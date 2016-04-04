module extensionapi.rpcclient;
version (DeadcodeClient):
class ClientLoop
{
	import std.socket;
	import dccore.signals;
    import extensionapi.common : RemoteCommandRegistrar;
    import extensionapi.rpc : RPC;
    import extensionapi.rpcapi : Application;

	mixin Signal!ClientLoop onConnected;

	private
	{
	    SocketSet _readSockets;
	    SocketSet _writeSockets;
	    SocketSet _errSockets;
	}


    RPC _rpc;
	Application app;
	RemoteCommandRegistrar registrar;

	this()
	{
	    _readSockets = new SocketSet();
	    _writeSockets = new SocketSet();
	    _errSockets = new SocketSet();
	}

    void connect(string ip = "127.0.0.1", ushort port = 13575)
    {
		_rpc = new RPC(ip, port);
		app = _rpc.create!Application(0);
		registrar = _rpc.create!RemoteCommandRegistrar(0);
		onConnected.emit(this);
    }

	void run()
	{
		auto res = select();
		while (res != SelectResult.Error)
		{
			if (res & SelectResult.Readable)
				_rpc.receiveMessage();
			res = select();
		}
	}

private:

	enum SelectResult : ubyte
	{
		Readable = 1,
            Writable = 2,
            Error    = 4,
	}

	SelectResult select()
	{
		auto sock = _rpc.sock;

	    _readSockets.reset();
	    _writeSockets.reset();
	    _errSockets.reset();

    	_writeSockets.add(sock);
    	_readSockets.add(sock);
    	_errSockets.add(sock);

	    import core.time;
	    auto count = Socket.select(_readSockets, _writeSockets, _errSockets, dur!"msecs"(100));
	    if (count <= 0)
	    	return SelectResult.Error;

		if (_errSockets.isSet(sock))
	    	return SelectResult.Error;

	    SelectResult result;
	   	if (_readSockets.isSet(sock))
	   		result = SelectResult.Readable;
	   	if (_writeSockets.isSet(sock))
	   		result = cast(SelectResult)(result | SelectResult.Writable);

    	return result;
    }
}

template rpcClient()
{
    int main(string[] args)
    {
        import std.conv;
	    import std.stdio;
        static import dccore.command;
        static import dccore.commandparameter;
        import extensionapi.rpcclient;
        dccore.commandparameter.registerCommandParameterPackHandlers();

        writeln("Connecting");

        string ip = "127.0.0.1";
        ushort port = 13575;
	    if (args.length > 1)
            ip = args[1];
        if (args.length > 2)
            port = args[2].to!ushort;

        auto loop = new ClientLoop;
        loop.connect(ip, port);

        writeln("Connected");

        auto app = loop.app;
        Command[] cmds;
        init(app, cmds);

        writeln(app.hello("Jonas"));

        // Setup commands
        auto localCommandManager = new dccore.command.CommandManager;
        loop._rpc.onCommandCall.connectTo((string name, CommandParameter[] params)
                                          {
                                              localCommandManager.execute(name, params); // TODO do directly on mgr
                                          });

        foreach (c; cmds)
        {
    	    writeln("Register command in deadcode ", c.name);
            localCommandManager.add(c);
            c.app = app;
            c.init();

            auto paramDefs = c.getCommandParameterDefinitions().asArray();
            loop.registrar.addRemoteCommand(c.name, paramDefs);
            writeln("Done");
            //app.addMenuItem(c.name, c.menuItem);
            //app.addCommandShortcuts(c.name, c.shortcuts);
        }

	    loop.run();
        return 0;
    }
}
