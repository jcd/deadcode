module extensionapi.rpc;

import msgpack;
import std.conv;
import std.stdio;
import std.traits;
import dccore.future;

// rdmd.exe -IC:\Users\jonasd\AppData\Roaming\dub\packages\msgpack-d-0.9.6\src\ .\testtcpclient.d

ubyte[] encodeLen(uint l)
{
    static uint r;
    r = l;
    ubyte* lenubyte = cast(ubyte*)&r;
    return lenubyte[0..4];
}

uint decodeLen(ubyte[] b)
{
    return *(cast(uint*)b.ptr);
}

// Dummy template mirroring the same struct for the deadcode app
template registerRPC(string Mod = __MODULE__)
{
}

alias CallID = string;
alias RPCAsyncCallback = Promise!Unpacker;

class RPC
{
    import std.array;
    import std.socket;
    import dccore.commandparameter : CommandParameter;
    import dccore.signals;
    Socket sock;
    ubyte[64*1024] inBuffer;
    Appender!(ubyte[]) outBuffer;
    RPCAsyncCallback[CallID] rpcCallbacks;
    ulong sNextCallID = 1;

    mixin Signal!(string, CommandParameter[]) onCommandCall;

    this(string ip, ushort port)
    {
        auto addr = new InternetAddress(ip, port);
        sock = new TcpSocket();
        sock.connect(addr);
        outBuffer = appender!(ubyte[]);
    }

    string newCallID()
    {
        import std.conv;
        return (sNextCallID++).to!string ~ "e";
    }

    void sendMessage()
    {
        ubyte[] packedData = outBuffer.data;
        sock.send(encodeLen(packedData.length));
        sock.send(packedData);
    }

    void receiveMessage()
    {
        sock.receive(inBuffer[0..4]);
        auto l = decodeLen(inBuffer);
        sock.receive(inBuffer[0..l]);
        auto unpacker =  Unpacker(inBuffer[0..l]);
        CallID callID;
        unpacker.unpack(callID);
        if (callID[$-1] == 'e')
        {
            // return from a call done on the editor
            auto promise = callID in rpcCallbacks;
            if (promise !is null)
                promise.setValue(unpacker);
            rpcCallbacks.remove(callID);
        }
        else
        {
            // new incoming command call from the editor
            string cmdName;
            unpacker.unpack(cmdName);
            CommandParameter[] cmdParams;
            unpacker.unpack(cmdParams);
            onCommandCall.emit(cmdName, cmdParams);
            outBuffer.clear();
            outBuffer ~= pack(callID);
            sendMessage();
        }
    }

    T create(T)(Unpacker unpacker)
    {
        typeof(T.id) id;
        unpacker.unpack(id);
        return create!T(id);
    }

    T create(T, ID)(ID id) if (!is(ID == Unpacker))
    {
        T i = new T();
        i.id = id;
        i.rpc = this;
        i.packedType = pack(T.stringof);
        i.packedID = pack(id.to!string);
        return i;
    }
}

class RPCProxy
{
    protected
    {
        RPC rpc;
        ubyte[] packedType;
        ubyte[] packedID;
    }

    protected string _setupRPCCall(string method)
    {
        rpc.outBuffer.clear();
        string callID = rpc.newCallID();
        rpc.outBuffer ~= pack(callID);
        rpc.outBuffer ~= packedType;
        rpc.outBuffer ~= packedID;
        rpc.outBuffer ~= pack(method);
        return callID;
    }

    auto asyncCallInternal(Args...)(string methodName, Args args)
    {
        CallID callID = _setupRPCCall(methodName);

        foreach (a; args)
        {
            version (RPCTrace)
                writeln("Arg: ", a);
			static if (is(typeof(a) == class))
				rpc.outBuffer ~= a.packedID;
			else
	            rpc.outBuffer ~= pack(a);
        }

        rpc.sendMessage();

        auto promise = new Promise!Unpacker;
        rpc.rpcCallbacks[callID] = promise;
        return promise.getFuture();
    }

    FutureVoid asyncCall(Args...)(string methodName, Args args)
    {
        auto future = asyncCallInternal(methodName, args);
        return future.then((Unpacker unpacker) {
            bool ok;
            unpacker.unpack(ok);

            version (RPCTrace)
                writeln(ok);

            import std.exception;
            enforce(ok);
        });
    }

    void call(Args...)(string methodName, Args args)
    {
        FutureVoid future = asyncCall(methodName, args);

        while (!future.isValid)
            rpc.receiveMessage();

        future.get();
    }

    Future!Result asyncCall(Result, Args...)(string methodName, Args args)
    {
        auto future = asyncCallInternal(methodName, args);
        return future.then((Unpacker unpacker) {
            bool ok;
            unpacker.unpack(ok);

            version (RPCTrace)
                writeln(ok);

            import std.exception;
            enforce(ok);

            Result ret;
            import std.traits;
            static if ( is(Result == class) )
            {
                version (RPCTrace)
                    writeln("unpackingA ", Result.stringof, " ", methodName);
                ret = rpc.create!Result(unpacker);
            }
            else
            {
                version (RPCTrace)
                    writeln("unpackingB ", Result.stringof);
                unpacker.unpack(ret);
            }
            return ret;
        });
    }

    Result call(Result, Args...)(string methodName, Args args)
    {
        Future!Result future = asyncCall!Result(methodName, args);

        while (!future.isValid)
            rpc.receiveMessage();

        return future.get();
    }

/*
        return tuple(asyncRes[0], (RPC _rpc) {

            Unpacker unpacker = asyncRes[1](_rpc);

            Result ret;
            import std.traits;
            static if ( is(Result == class) )
            {
                version (RPCTrace)
                    writeln("unpackingA ", Result.stringof, " ", methodName);
                ret = rpc.create!Result(unpacker);
            }
            else
            {
                version (RPCTrace)
                    writeln("unpackingB ", Result.stringof);
                unpacker.unpack(ret);
            }
        });
        */
}

enum RPCProxyMethodMixin = q{
    import std.array;
    import std.traits;
    import std.typetuple;
    alias Func = Identity!(mixin(__FUNCTION__));
    enum Name = __FUNCTION__.split(".")[$-1];
    alias ArgsIdents = ParameterIdentifierTuple!Func;

    static if (ArgsIdents.length == 0)
        alias Args = ArgsIdents;
    else static if (ArgsIdents.length == 1)
        alias Args =  AliasSeq!(mixin(ArgsIdents[0]));
    else static if (ArgsIdents.length == 2)
        alias Args = AliasSeq!(mixin(ArgsIdents[0]), mixin(ArgsIdents[1]));
    else
        pragma(msg, "Error: add support for more arguments in RPCProxyMethodMixin. Needed is ", ArgsIdents.length, " for ", __FUNCTION__);

    alias RT = ReturnType!(Func);
    static if(is (RT == void) )
        call(Name, Args);
    else
        return call!RT(Name, Args);
};

