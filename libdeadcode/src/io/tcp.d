module io.tcp;

import libasync;
import msgpack;
import util.queue;
import core.stdc.stdlib;
import core.stdc.string;
import dccore.signals;
static import extensionapi.rpc;
import dccore.commandparameter : CommandParameter;

class APICall
{
    TCPClient client;
    ubyte[] data;
    ubyte[] result;

    void execute(extensionapi.rpc.RPCObjectLookup lookup)
    {
        auto unpacker = Unpacker(data);
        string callID;
        string objectType;
        string objectID;
        unpacker.unpack(callID, objectType, objectID);

        Object obj = lookup(objectType, objectID);
        if (obj !is null)
        {
            import extensionapi.remotecommand : RemoteCommandRegistrar;
            RemoteCommandRegistrar rmr = cast(RemoteCommandRegistrar) obj;
            if (rmr !is null)
                rmr.client = client;
            auto rpcClass = extensionapi.rpc.lookupRPCClass(objectType);
            rpcClass.unpackAndCall(unpacker, lookup, obj, result);
            ubyte[] res = pack(callID) ~ pack(true) ~ result;
            uint len = res.length;
            ubyte* lenubyte = cast(ubyte*)&len;
            client.conn.send(lenubyte[0..4]);
            client.conn.send(res);
        }
        else
        {
            ubyte[] res = pack(callID) ~ pack(false);
            uint len = res.length;
            ubyte* lenubyte = cast(ubyte*)&len;
            client.conn.send(lenubyte[0..4]);
            client.conn.send(res);
        }
        client.apiCallPool.push(cast(shared)this);
    }
}

class TCPClient
{
    import core.sync.mutex : Mutex;
    import core.sync.condition : Condition;
    import core.atomic;
    private
    {
        AsyncTCPConnection conn;
        ubyte* readBuffer;
        size_t readBufferSize;
        enum maxBufferSize = 2000000;
        shared GrowableCircularQueue!(shared APICall) apiCalls;
        shared GrowableCircularQueue!(shared APICall) apiCallPool;
        uint totalBytesRead = 0;
        uint curMessageLen = 0;
        uint nextCallID = 1;
        Mutex mut;
        Condition cond;
    }

    // Called back in worker thread
    mixin Signal!() onQueuesUpdated;

    // shared GrowableCircularQueue!APIReturn apiReturns;
    shared bool isClosed;

    this(AsyncTCPConnection c)
    {
        conn = c;
        readBufferSize = 4096;
        readBuffer = cast(ubyte*)malloc(readBufferSize);
        apiCalls = new shared GrowableCircularQueue!(shared APICall);
        apiCallPool = new shared GrowableCircularQueue!(shared APICall);
        mut = new Mutex();
        cond = new Condition(mut);
        atomicStore(isClosed, false);
    }

    ~this()
    {
        free(readBuffer);
    }

    bool hasAPICall()
    {
        return !apiCalls.empty;
    }

    APICall popAPICall()
    {
         return cast(APICall)apiCalls.pop();
    }

    // Runs in AsyncIOWorker thread. Should only be called by async loop.
    void handleEvent(TCPEvent ev)
    {
        // Runs in AsyncIOWorker thread
        final switch (ev)
        {
            case TCPEvent.CONNECT:
                goto case TCPEvent.READ;
            case TCPEvent.READ:
                uint bytesRead = 0;

                bool receivedMessage = false;
                do
                {
                    bool readMsg = readMessages();
                    receivedMessage = receivedMessage || readMsg;
                    if (readBufferSize == totalBytesRead)
                    {
                        // allocate more space for incoming data
                        auto newSize = readBufferSize * 2;
                        if (newSize > maxBufferSize)
                            break;
                        readBuffer = cast(ubyte*)realloc(cast(void*)readBuffer, newSize);
                        readBufferSize = newSize;
                    }

                    auto b = readBuffer[totalBytesRead..readBufferSize];
                    bytesRead = conn.recv(b);
                    totalBytesRead += bytesRead;
                }
                while (bytesRead != 0);

                if (totalBytesRead == maxBufferSize)
                {
                    // Request too large
                    throw new Exception("TCP Request too large");
                }
                else
                {
                    receivedMessage = readMessages() || receivedMessage;
                }

                if (receivedMessage)
                    onQueuesUpdated.emit();
                break;
            case TCPEvent.WRITE:
                // ?
                break;
            case TCPEvent.ERROR:
                atomicStore(isClosed, true);
                cond.notify();
                break;
            case TCPEvent.CLOSE:
                atomicStore(isClosed, true);
                cond.notify();
                break;
        }
    }

    private static ubyte[] encodeLen(uint l)
    {
        static uint r;
        r = l;
        ubyte* lenubyte = cast(ubyte*)&r;
        return lenubyte[0..4];
    }

    private static uint decodeLen(ubyte[] b)
    {
        return *(cast(uint*)b.ptr);
    }

    // Runs in worker thread
    private bool readMessages()
    {
        bool didRead = false;
        while (true)
        {
            if (curMessageLen == 0 && totalBytesRead >= uint.sizeof)
            {
                curMessageLen = *(cast(uint*)readBuffer);
            }

            if (totalBytesRead >= (curMessageLen + uint.sizeof))
            {
                // We have enough data for a message to be decoded
                auto c = parseCall(readBuffer[uint.sizeof..curMessageLen+uint.sizeof]);
                apiCalls.push(cast(shared) c);
                cond.notify();
                totalBytesRead -= curMessageLen + uint.sizeof;
                memmove(readBuffer, readBuffer + curMessageLen + uint.sizeof, totalBytesRead);
                curMessageLen = 0; // prepare for new message
                didRead = true;
            }
            else
            {
                break;
            }
        }
        return didRead;
    }


    private auto parseCall(in ubyte[] data)
    {
        APICall c = apiCallPool.empty ? new APICall : cast(APICall) apiCallPool.pop();
        c.client = this;
        c.data.length = data.length;
        assumeSafeAppend(c.data);
        c.data[] = data[];
        return c;
    }

    void callRemoteCommand(extensionapi.rpc.RPCObjectLookup lookup, string name, CommandParameter[] params)
    {
        import std.exception;
        enforce(!atomicLoad(isClosed), "Connection closed during callRemoteCommand");
        import std.conv;
        string callID = (nextCallID++).to!string;
        ubyte[] res = pack(callID) ~ pack(name) ~ pack(params);
        uint len = res.length;
        ubyte* lenubyte = cast(ubyte*)&len;
        conn.send(lenubyte[0..4]);
        conn.send(res);
        while (true)
        {
            enforce(!atomicLoad(isClosed), "Connection closed during callRemoteCommand");
            cond.mutex.lock();
            while (hasAPICall())
            {
                APICall c = popAPICall();
                if (c.data.unpack!string() == callID)
                {
                    // The remote command returned and we can now return ourselves.
                    return;
                }
                else
                {
                    try
                    {
                        c.execute(lookup);
                    }
                    catch (Exception e)
                    {
                        assert(0, "ERROR callCommandRemote: " ~ e.toString());
                    }
                       // log.e("Error handling tcp client command while callCommandRemote");
                }
            }
            cond.wait();
        }
    }
}
