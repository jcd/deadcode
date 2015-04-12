module io.asyncio;

import core.future;

import libasync;

import std.concurrency;

import util.queue;

struct WatchDirResult
{
    uint id;
    shared GrowableCircularQueue!DWChangeInfo changesRange;
    bool success;
}

private
{
    interface IJob
    {
        abstract @property bool isDone();
        abstract void run(AsyncIOWorker worker);
    }

    mixin template JobImpl(Result, Args...)
    {
        Result _result;
        Args _args;

        private bool _isDone;

        @property bool isDone() const pure nothrow @safe
        {
            return _isDone;
        }

        private Promise!Result _promise;

        this(Args args)
        {
            _args = args;
            _promise = new Promise!Result;
            _isDone = false;
        }

        Promise!Result getPromise()
        {
            return _promise;
        }
    }

    class PingJob : IJob
    {
        struct Result
        {
            string msg;
            string reply;
        }

        private AsyncTimer _timerOneShot;

        mixin JobImpl!(Result, string);

        ~this()
        {
            destroy(_timerOneShot);
        }

        // This runs in the worker thread with eventLoop begin worker thread eventLoop
        override void run(AsyncIOWorker worker)
        {
            EventLoop eventLoop = worker._eventLoop;
            static int i = 0;
            _timerOneShot = new AsyncTimer(eventLoop);
            _timerOneShot.duration(1.seconds).run({
                auto r = Result(_args[0], "Pong to you " ~ i.to!string);
                _promise.setValue(r);
                _isDone = true;
                worker.resultProduced(this);
            });
            i++;

            /*
            // Nothing to run on the event loop. Just fulfill the promise
            import std.conv;
            _result = Result(_args[0], "Pong to you " ~ i.to!string);
            i++;
            import core.thread;
            import core.time;
            Thread.sleep( dur!("seconds")( 1 ) );
            _promise.setValue(_result);
            */
        }
    }

    class DownloadJob : IJob
    {
        struct Result
        {
            bool success;
        }

        HTTPClient _client;

        ~this()
        {
            destroy(_client);
        }

        mixin JobImpl!(Result, string, string);

        override void run(AsyncIOWorker worker)
        {
            EventLoop eventLoop = worker._eventLoop;
            _client = new HTTPClient(eventLoop);
            auto future = _client.GET(new URI(_args[0]));
            future.then( delegate(HTTPResponse r) {
                 import std.file;

                // save content to file dest
                write(_args[1], r.content);

                _promise.setValue(Result(true));
                _isDone = true;
                worker.resultProduced(this);
            });
        }
    }

    class WatchDirJob : IJob
    {
        private AsyncDirectoryWatcher _watcher;
        static private uint s_NextID = 1;

        alias WatchDirResult Result;

        mixin JobImpl!(Result, string, DWFileEvent, bool);

        ~this()
        {
            _watcher.kill();
            destroy(_watcher);
        }

        override void run(AsyncIOWorker worker)
        {

            EventLoop eventLoop = worker._eventLoop;

            _watcher = new AsyncDirectoryWatcher(eventLoop);

            auto r = new shared GrowableCircularQueue!DWChangeInfo();
            auto result = Result(s_NextID++, r, true);

            _watcher.run({
                DWChangeInfo[1] change;
                DWChangeInfo[] changeRef = change.ptr[0..1];
                while(_watcher.readChanges(changeRef)){
                    r.push(change[0]);
                }
                worker.resultProduced(this);
            });
            _watcher.watchDir(_args);

            _promise.setValue(result);
        }
    }
}

class AsyncIO
{
    private
    {
        Tid _workerTid;
        EventLoop _eventLoop;
        shared AsyncSignal _signal;
        uint _sdlCustomEventType;
    }

    @property uint customEventType() const pure nothrow @safe
    {
        return _sdlCustomEventType;
    }

    this()
    {
        import derelict.sdl2.sdl;
        _sdlCustomEventType = SDL_RegisterEvents(1);
        _eventLoop = new EventLoop();
        _workerTid = spawn(&spawnWorker, thisTid, _sdlCustomEventType);
        _signal = receiveOnly!(shared AsyncSignal)();
    }

    private static void spawnWorker(Tid parentTid, uint sdlCustomEventType)
    {
        auto worker = new AsyncIOWorker(sdlCustomEventType);
        // Need to share the signal between parent and worker
        parentTid.send(worker._signal);
        worker.run();
    }

    void stopWorker()
    {
        _workerTid.send(true);
        _signal.trigger(_eventLoop);
    }

    auto download(string url, string dest)
    {
        auto j = new DownloadJob(url, dest);
        return startAsync(j);
    }

    /** Returns an async range that with directory changes

    */
    auto watchDir(string path, DWFileEvent ev = DWFileEvent.ALL, bool recursive = false)
    {
        auto j = new WatchDirJob(path, ev, recursive);
        return startAsync(j);
    }

    auto ping(string msg)
    {
        auto j = new PingJob(msg);
        return startAsync(j);
    }

    private auto startAsync(Job)(Job j)
    {
        // Make a job (with a promise) and send that to the worker thread. Return a future to the caller
        // so that he knows when the result is ready.
        send(j);
        _signal.trigger(_eventLoop);
        return j.getPromise().getFuture();
    }

    private void send(D)(D d)
    {
        // Since Unique doesn't work for this yet we need to work around getting stuff send by casting it
        import std.typecons;
        _workerTid.send(cast(shared(D))d);
    }

    unittest
    {
        auto aio = new AsyncIO;
        aio.ping("Hello");
    }

    //void watchDirectory(string url, string dest, delegate void(size_t bytes, size_t totalBytes, Duration dur) progressDlg)
    //{
    //
    //}
}

class AsyncIOWorker
{

    private
    {
        EventLoop _eventLoop;
        bool _shutdown = false;
        shared AsyncSignal _signal;
        AsyncDirectoryWatcher resourceDirWatcher;
        uint _sdlCustomEventType;
    }

    this(uint sdlCustomEventType)
    {
        import std.stdio;
        import std.typecons;
        _sdlCustomEventType = sdlCustomEventType;
        _eventLoop = new EventLoop();
        _signal = new shared AsyncSignal(_eventLoop);
        _signal.run({
            receive(
                    (shared(IJob) j) { thaw(j).run(this); },
                    (bool s) { kill(); },
                    (Variant v) { writeln("Received variant in asyncio worker ", v); }
                    );
        });
    }

    void run()
    {
        while (!_shutdown)
            _shutdown = !_eventLoop.loop(dur!"days"(7)) || _shutdown; // _shutdown may have been set in a signal
        destroyAsyncThreads();
    }

    private static auto thaw(T)(T t)
    {
        import std.traits;
        return cast(Unqual!T)t;
    }

    private void resultProduced(IJob job)
    {
        if (job.isDone)
        {
            destroy(job);
        }
        signalOwnerThread();
    }

    // This will wake up the SDL loop
    private void signalOwnerThread()
    {
        import derelict.sdl2.sdl;
        SDL_Event event;
        //   SDL_Zero(event); not needed since dlang does this
        event.type = _sdlCustomEventType;
        SDL_PushEvent(&event);
    }

    void kill()
    {
        _shutdown = true;
    }
}




/**

Introduces a simple but under-powered HTTP client.

Based on: https://github.com/d-gamedev-team/gfm/blob/master/net/gfm/net/httpclient.d

*/

//import std.socketstream,
//    std.stream,
//    std.socket,
//    std.string,
//    std.conv,
//    std.stdio;

/// The exception type for HTTP errors.
class HTTPException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/// Results of a HTTP request.
class HTTPResponse
{
    int statusCode;         /// HTTP status code received.
    string[string] headers; /// HTTP headers received.
    ubyte[] content;        /// Request body.
}


enum HTTPMethod
{
    OPTIONS,
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    TRACE,
    CONNECT
}

/**

Minimalistic HTTP client.
At this point it only support simple GET requests which return the
whole response body.

Bugs: We might need to pool TCP connections later on.
*/
class HTTPClient
{
    public
    {
        /// Creates a HTTP client with user-specified User-Agent.
        this(EventLoop eventLoop, string userAgent = "deadcode-http-client")
        {
            _eventLoop = eventLoop;
            buffer.length = 4096;
            _userAgent = userAgent;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            //if (_socket !is null)
            //{
            //    _socket.close();
            //    _socket = null;
            //}
        }

        /// Perform a HTTP GET request.
        Future!HTTPResponse GET(URI uri)
        {
            return request(HTTPMethod.GET, uri, defaultHeaders(uri));
        }

        /// Perform a HTTP HEAD request (same as GET but without content).
        Future!HTTPResponse HEAD(URI uri)
        {
            return request(HTTPMethod.HEAD, uri, defaultHeaders(uri));
        }

        /// Performs a HTTP request.
        /// Requested URI can be "*", an absolute URI, an absolute path, or an authority
        /// depending on the method.
        /// Throws: $(D HTTPException) on error.
        Future!HTTPResponse request(HTTPMethod method, URI uri, string[string] headers)
        {
            import std.stdio;
            //checkURI(uri);
            Promise!HTTPResponse promise = new Promise!HTTPResponse;

            try
            {
                connectTo(uri);
                assert(_conn !is null);

                string request = format("%s %s HTTP/1.0\r\n", to!string(method), uri.toString());

                foreach (header; headers.byKey())
                {
                    request ~= format("%s: %s\r\n", header, headers[header]);
                }
                request ~= "\r\n";

                auto httpResponse = new HTTPResponse();

                _conn.run( (TCPEvent ev) {
                    final switch (ev) {
                        case TCPEvent.CONNECT:
                            writeln("!!Connected");
                            static ubyte[] abin = new ubyte[4092];
                            while (true) {
                                uint len = _conn.recv(abin);
                                if (len < abin.length)
                                    break;
                            }
                            writeln(_conn.local.toString());
                            writeln(_conn.peer.toString());
                            string q = "GET " ~ uri.toString() ~ "\nHost: example.org\nConnection: close";
                            _conn.send(cast(ubyte[])q);
                            break;
                        case TCPEvent.READ:
                            static ubyte[] bin = new ubyte[4092];
                            while (true) {
                                uint len = _conn.recv(bin);
                                writeln("!!Received " ~ len.to!string ~ " bytes");
                                writeln(cast(string)bin);
                                httpResponse.content ~= bin;
                                if (len < bin.length)
                                    break;
                            }
                            break;
                        case TCPEvent.WRITE:
                            // writeln("!!Write is ready");
                            break;
                        case TCPEvent.CLOSE:
                            writeln("!!Disconnected");
                            promise.setValue(httpResponse);
                            destroy(httpResponse);
                            break;
                        case TCPEvent.ERROR:
                            writeln("!!Error!");
                            break;
                    }
                    return;
                });

                /*
                auto scope ss = new SocketStream(_socket);
                ss.writeString(request);

                // parse status line
                auto line = ss.readLine();
                if (line.length < 12 || line[0..5] != "HTTP/" || line[6] != '.')
                    throw new HTTPException("Cannot parse HTTP status line");

                if (line[5] != '1' || (line[7] != '0' && line[7] != '1'))
                    throw new HTTPException("Unsupported HTTP version");

                // parse error code
                res.statusCode = 0;
                for (int i = 0; i < 3; ++i)
                {
                    char c = line[9 + i];
                    if (c >= '0' && c <= '9')
                        res.statusCode = res.statusCode * 10 + (c - '0');
                    else
                        throw new HTTPException("Expected digit in HTTP status code");
                }

                // parse headers
                while(true)
                {
                    auto headerLine = ss.readLine();

                    if (headerLine.length == 0)
                        break;

                    sizediff_t colonIdx = indexOf(headerLine, ':');
                    if (colonIdx == -1)
                        throw new HTTPException("Cannot parse HTTP header: missing colon");

                    string key = headerLine[0..colonIdx].idup;

                    // trim leading spaces and tabs
                    sizediff_t valueStart = colonIdx + 1;
                    for ( ; valueStart <= headerLine.length; ++valueStart)
                    {
                        char c = headerLine[valueStart];
                        if (c != ' ' && c != '\t')
                            break;
                    }

                    // trim trailing spaces and tabs
                    sizediff_t valueEnd = headerLine.length;
                    for ( ; valueEnd > valueStart; --valueEnd)
                    {
                        char c = headerLine[valueEnd - 1];
                        if (c != ' ' && c != '\t')
                            break;
                    }

                    string value = headerLine[valueStart..valueEnd].idup;
                    res.headers[key] = value;
                }

                while (!ss.eof())
                {
                    int read = cast(int)( ss.readBlock(buffer.ptr, buffer.length));
                    res.content ~= buffer[0..read];
                }

                return res;
            }
            */
            }
            catch (Exception e)
            {
                throw new HTTPException(e.msg);
            }
            return promise.getFuture();
        }
    }

    private
    {
        EventLoop _eventLoop;
        AsyncTCPConnection _conn;

        ubyte[] buffer;
        string _userAgent;

        void connectTo(URI uri)
        {
            _conn = new AsyncTCPConnection(_eventLoop);
            _conn.peer = _eventLoop.resolveHost(uri.hostName, 80);
        }

        static checkURI(URI uri)
        {
            if (uri.scheme() != "http")
                throw new HTTPException(format("'%' is not an HTTP absolute url", uri.toString()));
        }

        string[string] defaultHeaders(URI uri)
        {
            string hostName = uri.hostName();
            auto headers = ["Host": hostName,
            "User-Agent": _userAgent];
            return headers;
        }
    }
}






import std.range,
    std.string,
    std.ascii,
    std.socket;

/// Exception thrown when an URI doesn't parse.
class URIException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/**

An attempt at implementing URI (RFC 3986).

All constructed URI are valid and normalized.
Bugs:
$(UL
$(LI Separate segments in parsed form.)
$(LI Relative URL combining.)
$(LI . and .. normalization.)
)

Alternative:
Consider using $(WEB vibed.org,vibe.d) if you need something better.
*/
class URI
{
    public
    {
        enum HostType
        {
            NONE,
            REG_NAME, /// Host has a registered name.
            IPV4,     /// Host has an IPv4
            IPV6,     /// Host has an IPv6
            IPVFUTURE /// Unknown yet scheme.
        }

        /// Creactes an URI from an input range, throws if invalid.
        /// Input should be an ENCODED url range.
        /// Throws: $(D URIException) if the URI is invalid.
        this(T)(T input) if (isForwardRange!T)
        {
            _scheme = null;
            _hostType = HostType.NONE;
            _hostName = null;
            _port = -1;
            _userInfo = null;
            _path = null;
            _query = null;
            _fragment = null;
            parseURI(input);
        }

        /// Checks URI validity.
        /// Returns: true if input is valid.
        static bool isValid(T)(T input) /* pure */ nothrow
        {
            try
            {
                try
                {
                    URI uri = new URI(input);
                    return true;
                }
                catch (URIException e)
                {
                    return false;
                }
            }
            catch (Exception e)
            {
                assert(false); // came here? Fix the library by writing the missing catch-case.
            }
        }

        // getters for normalized URI components

        /// Returns: URI scheme, guaranteed not null.
        string scheme() pure const nothrow
        {
            return _scheme;
        }

        /// Returns: Host name, or null if not available.
        string hostName() pure const nothrow
        {
            return _hostName;
        }

        /// Returns: Host type (HostType.NONE if not available).
        HostType hostType() pure const nothrow
        {
            return _hostType;
        }

        /**
        * Returns: port number.
        * If none is provided by the URI, return the default port for this scheme.
        * If the scheme isn't recognized, return -1.
        */
        int port() pure const nothrow
        {
            if (_port != -1)
                return _port;

            foreach (ref e; knownSchemes)
                if (e.scheme == _scheme)
                    return e.defaultPort;

            return -1;
        }

        /// Returns: User-info part of the URI, or null if not available.
        string userInfo() pure const nothrow
        {
            return _userInfo;
        }

        /// Returns: Path part of the URI, never null, can be the empty string.
        string path() pure const nothrow
        {
            return _path;
        }

        /// Returns: Query part of the URI, or null if not available.
        string query() pure const nothrow
        {
            return _query;
        }

        /// Returns: Fragment part of the URI, or null if not available.
        string fragment() pure const nothrow
        {
            return _fragment;
        }

        /// Returns: Authority part of the URI.
        string authority() pure const nothrow
        {
            if (_hostName is null)
                return null;

            string res = "";
            if (_userInfo !is null)
                res = res ~ _userInfo ~ "@";
            res ~= _hostName;
            if (_port != -1)
                res = res ~ ":" ~ itos(_port);
            return res;
        }

        /// Resolves URI host name.
        /// Returns: std.socket.Address from the URI.
        Address resolveAddress()
        {
            final switch(_hostType)
            {
                case HostType.REG_NAME:
                case HostType.IPV4:
                    return new InternetAddress(_hostName, cast(ushort)port());

                case HostType.IPV6:
                    return new Internet6Address(_hostName, cast(ushort)port());

                case HostType.IPVFUTURE:
                case HostType.NONE:
                    throw new URIException("Cannot resolve such host");
            }
        }

        /// Returns: Pretty string representation.
        override string toString() const
        {
            string res = _scheme ~ ":";

            if (_hostName is null)
                res = res ~ "//" ~ authority();
            res ~= _path;
            if (_query !is null)
                res = res ~ "?" ~ _query;
            if (_fragment !is null)
                res = res ~ "#" ~ _fragment;
            return res;
        }

        /// Semantic comparison of two URIs.
        /// They are equals if they have the same normalized string representation.
        bool opEquals(U)(U other) pure const nothrow if (is(U : FixedPoint))
        {
            return value == other.value;
        }
    }

    private
    {
        // normalized URI components
        string _scheme;     // never null, never empty
        string _userInfo;   // can be null
        HostType _hostType; // what the hostname string is (NONE if no host in URI)
        string _hostName;   // null if no authority in URI
        int _port;          // -1 if no port in URI
        string _path;       // never null, bu could be empty
        string _query;      // can be null
        string _fragment;   // can be null

        // URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
        void parseURI(T)(ref T input)
        {
            _scheme = toLower(parseScheme(input));
            consume(input, ':');
            parseHierPart(input);

            if (input.empty)
                return;

            char c = popChar(input);

            if (c == '?')
            {
                _query = parseQuery(input);

                if (input.empty)
                    return;

                c = popChar(input);
            }

            if (c == '#')
            {
                _fragment = parseFragment(input);
            }

            if (!input.empty)
                throw new URIException("unexpected characters at end of URI");
        }

        string parseScheme(T)(ref T input)
        {
            string result = "";
            char c = popChar(input);
            if (!isAlpha(c))
                throw new URIException("expected alpha character in URI scheme");

            result ~= c;

            while(!input.empty)
            {
                c = peekChar(input);

                if (isAlpha(c) || isDigit(c) || "+-.".contains(c))
                {
                    result ~= c;
                    input.popFront();
                }
                else
                    break;
            }
            return result;
        }

        // hier-part   = "//" authority path-abempty
        //             / path-absolute
        //             / path-rootless
        //             / path-empty
        void parseHierPart(T)(ref T input)
        {
            if (input.empty())
                return; // path-empty

            char c = peekChar(input);
            if (c == '/')
            {
                input.popFront();
                T sinput = input.save;
                if (!input.empty() && peekChar(input) == '/')
                {
                    consume(input, '/');
                    parseAuthority(input);
                    _path = parseAbEmpty(input);
                }
                else
                {
                    input = sinput.save;
                    _path = parsePathAbsolute(input);
                }
            }
            else
            {
                _path = parsePathRootless(input);
            }
        }

        // authority   = [ userinfo "@" ] host [ ":" port ]
        void parseAuthority(T)(ref T input)
        {
            // trying to parse user
            T uinput = input.save;
            try
            {
                _userInfo = parseUserinfo(input);
                consume(input, '@');
            }
            catch(URIException e)
            {
                // no user name in URI
                _userInfo = null;
                input = uinput.save;
            }

            parseHost(input, _hostName, _hostType);

            if (!empty(input) && peekChar(input) == ':')
            {
                consume(input, ':');
                _port = parsePort(input);
            }
        }

        string parsePcharString(T)(ref T input, bool allowColon, bool allowAt, bool allowSlashQuestionMark)
        {
            string res = "";

            while(!input.empty)
            {
                char c = peekChar(input);

                if (isUnreserved(c) || isSubDelim(c))
                    res ~= popChar(input);
                else if (c == '%')
                    res ~= parsePercentEncodedChar(input);
                else if (c == ':' && allowColon)
                    res ~= popChar(input);
                else if (c == '@' && allowAt)
                    res ~= popChar(input);
                else if ((c == '?' || c == '/') && allowSlashQuestionMark)
                    res ~= popChar(input);
                else
                    break;
            }
            return res;
        }


        void parseHost(T)(ref T input, out string res, out HostType hostType)
        {
            char c = peekChar(input);
            if (c == '[')
                parseIPLiteral(input, res, hostType);
            else
            {
                T iinput = input.save;
                try
                {
                    hostType = HostType.IPV4;
                    res = parseIPv4Address(input);
                }
                catch (URIException e)
                {
                    input = iinput.save;
                    hostType = HostType.REG_NAME;
                    res = toLower(parseRegName(input));
                }
            }
        }

        void parseIPLiteral(T)(ref T input, out string res, out HostType hostType)
        {
            consume(input, '[');
            if (peekChar(input) == 'v')
            {
                hostType = HostType.IPVFUTURE;
                res = parseIPv6OrFutureAddress(input);
            }
            else
            {
                hostType = HostType.IPV6;
                string ipv6 = parseIPv6OrFutureAddress(input);

                // validate and expand IPv6 (for normalizaton to be effective for comparisons)
                try
                {
                    ubyte[16] bytes = Internet6Address.parse(ipv6);
                    res = "";
                    foreach (i ; 0..16)
                    {
                        if ((i & 1) == 0 && i != 0)
                            res ~= ":";
                        res ~= format("%02x", bytes[i]);
                    }
                }
                catch(SocketException e)
                {
                    // IPv6 address did not parse
                    throw new URIException(e.msg);
                }
            }
            consume(input, ']');
        }

        string parseIPv6OrFutureAddress(T)(ref T input)
        {
            string res = "";
            while (peekChar(input) != ']')
                res ~= popChar(input);
            return res;
        }

        string parseIPv4Address(T)(ref T input)
        {
            int a = parseDecOctet(input);
            consume(input, '.');
            int b = parseDecOctet(input);
            consume(input, '.');
            int c = parseDecOctet(input);
            consume(input, '.');
            int d = parseDecOctet(input);
            return format("%s.%s.%s.%s", a, b, c, d);
        }

        // dec-octet     = DIGIT                 ; 0-9
        //               / %x31-39 DIGIT         ; 10-99
        //               / "1" 2DIGIT            ; 100-199
        //               / "2" %x30-34 DIGIT     ; 200-249
        //               / "25" %x30-35          ; 250-255
        int parseDecOctet(T)(ref T input)
        {
            int res = popDigit(input);

            if (!input.empty && isDigit(peekChar(input)))
            {
                res = 10 * res + popDigit(input);

                if (!input.empty && isDigit(peekChar(input)))
                    res = 10 * res + popDigit(input);
            }

            if (res > 255)
                throw new URIException("out of range number in IPv4 address");

            return res;
        }

        // query         = *( pchar / "/" / "?" )
        string parseQuery(T)(ref T input)
        {
            return parsePcharString(input, true, true, true);
        }

        // fragment      = *( pchar / "/" / "?" )
        string parseFragment(T)(ref T input)
        {
            return parsePcharString(input, true, true, true);
        }

        // pct-encoded   = "%" HEXDIG HEXDIG
        char parsePercentEncodedChar(T)(ref T input)
        {
            consume(input, '%');

            int char1Val = hexValue(popChar(input));
            int char2Val = hexValue(popChar(input));
            return cast(char)(char1Val * 16 + char2Val);
        }

        // userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
        string parseUserinfo(T)(ref T input)
        {
            return parsePcharString(input, true, false, false);
        }

        // reg-name      = *( unreserved / pct-encoded / sub-delims )
        string parseRegName(T)(ref T input)
        {
            return parsePcharString(input, false, false, false);
        }

        // port          = *DIGIT
        int parsePort(T)(ref T input)
        {
            int res = 0;

            while(!input.empty)
            {
                char c = peekChar(input);
                if (!isDigit(c))
                    break;
                res = res * 10 + popDigit(input);
            }
            return res;
        }

        // segment       = *pchar
        // segment-nz    = 1*pchar
        // segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
        string parseSegment(T)(ref T input, bool allowZero, bool allowColon)
        {
            string res = parsePcharString(input, allowColon, true, false);
            if (!allowZero && res == "")
                throw new URIException("expected a non-zero segment in URI");
            return res;
        }

        // path-abempty  = *( "/" segment )
        string parseAbEmpty(T)(ref T input)
        {
            string res = "";
            while (!input.empty)
            {
                if (peekChar(input) != '/')
                    break;
                consume(input, '/');
                res = res ~ "/" ~ parseSegment(input, true, true);
            }
            return res;
        }

        // path-absolute = "/" [ segment-nz *( "/" segment ) ]
        string parsePathAbsolute(T)(ref T input)
        {
            consume(input, '/');
            string res = "/";

            try
            {
                res ~= parseSegment(input, false, true);
            }
            catch(URIException e)
            {
                return res;
            }

            res ~= parseAbEmpty(input);
            return res;
        }

        string parsePathNoSlash(T)(ref T input, bool allowColonInFirstSegment)
        {
            string res = parseSegment(input, false, allowColonInFirstSegment);
            res ~= parseAbEmpty(input);
            return res;
        }

        // path-noscheme = segment-nz-nc *( "/" segment )
        string parsePathNoScheme(T)(ref T input)
        {
            return parsePathNoSlash(input, false);
        }

        // path-rootless = segment-nz *( "/" segment )
        string parsePathRootless(T)(ref T input)
        {
            return parsePathNoSlash(input, true);
        }
    }
}

private pure
{
    bool contains(string s, char c) nothrow
    {
        foreach(char sc; s)
            if (c == sc)
                return true;
        return false;
    }

    bool isAlpha(char c) nothrow
    {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
    }

    bool isDigit(char c) nothrow
    {
        return c >= '0' && c <= '9';
    }

    bool isHexDigit(char c) nothrow
    {
        return hexValue(c) != -1;
    }

    bool isUnreserved(char c) nothrow
    {
        return isAlpha(c) || isDigit(c) || "-._~".contains(c);
    }

    bool isReserved(char c) nothrow
    {
        return isGenDelim(c) || isSubDelim(c);
    }

    bool isGenDelim(char c) nothrow
    {
        return ":/?#[]@".contains(c);
    }

    bool isSubDelim(char c) nothrow
    {
        return "!$&'()*+,;=".contains(c);
    }

    int hexValue(char c) nothrow
    {
        if (isDigit(c))
            return c - '0';
        else if (c >= 'a' && c <= 'f')
            return c - 'a';
        else if (c >= 'A' && c <= 'F')
            return c - 'A';
        else
            return -1;
    }

    // peek char from input range, or throw
    char peekChar(T)(ref T input)
    {
        if (input.empty())
            throw new URIException("expected character");

        dchar c = input.front;

        if (cast(int)c >= 127)
            throw new URIException("US-ASCII character expected");

        return cast(char)c;
    }

    // pop char from input range, or throw
    char popChar(T)(ref T input)
    {
        char result = peekChar(input);
        input.popFront();
        return result;
    }

    int popDigit(T)(ref T input)
    {
        char c = popChar(input);
        if (!isDigit(c))
            throw new URIException("expected digit character");
        return hexValue(c);
    }

    void consume(T)(ref T input, char expected)
    {
        char c = popChar(input);
        if (c != expected)
            throw new URIException("expected '" ~ c ~ "' character");
    }

    string itos(int i) pure nothrow
    {
        string res = "";
        do
        {
            res = ('0' + (i % 10)) ~ res;
            i = i / 10;
        } while (i != 0);
        return res;
    }

    struct KnownScheme
    {
        string scheme;
        int defaultPort;
    }

    enum knownSchemes =
    [
        KnownScheme("ftp", 21),
        KnownScheme("sftp", 22),
        KnownScheme("telnet", 23),
        KnownScheme("smtp", 25),
        KnownScheme("gopher", 70),
        KnownScheme("http", 80),
        KnownScheme("nntp", 119),
        KnownScheme("https", 443)
    ];

}

unittest
{

    {
        string s = "HTTP://machin@fr.wikipedia.org:80/wiki/Uniform_Resource_Locator?Query%20Part=4#fragment%20part";
        assert(URI.isValid(s));
        auto uri = new URI(s);
        assert(uri.scheme() == "http");
        assert(uri.userInfo() == "machin");
        assert(uri.hostName() == "fr.wikipedia.org");
        assert(uri.port() == 80);
        assert(uri.authority() == "machin@fr.wikipedia.org:80");
        assert(uri.path() == "/wiki/Uniform_Resource_Locator");
        assert(uri.query() == "Query Part=4");
        assert(uri.fragment() == "fragment part");
    }

    // host tests
    {
        assert((new URI("http://truc.org")).hostType() == URI.HostType.REG_NAME);
        assert((new URI("http://127.0.0.1")).hostType() == URI.HostType.IPV4);
        assert((new URI("http://[2001:db8::7]")).hostType() == URI.HostType.IPV6);
        assert((new URI("http://[v9CrazySchemeFromOver9000year]")).hostType() == URI.HostType.IPVFUTURE);
    }

    auto wellFormedURIs =
    [
        "ftp://ftp.rfc-editor.org/in-notes/rfc2396.txt",
        "mailto:Quidam.no-spam@example.com",
        "news:fr.comp.infosystemes.www.auteurs",
        "gopher://gopher.quux.org/",
        "http://Jojo:lApIn@www.example.com:8888/chemin/d/acc%C3%A8s.php?q=req&q2=req2#signet",
        "ldap://[2001:db8::7]/c=GB?objectClass?one",
        "mailto:John.Doe@example.com",
        "tel:+1-816-555-1212",
        "telnet://192.0.2.16:80/",
        "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
        "about:",
    ];

    foreach (wuri; wellFormedURIs)
    {
        bool valid = URI.isValid(wuri);
        assert(valid);
    }
}
