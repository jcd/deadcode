module application;

import behavior.behavior;
import dccore.analytics;
import dccore.commandparameter;
import dccore.command : CompletionEntry, CommandManager;
import dccore.container;
import dccore.future;

import dccore.log;
import dccore.mainloopworker;
import dccore.signals;
import core.stdc.errno;
import dccore.uri;

import edit.buffer;
import edit.bufferview;
import edit.copybuffer;
import edit.language;

import extensionapi.rpc;
import extensionapi.types : MenuItem, Shortcut;
import extensionapi.remotecommand : RemoteCommandRegistrar;

public import platform.config : ResourceBaseLocation;

import graphics;
import gui;
import gui.resources.texture : GTexture = Texture;

import controls.button;
import controls.command;
import controls.menu;
import controls.texteditor;
import dccore.path;

import gui.resources.generic;
import gui.layout;
import io.asyncio;
import io.tcp : TCPClient, APICall;

import util.queue;

import libasync : DWChangeInfo, AsyncTCPConnection, TCPEvent;

import math; // Vec2f

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.string;
static import std.exception;

mixin registerRPC;

enum RelativeLocation
{
	topOf,
	bottomOf,
	leftIn,
	rightIn,
	above,
	below,
	leftOf,
	rightOf,
	inside,
}

import util.jsonx;

interface IWidgetLocationUpdater
{
	void scheduleWidgetPlacement(Widget placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc);
	void performLocationUpdates();
}

class PromptQuery
{
	this(string q, string a, Promise!PromptQueryResult p, bool delegate(string) _validationDg, CompletionEntry[] delegate(string) _getCompletionsDg)
	{
		question = q;
		answer = a;
		promise = p;
        validationDg = _validationDg;
		getCompletionsDg = _getCompletionsDg;
	}

	string question;
	string answer;
	Promise!PromptQueryResult promise;
    bool delegate(string) validationDg;
	CompletionEntry[] delegate(string) getCompletionsDg;
}

class PromptQueryResult
{
	string answer;
	bool success;
}

uint g_sdlCustomEventType;

void wakeMainThread()
{
    import derelict.sdl2.sdl;
    SDL_Event event;
    //   SDL_Zero(event); not needed since dlang does this
    event.type = g_sdlCustomEventType;
    SDL_PushEvent(&event);
}

private Throwable.TraceInfo myTraceHandler( void* ptr = null )
{
    import core.runtime;
    import platform.dialog;
    messageBox("Tracehandling", "Tracehandler is being called", MessageBoxStyle.error | MessageBoxStyle.yesNo | MessageBoxStyle.modal);
    return defaultTraceHandler(ptr);
}

/*
private void tcpCommandSession(Socket sock, Tid ownerTid)
{
    ubyte[4096] buf;
    while (true)
    {
        sock.receive(buf);
        ownerTid.send(SerializedCommand(buf));

        import derelict.sdl2.sdl;
        SDL_Event event;
        //   SDL_Zero(event); not needed since dlang does this
        event.type = _sdlCustomEventType;
        SDL_PushEvent(&event);
    }
}

private void tcpCommandHandler(Tid ownerTid)
{
    // Setup listning

    // Accept

    // Spawn new thread for handling connection and provide it with the owner Tid
    spawn(&tcpCommandSession, sock, ownerTid);
}
*/
@RPC
class Application
{
	GUI guiRoot;
	Menu menu;

    int id = 0; // for rpc

	import std.container;
	Stack!PromptQuery _promptStack;

    // Currently connected tcp clients
    TCPClient[] _connectedTcpClients;

    // Newly connected client waiting to be put into _connectedTcpClients array
    //shared GrowableCircularQueue!(shared TCPClient) _connectedTcpClientQueue;
    shared RWQueue!(shared TCPClient) _connectedTcpClientQueue;

    // int is ResourceBaseLocation flags changed
    mixin Signal!(uint) onResourceBaseLocationChanged;
    mixin Signal!(BufferView) onFileOpened;

	private string _restartExecutable;
	private IWidgetLocationUpdater _widgetLocationUpdater;

	// super()
    private
	{
		BufferViewManager _bufferViewManager;
		BufferView _currentBuffer;
		int _previousBufferID;
		EditorBehavior _editorBehavior;
		CommandManager _commandManager;
	    Log _log;
        RemoteCommandRegistrar _remoteCommandRegistrar;
    }

	static struct EditorInfo
	{
		this(int fo, TextEditor ed)
		{
			focusOrder = fo;
			editor = ed;
		}
		int focusOrder; // LRU ordering

		@noSerialize
        TextEditor editor;
	}

	static class Editors
	{
		int focusOrderCounter;
		EditorInfo[int] editors;
	}

	enum appVersion = "0.4";
	string analyticsKey;

	Editors editors;

	private Widget _editorStack;
	private Widget _mainWidget;
    //shared GrowableCircularQueue!WatchDirChange resourceDirWatcherQueue;
    shared RWQueue!WatchDirChange* resourceDirWatcherQueue;
    // shared GrowableCircularQueue!WatchDirChange extensionsDirWatcherQueue;
    shared RWQueue!WatchDirChange* extensionsDirWatcherQueue;

	StyleSheet defaultStyleSheet;

	GenericResource sessionData;

	private Analytics analytics;
    private AsyncIO _asyncIO;

	T getGlobalStyle(T)(string name)
	{
		T res;
		defaultStyleSheet.getStyle("Globals").getProperty(name, res);
		return res;
	}

	class WindowData
	{
		CommandControl commandControl;
	}

    @property Window activeWindow()
    {
        return guiRoot.activeWindow;
    }

	// super()
    @property
	{
		BufferViewManager bufferViewManager() { return _bufferViewManager; }
        void currentBuffer(BufferView v) { _previousBufferID = _currentBuffer is null ? 0 : _currentBuffer.id; _currentBuffer = v; }
        @RPC BufferView currentBuffer() { return _currentBuffer; }
        @RPC BufferView previousBuffer() { return bufferViewManager[_previousBufferID]; }
		EditorBehavior editorBehavior() { return _editorBehavior; }
		CommandManager commandManager() { return _commandManager; }
	}

    // TODO: move to ctx
    dccore.uri.URI resourceURI(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
    {
        static import platform.config;
        return platform.config.resourceURI(path, base);
    }

	private this(GUI gui)
	{
        setLog(dccore.log.log);

        // Make sure standard dirs exists
        {
            auto d = resourceURI("extensions", ResourceBaseLocation.userDataDir).uriString;
            if (!exists(d))
                mkdirRecurse(d);

            d = resourceURI("", ResourceBaseLocation.sessionDir).uriString;
            if (!exists(d))
                mkdirRecurse(d);
        }

        //_connectedTcpClientQueue = new shared GrowableCircularQueue!(shared TCPClient)();
        // _mainThreadWorkQueue = new typeof(_mainThreadWorkQueue);

		// This also sets up tracking keys for analytics
		guiRoot = gui;
		setupRegistryEntries();
		_promptStack = new Stack!PromptQuery();

		// analytics = new GoogleAnalytics("UA-42266538-2", analyticsKey, "Ded", "com.streamwinter.ded", appVersion);

		// analytics = new NullAnalytics;
		analyticEvent("core", "start");
		analyticStartTiming("core", "startup");
		_widgetLocationUpdater = new WidgetLocationUpdater(this);

        // super()
        {
            _commandManager = new CommandManager();
            _bufferViewManager = new BufferViewManager();
            auto buf = _bufferViewManager.create("ctrl+? for help.\nctrl+w for console\n\n", "*Messages*");
            buf.cursorToEndOfLine();
            _bufferViewManager.create("", "*CommandInput*");

            // Let text editing behave like emacs
            import behavior.emacs;
            _editorBehavior = new EmacsBehavior(this);
        }


        // editorcommands.register(this);
		editors = new Editors;
	}

	~this()
	{
	}

    static bool wakeExisting(string[] args)
    {
        // Try to connect to an existing instance and pass the args
        import std.socket;

        auto addr = new InternetAddress("127.0.0.1", 13575);
        auto sock = new TcpSocket();
        sock.blocking = false;
        sock.connect(addr);
        auto readSockets = new SocketSet();
        auto writeSockets = new SocketSet();
        auto errSockets = new SocketSet();
        writeSockets.add(sock);
        readSockets.add(sock);

        import core.time;
        auto count = Socket.select(readSockets, writeSockets, errSockets, dur!"msecs"(100));
        if (count <= 0 || !writeSockets.isSet(sock))
            return false;

        readSockets.reset();
        writeSockets.reset();
        errSockets.reset();

        readSockets.add(sock);

        string cmdline = std.conv.to!string(args.map!(a => "\"" ~ a ~ "\"").joiner(" ").array);
        sock.send("commandline " ~ cmdline);

        count = Socket.select(readSockets, writeSockets, errSockets, dur!"msecs"(100));
        if (count <= 0 || !readSockets.isSet(sock))
            return false;

        char[8] buf;
        auto bytesReceived = sock.receive(buf);
        return bytesReceived >= 2 && "ok" == buf[0..2];
    }

	static Application create(GUI gui = null)
	{
		if (gui is null)
        {
            // TODO: Dependency injection
            version (all)
                gui = GUI.create();
            else
            {
                import graphics.graphicssystem;
                GraphicsSystem gs = new NullGraphicsSystem();
                gui = GUI.create(gs);
            }
        }

		auto app = new Application(gui);
		app.guiRoot.onFileDropped.connect(&app.onFileDropped);
		return app;
	}


    //shared GrowableCircularQueue!(shared IWorker) _mainThreadWorkQueue;
    shared RWQueue!(shared IWorker) _mainThreadWorkQueue;

    void pushMainThreadWork(IWorker worker)
    {
        _mainThreadWorkQueue.pushBusyWait(cast(shared)worker);
        wakeMainThread();
    }

    void handleMainThreadWorkQueue()
    {
        while (!_mainThreadWorkQueue.empty)
        {
            auto w = cast(IWorker)_mainThreadWorkQueue.pop();
            w.work();
        }
    }

    auto signalOnMainThread(alias sig)()
    {
        import std.traits;
        class DelayedSignal : IWorker
        {
            alias SigParams = Parameters!(sig.connect);
            mixin Signal!SigParams onSignal;

            alias connect = onSignal.connect;
            alias connectTo = onSignal.connectTo;
            alias disconnect = onSignal.disconnect;
            alias unhook = onSignal.unhook;

            private SigParams _params;
            private Application _app;

            private this(Application app)
            {
                _app = app;
                sig.connect(&this.collect);
            }

            private void collect(SigParams p)
            {
                _params = p;
                _app.pushMainThreadWork(this);
            }

            void work()
            {
                onSignal.emit(_params);
            }
        }
        return new DelayedSignal(this);
    }

    auto mainThreadRelay(Dlg)(Dlg dlg)
    {
        import std.traits;
        //class RelaySignal : IWorker
        //{
        //    Dlg _dlg;
        //    alias Params = Parameters!Dlg;
        //
        //    alias slot_t = void delegate(Params);
        //    slot_t slot;
        //
        //    private Params _params;
        //    private Application _app;
        //
        //    private this(Application app, Dlg d)
        //    {
        //        _app = app;
        //        _dlg = d;
        //    }
        //
        //    void opCall(Params params)
        //    {
        //        _params = params;
        //        _app.pushMainThreadWork(this);
        //    }
        //
        //    void work()
        //    {
        //        slot(_params);
        //    }
        //}

        alias Params = Parameters!Dlg;
        return (Params params)
                {
                    class RelayWorker : IWorker
                    {
                        private Params _params;
                        this (Params p)
                        {
                            _params = p;
                        }

                        void work()
                        {
                            dlg(_params);
                        }
                    }

                    pushMainThreadWork(new RelayWorker(params));
                };

        //return (new RelaySignal(this, dlg)).opCall;
    }

    void setLog(Log l)
    {
        log.onInfo.disconnect(&appendConsoleMessage);
        setGlobalLog(l);
        log.onInfo.connect(&appendConsoleMessage);
    }

    // super()
    @RPC
    void setLogFile(string path)
    {
        setLog(new Log(path));
    }

    @RPC
    void bufferViewParamTest(BufferView b)
    {
        b.scrollDown(1);
    }

    @RPC
    void addCommand(Command c)
    {
        commandManager.add(c);
    }

    @RPC
    void addMenuItem(string commandName, MenuItem menuItem)
    {
        if (!menuItem.path.empty)
        {
            if (menuItem.argument is null)
            {
                menu.addTreeItem(menuItem.path, commandName);
            }
            else
            {
                auto args = commandManager.parseCommandArguments(commandName, menuItem.argument);
                menu.addTreeItem(menuItem.path, commandName, args);
            }
        }
    }

    @RPC
    void addCommandShortcuts(string commandName, Shortcut[] shortcuts)
    {
        import std.stdio;

        foreach (sc; shortcuts)
        {
            if (sc.argument is null)
                editorBehavior.keyBindings.setKeyBinding(sc.keySequence, commandName);
            else
                editorBehavior.keyBindings.setKeyBinding(sc.keySequence, commandName, sc.argument);
        }
    }

    // super()
    private void appendConsoleMessage(string msg, LogLevel level)
    {
		import std.conv;
		auto view = bufferViewManager["*Messages*"];
		view.insert(text(msg));
		view.insert("\n");
    }

    // super()
	void addMessage(Types...)(Types msgs)
	{
		dccore.log.log.i(msgs);
    }

    @RPC
    void onFileDropped(string path)
	{
		analyticEvent("core", "fileDrop");
		addMessage("Dropped file %s ", path);
		path = path.replace("\\", "/");
		openFile(path);
	}

    static struct Config
    {
        string behavior; // emacs, vs, vim
    }

    void loadKeyBindings(string fileName, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
    {
        static class Rule
        {
            string key;
            string operator;
            string value;
            string type;
            bool negated;
        }

        static class KeyMapping
        {
            string keys;
            string command;
            string argument;
            Rule[] rules;
        }

        static class KeyMappings
        {
            KeyMapping[] mappings;
        }

        static import gui.ruleset;

        GenericResource keyMappingsResource = getUpdated(fileName, base);

        KeyMappings mappings = keyMappingsResource.get!KeyMappings();
        if (mappings is null)
        {

            KeyMappings m = new KeyMappings;
            KeyMapping mp = new KeyMapping;
            mp.keys = "<ctrl> + i";
            mp.command = "d.dRocks";
            auto r = new Rule;
            r.key = "currentBufferName";
            r.operator = "equals";
            r.value = "my buffer";
            r.type = "string";
            r.negated = false;
            mp.rules ~= r;
            m.mappings ~= mp;
            keyMappingsResource.add(m);
            keyMappingsResource.save();
            return;
        }

        auto bindingSet = editorBehavior.currentKeyBindingsSet;

        foreach (idx, m; mappings.mappings)
        {
            gui.ruleset.RuleSet ruleSet = null;
            if (m.rules.length)
            {
                ruleSet = new gui.ruleset.RuleSet();
                foreach (rule; m.rules)
                {
                    switch (rule.operator)
                    {
                        case "equals":
                            switch (rule.type)
                            {
                                case "int":
                                    ruleSet.addEquals(rule.key, rule.value.to!int, rule.negated);
                                    break;
                                case "string":
                                    ruleSet.addEquals(rule.key, rule.value, rule.negated);
                                    break;
                                default:
                                    addMessage("Invalid type in keymapping rule file '" ~ fileName ~ "' rule " ~ idx.to!string);
                                    continue;
                            }
                            break;
                        case "regex":
                            ruleSet.addRegex(rule.key, rule.value, "", rule.negated);
                            break;
                        case "containsRegex":
                            ruleSet.addRegexContains(rule.key, rule.value, "", rule.negated);
                            break;
                        default:
                            addMessage("Invalid operator in keymapping rule file '" ~ fileName ~ "' rule " ~ idx.to!string);
                            continue;
                    }
                }
            }
            if (m.argument is null)
                bindingSet.replaceKeyBinding(m.keys, m.command, ruleSet);
            else
            {
                if (auto cmd = commandManager.lookup(m.command))
                {
                    CommandParameter[] args;
                    cmd.getCommandParameterDefinitions().parseValues(args, m.argument);
                    bindingSet.replaceKeyBinding(m.keys, m.command, args, ruleSet);
                }
            }
        }
    }

	void run()
	{
		import core.runtime;
        Runtime.traceHandler = &myTraceHandler;
        registerCommandParameterPackHandlers();

        setupResourcesRoot();

		// guiRoot.locationsManager.baseURI = "resources/";

		scanResources();

		auto styleSheetPath = resourceURI("default.stylesheet", ResourceBaseLocation.resourceDir);
        log.v("Using stylesheet %s", styleSheetPath);
        defaultStyleSheet = guiRoot.styleSheetManager.load(styleSheetPath);
		guiRoot.styleSheetManager.onSourceChanged.connect(&styleSheetSourceChanged);
		guiRoot.textureManager.onSourceChanged.connect(&textureSourceChanged);

        // Load and apply keybindings overrides
		commandManager.create("app.toggleCommandArea", "Toggle visibility of the command area in the current active window",
							  createParams(""),
							  delegate(CommandParameter[] v)
							  {
								  CommandControl cc = guiRoot.activeWindow.userData.get!WindowData().commandControl;
								  bool isShown = cc.isShown;

								  auto val = v[0].peek!string();
								  if (val !is null)
									  cc.setCommand(*val);

								  if (isShown)
									  cc.show(CommandControl.Mode.hidden);
								  else
									  cc.show(CommandControl.Mode.multiline);
							  });

		commandManager.create("app.cycleBuffers", "Cycle through buffers in the current active window",
							  createParams(1),
							  (CommandParameter[] v)
							  {
								  import std.conv;
								  auto cc = guiRoot.activeWindow.userData.get!WindowData().commandControl;

								  if (!cc.isShown )
									  cc.show(CommandControl.Mode.multiline);

								  int val = 1;
								  auto valPtr = v[0].peek!int();
								  if (valPtr !is null)
									  val = *valPtr;

								  // Initial cycle. The following cycling is handled by the command widget onCommand()
								  cc.cycleBuffers(val);
							  });

		//                      delegate(std.variant.Variant v)
		//                      {
		//                          import std.conv;
		//                          auto bufNames = getActiveBufferCompletions("");
		//                          if (bufNames.empty)
		//                              return;
		//
		//                          // locate current visible buffer
		//                          auto visibleBuffer = getVisibleBuffer();
		//                          int startOffset = 0;
		//                          if (visibleBuffer !is null)
		//                          {
		//                             foreach (idx, bufName; bufNames)
		//                             {
		//                                if (bufName == visibleBuffer.name)
		//                                {
		//                                    startOffset = idx;
		//                                    break;
		//                                }
		//                             }
		//                          }
		//
		//                          auto valPtr = v.peek!string();
		//                          string val = "1";
		//                          if (valPtr !is null)
		//                              val = *valPtr;
		//
		//                          int focusOrderOffset = (startOffset + val.to!int()) % bufNames.length;
		//                          auto name = bufNames[focusOrderOffset < 0 ? bufNames.length - focusOrderOffset : focusOrderOffset];
		//                          previewBuffer(name);
		//                      });

		guiRoot.init();

        _asyncIO = new AsyncIO();
        guiRoot.registerCustomEventType(_asyncIO.customEventType);

        import derelict.sdl2.sdl;
        g_sdlCustomEventType = SDL_RegisterEvents(1);

        guiRoot.registerCustomEventType(g_sdlCustomEventType);

		import libasync : DWFileEvent;
        static import platform.config;

        _asyncIO.watchDir(platform.config.resourcesRoot, DWFileEvent.ALL,  true).then( (WatchDirResult r) {
            // log.i("Watching dir %s", r.success);
            resourceDirWatcherQueue = r.changesRange;
            //// TODO: append... do not just set the queue
            //while (!r.changesRange.empty)
            //{
            //    auto item = r.changesRange.pop();
            //    resourceDirWatcherQueue.pushBusyWait(item);
            //}
        });


        foreach (loc; [ ResourceBaseLocation.executableDir /* , ResourceBaseLocation.userDataDir */ ])
        {
            string extensionsDir = platform.config.resourceURI("extensions", loc).uriString;
            if (exists(extensionsDir))
            {
                _asyncIO.watchDir(extensionsDir, DWFileEvent.ALL,  true).then( (WatchDirResult r) {
                    // TODO: append... do not just set the queue
                   extensionsDirWatcherQueue = r.changesRange;
                   //if (r.success)
                   //{
                   //     while (!r.changesRange.empty)
                   //     {
                   //         auto item = r.changesRange.pop();
                   //         extensionsDirWatcherQueue.pushBusyWait(item);
                   //     }
                   //}
                });
                // scheduleExtensionsDirScan(extensionsDir);
            }
        }

        ushort port = 13575;
        _asyncIO.tcpListen("127.0.0.1", port, &acceptTcpConnection);

        /*
        _syncIO.tcpListen("127.0.0.1", 13575, void delegate(TCPEvent) delegate(AsyncTCPConnection conn) {
            enum bufSize = 4096;
            ubyte[bufSize] buf;
            return (TCPEvent ev) {
                switch (ev)
                {
                    case TCPEvent.CONNECT:
                        // just connected
                        break;
                    case TCPEvent.READ:
                        uint bytesRead = bufSize + 1;

                        while (bytesRead >= bufSize)
                        {
                            bytesRead = conn.read(buf);

                        }
                        break;
                    case TCPEvent.WRITE:
                        // ?
                        break;
                    case TCPEvent.CLOSE:

                        break;
                }
            };
        });
        */

        //_tcpCommandTid = spawn(&tcpCommandHandler, thisTid);

        // Regular check will also be called on every refocus or async job completion
        regularCheck();

        // TODO: get rid of this active polling
        //timeout(dur!"msecs"(500), &regularCheck);

		//guiRoot.timeout(dur!"msecs"(500), );

		setupMainWindow();

		import extensionapi : extInit = init, extFini = fini;
		auto exceptions = extInit(this);
        foreach (e; exceptions)
            addMessage(e.toString());

        reloadKeyMappings();

		loadSession();

        // Show window now that session has loaded the old size and position of the window
        activeWindow.show();

    	analyticStopTiming("core", "startup");

		guiRoot.onActivity.connect(&handleActivity);

		guiRoot.run();

        guiRoot.outputProfile(log());

        analyticEvent("core", "stop");
		if (analytics !is null)
			analytics.stop();

		extFini(this);
		saveSession();

		if (!_restartExecutable.empty)
		{
			import std.process;
			version (Windows)
			{
			    spawnProcess(_restartExecutable);
			}

            version (linux)
			{
    		    string[] argv;
    		    execv(_restartExecutable, argv);
			}
		}

        _asyncIO.kill();
	}

	private void delegate(TCPEvent) acceptTcpConnection(AsyncTCPConnection conn)
    {
        auto h = new TCPClient(conn);
        _connectedTcpClientQueue.pushBusyWait(cast(shared)h);
        return &h.handleEvent;
    }

    private void handleActivity()
	{
		// Since this is called by onActivity the futures supported currently are only those
		// being fulfilled by an activity ie. key press, mouse move etc.

	    doMainFiberWork();
		handleFiberFutures();
		handlePromptQuery();
		doCommandCalls();
        handleNewTCPClients();
        handleTCPClientCommands();
        handleMainThreadWorkQueue();
    }

    private void handleNewTCPClients()
    {
        while (!_connectedTcpClientQueue.empty)
        {
            auto c = _connectedTcpClientQueue.pop();
            assumeSafeAppend(_connectedTcpClients);
            auto tcpClient = cast(TCPClient)c;
            _connectedTcpClients ~= tcpClient;

            import std.functional;
            tcpClient.onQueuesUpdated.connectTo(() { wakeMainThread(); });
        }
    }

    private void handleTCPClientCommands()
    {
        for (int i = 0; i < _connectedTcpClients.length; )
        {
            auto c = _connectedTcpClients[i];
            if (c.isClosed)
            {
                commandManager.remove((cmdName, cmd) {
                    import extensionapi.remotecommand : RemoteCommand;
                    auto rcmd = cast(RemoteCommand)cmd;
                    if (rcmd is null)
                        return false;
                    bool res = rcmd.client is c;
                    if (res)
                    {
                        // Remove shortcuts for commands
                        editorBehavior.keyBindings.clearKeyBinding(cmdName);
                        menu.removeTreeItemByCommand(cmdName);
                    }
                    return res;
                });

                _connectedTcpClients[i] = _connectedTcpClients[$-1];
                _connectedTcpClients.length--;
                assumeSafeAppend(_connectedTcpClients);
                continue;
            }
            while (c.hasAPICall)
            {
                APICall apiCall = c.popAPICall();
                bool ok = false;
                try
                {
                    apiCall.execute(&lookupAPIObject);
                }
                catch (Exception e)
                {
                    log.e("Error handling tcp client command %s", e.toString());
                }
            }
            ++i;
        }
    }

    Object lookupAPIObject(string objectType, string objectID)
    {
        import extensionapi.remotecommand;
        switch (objectType)
        {
            case "Application":
                return this;
            case "BufferView":
                return bufferViewManager[objectID.to!int];
            case "RemoteCommandRegistrar":
                CommandManager mgr = commandManager;
                return new RemoteCommandRegistrar(mgr, &lookupAPIObject);
            default:
                return null;
        }
    }

	private void handlePromptQuery()
	{
		if (_promptStack.empty)
			return;

		// If another command control query is already shown we wait for the users answer
		CommandControl cc = guiRoot.activeWindow.userData.get!WindowData().commandControl;
		if (cc.isShown)
			return;

		auto q = _promptStack.top;

		cc.setPrompt(q.question, q.answer, (bool success, string answer) {
			auto result = new PromptQueryResult;
			result.answer = answer;
			result.success = success;
			q.promise.setValue(result);
			_promptStack.remove(q);
		}, q.validationDg, q.getCompletionsDg);
	}

	void scheduleRestart(string exePath)
	{
		_restartExecutable = exePath;
		guiRoot.stop();
	}

    @RPC
    void quit()
    {
		_asyncIO.stopWorker();
        guiRoot.stop();
    }

    @RPC
    string hello(string yourName)
    {
        return "Hello to you : " ~ yourName;
    }

    void setKeyBinding(string keySequence, string cmd)
    {
        editorBehavior.keyBindings.setKeyBinding(keySequence, cmd);
    }

	void setupResourcesRoot()
	{
        import platform.config : resourcesRoot, binariesRoot;

        version (portable)
        {
            import dccore.pack;
            string destDir = FilePack!"resources.pack"().unpack();
            resourcesRoot = buildPath(destDir, "resources");
            writeln("Unpack dir ", destDir);
            destDir = FilePack!"binaries.pack"().unpack();
            binariesRoot = buildPath(destDir, "binaries");
            writeln("Unpack dir ", destDir);
        }
        else
        {
            resourcesRoot = absolutePath("resources", thisExePath().dirName());
            debug
                binariesRoot = absolutePath("binaries", thisExePath().dirName());
            else
                binariesRoot = absolutePath(thisExePath().dirName());
        }
	}

	void setupRegistryEntries()
	{
		import std.uuid;
		import platform.config;
        // addFileBrowserContextMenuItem("Open with DeadCode", r"C:\Projects\D\ded\ded-debug_d.exe");
        analyticsKey = getOrSetConfigField("analyticsKey", randomUUID().toString());
	}


	void scanResources()
	{
		guiRoot.locationsManager.scan(resourceURI("*", ResourceBaseLocation.resourceDir));
	}

    void setCurrentDirectory(string path)
    {
        chdir(path);
        onResourceBaseLocationChanged.emit(ResourceBaseLocation.currentDir);
    }

	Window createWindow(string name = "mainWindow", int width = 854, int height = 900)
        //    Window createWindow(string name = "mainWindow", int width = 705, int height = 658) // maineditor.png
        // Window createWindow(string name = "mainWindow", int width = 600, int height = 300) // maineditor.png
        //        Window createWindow(string name = "mainWindow", int width = 854, int height = 480) // blog posts (Wide 480p format)
	{
		auto win = guiRoot.createWindow(name, width, height);
		win.styleSheet = defaultStyleSheet;
		return win;
	}

	/**
    CSS style selector for querying a widget e.g.
    Window.mainWindow > .main ErrorListWidget
    can even get detached widget using
    Window.mainWindow ErrorListWidget
    or for all windows just
    ErrorListWidget
	*/
	Widget queryWidget(string selector)
	{
		import std.regex;
		auto toks = split(selector, regex("\\s+"));
		return null;
	}

    T getWidget(T = Widget)(string name)
    {
        return cast(T) guiRoot.activeWindow.getWidget(name);
    }

	private void setupMainWindow()
	{
        import platform.display : getExistingWindowRect;
		Rectf existingRect;
		bool gotRect = getExistingWindowRect(&existingRect);
		auto win = createWindow("Deadcode", 1280, 720);
		if (gotRect)
		{
            import std.stdio;
			win.position = existingRect.pos;
			writeln(existingRect.size);
            win.size = existingRect.size;
		}

		// A main widget
		// _mainWidget = new Widget(win, 100, 100, 20, 32);

		// Widget that contains all editor widgets
		_editorStack = new Widget(win, 100, 100, 20, 32);
		_editorStack.layout = new StackLayout();

		// A widget that can be mousedowned and resize the window
		Widget _resizerWidget = new Widget(win, 0, 0, 24, 24);
        _resizerWidget.zOrder = 500f;
		_resizerWidget.features ~= new WindowResizer();

		// A widget that can be mousedowned and move the window
		//Widget _draggerWidget = new Widget(win, 0, 0, 20, 32);
		//_draggerWidget.features ~= new WindowDragger();

		// A widget that can be mousedowned and move the window
		//Widget _draggerRightWidget = new Widget(win, 0, 0, 20, 32);
		//_draggerRightWidget.features ~= new WindowDragger();

		/*
        ScalarExpr e = new ScalarExpr(mainWidget, WidgetAnchor.Top, 10);

        resizerWidget.top = mainWidget.top + 10;
        resizerWidget.mid = mainWidget.width * 0.5f;

        resizeWidget.top = 0;       // default to px offset from parent top;
        resizerWidget.width = 10;   // default to px width

        resizerWidget.width = rel(1.0f); // default to rel to parent width
        resizerWidget.top = rel(0);       // default to pct offset from parent top by parent height;
        resizerWidget.top = rel(0.1f, WidgetAnchor.Width);       // default to pct offset from parent top by parent height;
        resizerWidget.top = rel(0.1f, WidgetAnchor.Width, mainWidget);       // default to pct offset from parent top by parent height;
        resizerWidget.top = rel(0.1f, WidgetAnchor.Width, mainWidget) + 10;       // default to pct offset from parent top by parent height;
        resizerWidget.top = rel(0.1f) + px(10);       // default to pct offset from parent top by parent height;


        resizeWidget.top = 0;       // default to px offset from parent top;
        resizerWidget.width = 100.pct();   // default to px width
        resizerWidget.heigth = 10.px();
        */
		// Layout expanding mainWidget to window
		// _editorStack.alignToWindow(Anchor.TopLeft);
		// _mainWidget.alignTo(_draggerWidget, Anchor.BottomLeft, Anchor.TopLeft);
		//_editorStack.alignToWindow(Anchor.BottomRight);
		_editorStack.name = "main";

		// Layout setting resizerWidget at bottom left of mainWidget
		_resizerWidget.alignToWindow(Anchor.BottomRight, _resizerWidget.rect.size);
		_resizerWidget.name = "resizer";

		// Layout setting dragger widget fill top 20px of mainWidget
		//_draggerWidget.alignToWindow(Anchor.TopLeft, Vec2f(220, 24), Vec2f(0,0f));
		//_draggerWidget.name = "dragger";

		//_draggerRightWidget.alignTo(_draggerWidget, Anchor.TopRight, Anchor.TopLeft, Vec2f(-1, 24));
		//_draggerRightWidget.alignTo(NullWidgetID, Anchor.TopRight, Anchor.TopRight);
		//_draggerRightWidget.name = "draggerRight";


		// _mainWidget.features ~= new BoxRenderer("window-main");

		// _draggerWidget.features ~= new BoxRenderer("window-head");
		// _resizerWidget.features ~= new BoxRenderer("window-resizer");

		//_draggerWidget.onMouseClickCallback = (Event e, Widget w)
		//{
		//    std.stdio.writeln("clicked ", w.pos.v, " ", w.size.v);
		//    return EventUsed.no;
		//};

		auto mainBuf = bufferViewManager["*Messages*"];
		mainBuf.cursorToEnd();
		mainBuf.clearUndoStack();
		showBuffer(mainBuf);

		// Add command control
		auto winData = new WindowData();
		win.userData = winData;
		BufferView bufferView = bufferViewManager["*CommandInput*"];
		CommandControl cc = new CommandControl(win, 379f, bufferView, this);
		cc.name = "command";
		// cc.alignToWindow(Anchor.TopCenter, Vec2f(600,-1), Vec2f(0,0));
		// cc.visible = false;
		winData.commandControl = cc;

		editorBehavior.onMissingCommandArguments.connect(&cc.onMissingCommandArguments);

		//auto w = new Widget();
		//w.parent = win;
		//w.name = "foo";
		//w.pos = Vec2f(100,200);
		//
		//auto w1 = new Widget();
		//w1.parent = w;
		//w1.name = "fooa";
		//w1.pos = Vec2f(100,200);
		//w1.size = Vec2f(10,10);
		//
		//auto w2 = new Widget();
		//w2.parent = w;
		//w2.name = "foob";
		//w2.pos = Vec2f(200,300);
		//w1.size = Vec2f(10,10);
		//
		//w.features ~= new DirectionalLayout!false();

		menu = new Menu(commandManager);
        menu.name = "Menu";
		menu.parent = win;
		menu.onMissingCommandArguments.connect(&cc.onMissingCommandArguments);

		import gui.control.notice;
        auto n = new Notice();
        n.parent = win;

        guiRoot.onEvent.connectTo((Event* ev) {
			// Let the shortcut handler do its magic before event is dispatched to
			// the widgets.
			switch (ev.type) with (EventType)
            {
                case Focus:
                    if (ev.on)
                        regularCheck();
                    break;
                case AsyncCompletion:
                    regularCheck();
                    break;
                default:
                    break;
            }

			ev.used = editorBehavior.onEvent(*ev) == EventUsed.yes;
        });

		// Let text editor handle events before normal gui
        //win.onEvent = (ref Event ev) {
        //    //if (used == EventUsed.yes)
        //
        //    //    return used;
        //    //return cc.onCommand(ev);
        //};
	}



	//GenericResource load(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	//{
	//    return guiRoot.genericResourceManager.load(resourceURI(path, base));
	//}

    GenericResource getLoaded(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
		// predeclare to sure that unsuccessful loads return a valid resource anyway.
		auto u = resourceURI(path, base);
		auto res = guiRoot.genericResourceManager.declare(u);
		if (res.loadState == LoadState.loaded)
			return res; // already loaded and ready
        return null;
    }

    GenericResource getUpdated(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
        GenericResource res = getLoaded(path, base);
        if (res is null)
        {
            // load it
            res = get(path, base);
        }
        else
        {
            // reload
            res.unload();
            res.load();
        }
        return res;
    }

    GenericResource get(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
		// predeclare to sure that unsuccessful loads return a valid resource anyway.
		auto u = resourceURI(path, base);
		auto res = guiRoot.genericResourceManager.declare(u);
		if (res.loadState == LoadState.loaded)
			return res; // already loaded and ready

		res.load();
		auto state = res.loadState;
		//if (state != LoadState.prepared)
		if (state != LoadState.loaded) // TODO: Fix to be prepared
		{
			const(Exception) ex = res.getLastException();
			string exMsg = "";
			if (ex !is null)
				ex.toString( (data) { exMsg ~= data; } );
			addMessage("Couldn't load %s (%s) %s", u.uriString, state, exMsg);
		}
		return res;
	}

    U getConfig(U)(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
    {
        auto resource = get(path, base);

        if (resource is null)
            return null;

        auto firstObjectInResource = resource.get!U();
        if (firstObjectInResource is null)
        {
            firstObjectInResource = new U();
            resource.add(firstObjectInResource);
        }

        return firstObjectInResource;
    }

    private static string normalizePath(string path)
    {
        import platform.config;
        auto de = statFilePathCase(path.absolutePath);
		path = de.replace("\\", "/");
        return path;
    }

	BufferView openFile(string path, bool show = true)
	{
		path = normalizePath(path);

        auto existingBuffer = bufferViewManager[path];
		if (existingBuffer !is null)
		{
			if (show)
                showBuffer(existingBuffer);
			return existingBuffer;
		}

		addMessage("Opening %s", path);

		if (!exists(path))
		{
			addMessage("Cannot open non-existing file : %s", path);
			return null;
		}

        static import std.stdio;
		std.stdio.File file;
		try
			file = std.stdio.File(path, "rb");
		catch (std.exception.ErrnoException e)
		{
            static import core.stdc.errno;
			string msg = std.conv.text(e);
			if (e.errno == core.stdc.errno.ENOENT)
				msg = "No such file";

			addMessage("Error opening file : %s", msg);
			return null;
		}
		auto view = bufferViewManager.create("", path);
		view.isPersistant = true;
		view.ensureCapacity(cast(uint)file.size);

		//view.buffer.gbuffer.ensureGapCapacity(cast(uint)file.size);
		auto r = file.byLine!(char,	char)(std.stdio.KeepTerminator.yes, '\x0a');
		foreach (line; r)
		{
			view.insert(std.conv.text(line));
		}
		view.cursorToStart();
		view.clearUndoStack();

        // In order to be able to center on line before a redraw we set the visible line count from the current
        // active buffer
        auto curBV = getVisibleBuffer();
        if (curBV)
            view.visibleLineCount = curBV.visibleLineCount;

		if (show)
            showBuffer(view);
        else
            ensureTextEditor(view);

        // debug view.enableUndoStackDumps();
		view.onBufferModified.connect(&bufferModified);
		// addMessage("Read %s", view.name);

        onFileOpened.emit(view);
		return view;
		//Application.activeEditor.show(view);
	}

	BufferView createBuffer(string name = null)
	{
		auto view = bufferViewManager.create("", name);
		addMessage("Create buffer %s", view.name);
		view.onBufferModified.connect(&bufferModified);
		return view;
	}

	BufferView getOrCreateBuffer(string name)
	{
        auto view = bufferViewManager[name];
        if (view !is null)
            return view;
        return createBuffer(name);
	}

	private void bufferModified(BufferView b)
	{
		// Make a backup copy
		if (std.file.exists(b.name))
			backupFile(b.name);
	}

	private void backupFile(string path)
	{
		string to = resourceURI( path.stripDrive() ).uriString;
		std.file.mkdirRecurse(to.dirName());
		std.file.copy(path, to);
	}

	CompletionEntry[] getActiveBufferCompletions(string prefix)
	{
		// current buffer name is most likely "command" buffer and not an active editor
		import util.string;

        //writeln("++++++++++++++++++++++++++++++++++++++++++++");
        //foreach (item; editors.editors.values
        //    .filter!(a => a.editor.bufferView.name.startsWith(prefix))
        //    .array
        //    .sort!("a.focusOrder > b.focusOrder"))
        //{
        //    writeln(item.focusOrder, ": ", item.editor.bufferView.name);
        //}
        //writeln("------------------------------------------");

        return editors.editors.values
            .filter!(a => a.editor.bufferView.name.startsWith(prefix))
            .array
            .sort!("a.focusOrder > b.focusOrder")
            .map!((a) => a.editor.bufferView.name)
            .uniquePostfixPath
            .map!(a => CompletionEntry(a[0], a[1]))
            .array;
	}

	string[] getBufferCompletions(string prefix)
	{
		return std.array.array(bufferViewManager.buffers.values.map!"a.name".filter!(a => a.startsWith(prefix))());
	}

    private TextEditor ensureTextEditor(BufferView buf)
    {
        EditorInfo* w = buf.id in editors.editors;

        if (w !is null)
            return w.editor;

		//a create a new widget for this buffer
		auto editorWidget = new TextEditor(buf);
        editorWidget.onGlyphMouseUp.connect(&textEditorGlyphClicked);

        editorWidget.parent = _editorStack;
		// guiRoot.timeout(dur!"msecs"(500), () { editorWidget.toggleCursorVisibility(); return true; });
		//editorWidget.alignTo(Anchor.TopLeft, Vec2f(-1, -1), Vec2f(6,0));
		//editorWidget.alignTo(Anchor.BottomRight);
		editors.editors[buf.id] = EditorInfo(++editors.focusOrderCounter, editorWidget);
		editorWidget.name = "editor-buffer-" ~ buf.id.to!string;
		editorWidget.onKeyboardFocusCallback = (Event ev, Widget w) {
			EditorInfo* info = &(editors.editors[buf.id]);
            info.focusOrder = ++editors.focusOrderCounter;
			currentBuffer = buf;
			return EventUsed.yes;
		};

		import edit.language;
		auto dinfo = manager().lookupByFileExtension(extension(buf.name));
		if (buf.codeModel is null && dinfo !is null)
        {
			buf.codeModel = dinfo.createModel(buf);
        }
        else
        {
            buf.onChanged.connect(&detectCodeModel);
        }

        buf.onCodeModelChanged.connect(&codeModelChanged);

        if (editorWidget.textStyler is null)
            editorWidget.textStyler = createTextStyler(buf);

        bufferViewManager.onBufferViewRenamed.connect(&bufferViewRenamed);
        return editorWidget;
    }

	private auto setBufferVisible(BufferView buf)
	{
		_editorStack.hideChildren();
	    auto w = ensureTextEditor(buf);
		w.visible = true;
		return w;
	}

    private void bufferViewRenamed(BufferView buf, string oldName)
    {
        // Check if the codeModel shoudl be set/changed
        import edit.language;
        auto dinfo = manager().lookupByFileExtension(extension(buf.name));
        if (dinfo !is null && (buf.codeModel is null || buf.codeModel.codeIntel !is dinfo))
            buf.codeModel = dinfo.createModel(buf);
    }

    private void detectCodeModel(BufferView b, int index, int count, bool addOrRemove)
    {
        if (b.codeModel is null)
        {
            import edit.language;
            auto dinfo = manager().detect(b);
            if (dinfo !is null)
            {
               // std.signals doesn't support emitting from emitted signal that also disconnects something
               // unrelated. Weird... but work around it by delaying actual work a bit.
               pushMainFiberWork(() {
                   b.codeModel = dinfo.createModel(b);
                   b.onChanged.disconnect(&detectCodeModel);
               });
            }
        }
        else
        {
             b.onChanged.disconnect(&detectCodeModel);
        }
    }

    private void codeModelChanged(BufferView bv, ICodeModel old)
    {
        // Check if the highlighter should be changed
        auto editor = bv.id in editors.editors;
        if (editor !is null)
        {
            assert(editor.editor !is null);
            editor.editor.textStyler = createTextStyler(bv);
        }
    }

    private void textEditorGlyphClicked(Event event, GlyphHit info)
    {
		if ((event.mouseMod & KeyMod.CTRL) && (event.mouseButtonsChanged & Event.MouseButton.Left))
        {
            // Hardcode this commmand for now until keymappings supports mouse presses
            // TODO: Fix
            commandManager.execute("d.gotoDefinition", null);
        }
    }

	@RPC
    TextEditor getCurrentTextEditor()
	{
		foreach (k,v; editors.editors)
		{
			if (v.editor.visible)
				return v.editor;
		}
		return null;
	}

	TextEditor getTextEditorForBufferView(BufferView bv)
	{
		foreach (k,v; editors.editors)
		{
			if (v.editor.bufferView is bv)
				return v.editor;
		}
		return null;
	}

	TextEditor getTextEditorForFile(string path)
	{
        // open the file in background if needed
        auto bv = openFile(path, false);

        foreach (k,v; editors.editors)
		{
			if (v.editor.bufferView is bv)
				return v.editor;
		}
        return null;
	}

	@RPC
    BufferView getCurrentBuffer()
    {
        return getVisibleBuffer();
    }

	// deprecated
	BufferView getVisibleBuffer()
	{
		auto e = getCurrentTextEditor();
		return e is null ? null : e.bufferView;
	}

	BufferView getRecentNonCommandBuffer()
	{
		auto b = getCurrentBuffer();
		if (b.name == "*CommandInput*")
			return previousBuffer;
		return b;
	}

	void previewBuffer(string name)
	{
		auto buf = bufferViewManager[name];
		if (buf is null)
		{
			addMessage("Cannot preview unknown buffer '%s'", name);
			return;
		}
		previewBuffer(buf);
	}

	void previewBuffer(BufferView buf)
	{
		setBufferVisible(buf);
	}

	bool hasBuffer(string name)
    {
        return bufferViewManager[name] !is null;
    }

	void showBuffer(string name)
	{
		auto buf = bufferViewManager[name];
		if (buf is null)
		{
			addMessage("Cannot show unknown buffer '%s'", name);
			return;
		}
		showBuffer(buf);
	}

	void showBuffer(BufferView buf)
	{
		auto w = setBufferVisible(buf);
		w.setKeyboardFocusWidget();
		currentBuffer = buf;
	}

	void scheduleWidgetPlacement(Widget placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc)
	{
		_widgetLocationUpdater.scheduleWidgetPlacement(placeThisWidget, relativeToWidgetWithThisName, loc);
	}

	enum WidgetPlacementResult
	{
		success,
		unknownRelativeWidget,
		placementInsideNotPossible,
	}

	WidgetPlacementResult placeWidgetRelative(Widget placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc)
	{
		Widget w = guiRoot.activeWindow.getWidget(relativeToWidgetWithThisName);
		if (w is null)
		{
			return WidgetPlacementResult.unknownRelativeWidget;
		}
		else
		{
			Widget layoutWidget = null;

			// TODO: fix bottom and right positions
			final switch (loc)
			{
				case RelativeLocation.bottomOf:
					bool horz = true;
					auto lo = cast(GridLayout)w.layout;
					if (lo !is null && lo.direction == GridLayout.Direction.column)
					{
						placeThisWidget.parent = w;
					}
					else
					{
						auto newLayout = new Widget();
						//newLayout.features ~= new VerticalLayout(false, VerticalLayout.Mode.scaleChildren);
						newLayout.layout = new GridLayout(GridLayout.Direction.column, 1);

						//newLayout.features ~= new VerticalLayout(false);
						w.parent.replaceChild(w, newLayout);
						w.parent = newLayout;
						// w.features = w.features.filter!(a => cast(ConstraintLayout)a is null).array;
						w.manualLayout = false;
						placeThisWidget.parent = newLayout;
					}
					break;
				case RelativeLocation.topOf:
					bool horz = true;
					layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w);
					break;
				case RelativeLocation.leftIn:
					bool horz = false;
					layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
					if (layoutWidget !is null)
						placeThisWidget.parent = layoutWidget;
					break;
				case RelativeLocation.rightIn:
					bool horz = false;
					layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
					break;
				case RelativeLocation.above:
					bool horz = true;
					layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w);
					if (layoutWidget is w)
						layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w.parent);
					if (layoutWidget !is null)
						placeThisWidget.parent = layoutWidget;
					break;
				case RelativeLocation.below:
					bool horz = true;
					layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w);
					if (layoutWidget is w)
						layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w.parent);
					break;
				case RelativeLocation.leftOf:
					bool horz = false;
					layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
					if (layoutWidget is w)
						layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w.parent);
					if (layoutWidget !is null)
						placeThisWidget.parent = layoutWidget;
					break;
				case RelativeLocation.rightOf:
					bool horz = false;
					layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
					if (layoutWidget is w)
						layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w.parent);
					break;
				case RelativeLocation.inside:
					layoutWidget = getFirstAncestorWithLayout!StackLayout(w);
					if (layoutWidget is w)
						placeThisWidget.parent = w;
					else
					{
						return WidgetPlacementResult.placementInsideNotPossible;
						//addMessage("Cannot put widget '%s' inside widget '%s'", placeThisWidget.name, relativeToWidgetWithThisName);
					}
					break;
			}
		}
		return WidgetPlacementResult.success;
	}

	private Widget getFirstAncestorWithLayout(LayoutType)(Widget _parent)
	{
		while (_parent !is null)
		{
			if ( (cast(LayoutType)(_parent.layout)) !is null)
				return _parent;
			_parent = _parent.parent;
		}
		return null;
	}

	private Widget getFirstAncestorWithFeature(FeatureType)(Widget _parent)
	{
		while (_parent !is null)
		{
			if (getFeatureByType!FeatureType(_parent) !is null)
				return _parent;
			_parent = _parent.parent;
		}
		return null;
	}

	private FeatureType getFeatureByType(FeatureType)(Widget w)
	{
		foreach (f; w.features)
		{
			auto ft = cast(FeatureType)f;
			if (ft !is null)
				return ft;
		}
		return null;
	}

    void repaintAll()
    {
        guiRoot.activeWindow.repaint();
    }

	private void styleSheetSourceChanged(StyleSheet sheet)
	{
		analyticEvent("core", "changed", "stylesheet", sheet.uri.uriString);
		sheet.load();
		guiRoot.activeWindow.onStyleSheetChanged();
		guiRoot.activeWindow.repaint();
	}

	private void textureSourceChanged(GTexture tex)
	{
		analyticEvent("core", "changed", "texture", tex.uri.uriString);
		tex.load();
	}

	private bool regularCheck()
    {
        checkResourceDirForChanges();
        checkExtensionsDirForChanges();
        updateDelayedWidgetLocations();
        if (auto ed = getCurrentTextEditor())
            ed.toggleCursorVisibility();
        return true;
    }

    private void updateDelayedWidgetLocations()
    {
        _widgetLocationUpdater.performLocationUpdates();
    }

    // The dir change watches thread puts changes into a queue.
    // Here we simply check if there is something in the queue and scan resources.
    // Note that the watching thread will wake up the main thread in case it notices some changes
    // and therefore we will get here process it.
    private void checkResourceDirForChanges()
	{
        if (resourceDirWatcherQueue is null)
            return;

        if (resourceDirWatcherQueue.clear())
            scanResources();
	}

    private void checkExtensionsDirForChanges()
	{
        // TODO: extensionsDirWatcherQueue might be null if not initialized yet by watchDIR
        if (extensionsDirWatcherQueue is null)
            return;

        while (!extensionsDirWatcherQueue.empty)
        {
            WatchDirChange info = extensionsDirWatcherQueue.pop();
            handleOutOfProcessExtensionCandidate(info.path);
        }
	}

    void scheduleExtensionsDirScan(string dirPath)
    {
        WatchDirChange ci = WatchDirChange();

        // TODO: extensionsDirWatcherQueue might be null if not initialized yet by watchDIR
        //if (extensionsDirWatcherQueue is null)
        //    extensionsDirWatcherQueue = new typeof(extensionsDirWatcherQueue);

        import std.file;
        foreach (f; dirEntries(dirPath, "*.d", SpanMode.depth))
        {
            ci.path = f;
            // log.i("bar4b2 %s", &extensionsDirWatcherQueue);
            extensionsDirWatcherQueue.pushBusyWait(ci);
        }
    }

    void handleOutOfProcessExtensionCandidate(string path)
    {
        // Check first ~4k bytes for "mixin registerCommandsRPC". If found then compile the extension
        // as out of process and (re)spawn it.
        if (!isFileOutOfProcessExtensionSource(path))
            return;

        commandManager.execute("deadcode.buildAndStartExtension", path);
    }

    class ProcessManager
    {

    }
    ProcessManager processManager;
   import std.process; Pid[string] _runningExtensionProcesses;

    @RPC
    void startExtension(string path)
    {
        log.i("Starting extension ", path);
        import std.process;
        import std.stdio;
        // TODO: Register all sub processes so that they can be killed on request by path name and also registered for KillWhenParentDies windows JobObject thingy
        //processManager.kill(path);
        //processManager.spawn(path, Config.suppressConsole);

        auto existingProcess = path in _runningExtensionProcesses;
        if (existingProcess !is null)
        {
            kill(*existingProcess);
            _runningExtensionProcesses.remove(path);
        }
        auto pid = spawnProcess(path, stdin, stdout, stderr, null, Config.suppressConsole);
        // Error check
        _runningExtensionProcesses[path] = pid;
    }

    private bool isFileOutOfProcessExtensionSource(string path)
    {
        import std.file;
        if (!exists(path))
            return false;
        if (isDir(path))
        {
            log.e("%s is directory and not extension", path);
            return false;
        }
        char[] data = cast(char[]) read(path, 4000);
        return data.canFind("mixin registerCommandsRPC");
    }

	static class SessionBuffer
	{
		this() {}
		int focusOrder;
		string path;
		int cursorPoint;
		int lineOffset;
	}

	static class SessionCopyBuffer
	{
		string[] entries;
	}

	static class Layout
	{
		bool horizontal;
		// name of the child widgets. In case the string is null it is a layout in the field below this.
		string[] childWidgetNames;
		Layout[string] childLayouts; // A child layout is always orthogonal to current layout ie. this.horizontal == !child.horizontal
	}

	static class SessionData
	{
		int focusOrderCounter;
		SessionBuffer[] buffers;
		SessionCopyBuffer copyBuffer;
		Layout windowLayout;
		Rectf windowRect;
	}

	void saveSession()
	{
		auto s = sessionData.get!SessionData();
		s.focusOrderCounter = editors.focusOrderCounter;
		s.buffers.length = 0;
		foreach (key, ed; editors.editors)
		{
			string bufferName = ed.editor.bufferView.name;
			if (bufferName == "*Messages*")
				continue;
			SessionBuffer data = new SessionBuffer;
			data.focusOrder = ed.focusOrder;
			data.path = bufferName;
			data.cursorPoint = ed.editor.bufferView.cursorPoint;
			data.lineOffset = ed.editor.bufferView.lineOffset;
			s.buffers ~= data;
		}

		auto scb = new SessionCopyBuffer;
		auto cb = bufferViewManager.copyBuffer;
		foreach (entry; cb.entries)
		{
			scb.entries ~= entry.txt.to!string;
		}
		s.copyBuffer = scb;

		auto winRect = Rectf(activeWindow.position, activeWindow.size);

		import derelict.sdl2.functions;
		import derelict.sdl2.types;
		SDL_DisplayMode dm;
		if (SDL_GetDesktopDisplayMode(0, &dm) != 0) {
		    addMessage("SDL_GetDesktopDisplayMode failed: %s", SDL_GetError());
		}
        else
        {
            winRect = Rectf(0, 0, dm.w, dm.h).clip(winRect);
        }

		s.windowRect = winRect;
		sessionData.save();
	}

	void loadSession()
	{
		sessionData = get("session");
		if (sessionData is null)
			return;

		auto s = sessionData.get!SessionData();
		if (s is null)
		{
			s = new SessionData;
			sessionData.add(s);
		}

        pushMainFiberWork(() {

		    editors.focusOrderCounter = s.focusOrderCounter;

		    string showBufferName;

		    foreach (l; s.buffers)
		    {
			    auto p = buildNormalizedPath(l.path);
			    BufferView bv = openFile(p);
			    if (bv is null)
				    continue;
			    if (l.focusOrder == s.focusOrderCounter)
				    showBufferName = p;
			    auto ed = editors.editors[bv.id];
			    ed.focusOrder = l.focusOrder;
			    // TODO: Save undo buffer
			    ed.editor.bufferView.cursorPoint = min(l.cursorPoint, ed.editor.bufferView.length);
			    ed.editor.bufferView.lineOffset = l.lineOffset;
			    ed.editor.bufferView.clearUndoStack();
		    }
		    if (!showBufferName.empty)
			    showBuffer(showBufferName);

		    editors.focusOrderCounter = s.focusOrderCounter;

		    auto cb = bufferViewManager.copyBuffer;

		    if (s.copyBuffer !is null)
		    {
			    foreach (data; s.copyBuffer.entries)
			    {
				    cb.entries ~= new CopyBuffer.Entry(data);
			    }
		    }
        });

        auto winRect = Rectf(s.windowRect.pos, s.windowRect.size);

        import derelict.sdl2.functions;
        import derelict.sdl2.types;

        SDL_DisplayMode dm;
        if (SDL_GetDesktopDisplayMode(0, &dm) != 0) {
            addMessage("SDL_GetDesktopDisplayMode failed: %s", SDL_GetError());
        }
        else
        {
            winRect = Rectf(0, 0, dm.w, dm.h).clip(winRect);

            const float minDim = 50;
            import std.math;

            if (fabs(winRect.w) < minDim)
            {
                winRect.x = 0;
                winRect.w = 300;
            }

            if (fabs(winRect.h) < minDim)
            {
                winRect.y = 0;
                winRect.h = 500;
            }
        }

        activeWindow.position = winRect.pos;
        activeWindow.size = winRect.size;
	}

    void reloadKeyMappings()
    {
        static class Config
        {
            string keyMappings;
        }

        editorBehavior.currentKeyBindingsSet.clear();

        // Re-register command extension shortcuts as defined by @Shortcut attribute
        import extensionapi.command : registerCommandKeyBindings;
        registerCommandKeyBindings(this);

        // Load global key mappings
        loadKeyBindings("key-mappings/key-mappings-global", ResourceBaseLocation.resourceDir);

        // Load config
        GenericResource configResource = getUpdated("config");
        Config config = configResource.get!Config();
        if (config !is null)
        {
            // Base behavior
            switch (config.keyMappings)
            {
                case "emacs":
                    loadKeyBindings("key-mappings-" ~ config.keyMappings);
                    break;
                default:
                    addMessage("Unknown behavior set in config. Must be 'emacs'");
            }
        }

        // User overridden behavior
        loadKeyBindings("key-mappings-user");
    }

	Future!PromptQueryResult prompt(string question, string answer = "", bool delegate(string) validationDg = null, CompletionEntry[] delegate(string) getCompletionsDg = null)
	{
		PromptQueryResult result;
		auto promise = new Promise!PromptQueryResult();
		auto q = new PromptQuery(question, answer, promise, validationDg, getCompletionsDg);
		_promptStack.push(q);
		return promise.getFuture();
	}

	PromptQueryResult yieldPrompt(string question, string answer = "", bool delegate(string) validationDg = null, CompletionEntry[] delegate(string) getCompletionsDg = null)
	{
		import core.thread;
		assert(Fiber.getThis() !is null);
		auto future = prompt(question, answer, validationDg, getCompletionsDg);
		yieldFuture(future);
		return future.get();
	}

    string showSelectFolderDialogBasic(string defaultDir)
    {
		import core.thread;
		enforce(Fiber.getThis() !is null);

        auto promise = new Promise!string();
        pushMainFiberWork( () {
            static import platform.dialog;
            string res = platform.dialog.showSelectFolderDialogBasic(defaultDir);
            promise.setValue(res);
        });
        yieldFuture(promise.getFuture());
        return promise.getFuture().get();
    }

    U yield(U, Args...)(U delegate(Args) dlg, Args args) if (!is(U == void))
    {
        import core.thread;
        enforce(Fiber.getThis() !is null);

        auto promise = new Promise!U();

        auto thread = new Thread( () {
            promise.setValue(dlg(args));
	        import derelict.sdl2.sdl;
	        SDL_Event event;
	        //   SDL_Zero(event); not needed since dlang does this
	        event.type = g_sdlCustomEventType;
	        SDL_PushEvent(&event);
        });

        thread.start();
        yieldFuture(promise.getFuture());
        thread.join();
        return promise.getFuture().get();
    }

    void yield(Args...)(void delegate(Args) dlg, Args args)
    {
        import core.thread;
        enforce(Fiber.getThis() !is null);

        auto promise = new Promise!bool();

        auto thread = new Thread( () {
			dlg(args);
            promise.setValue(true);
	        import derelict.sdl2.sdl;
	        SDL_Event event;
	        //   SDL_Zero(event); not needed since dlang does this
	        event.type = g_sdlCustomEventType;
	        SDL_PushEvent(&event);
        });

        thread.start();
        yieldFuture(promise.getFuture());
        thread.join();
    }

    U yield(U, Args...)(U function(Args) dlg, Args args) if (!is(U == void))
    {
        import core.thread;
        enforce(Fiber.getThis() !is null);

        auto promise = new Promise!U();

        auto thread = new Thread( () {
            promise.setValue(dlg(args));
            import derelict.sdl2.sdl;
	        SDL_Event event;
	        //   SDL_Zero(event); not needed since dlang does this
	        event.type = g_sdlCustomEventType;
	        SDL_PushEvent(&event);
        });

        thread.start();
        yieldFuture(promise.getFuture());
        thread.join();
        return promise.getFuture().get();
    }

    void yield(Args...)(void function(Args) dlg, Args args)
    {
        import core.thread;
        enforce(Fiber.getThis() !is null);

        auto promise = new Promise!bool();

        auto thread = new Thread( () {
			dlg(args);
            promise.setValue(true);
	        import derelict.sdl2.sdl;
	        SDL_Event event;
	        //   SDL_Zero(event); not needed since dlang does this
	        event.type = g_sdlCustomEventType;
	        SDL_PushEvent(&event);
        });

        thread.start();
        yieldFuture(promise.getFuture());
        thread.join();
    }

    auto timeout(Fn, Args...)(Duration d, Fn fn, Args args)
	{
		return guiRoot.timeout(d, fn, args);
	}

    struct MainFiberWork
    {
        void delegate() dlg;
    }

    MainFiberWork[] _mainFiberWorkList;
	CommandCall[] _commandCallList;

    @RPC
	void scheduleCommand(string commandName, string arg1)
    {
        auto cc = CommandCall(commandName);
        cc.arguments ~= CommandParameter(arg1);
        pushCommandCall(cc);
    }

	void pushCommandCall(CommandCall c)
    {
        assumeSafeAppend(_commandCallList);
        _commandCallList ~= c;
    }

    void pushMainFiberWork(void delegate() dlg)
    {
        assumeSafeAppend(_mainFiberWorkList);
        _mainFiberWorkList ~= MainFiberWork(dlg);
    }

    string ping()
    {
		import core.thread;
		enforce(Fiber.getThis() !is null);
        auto future = _asyncIO.ping("Hello there");
		yieldFuture(future);
		return future.get().reply;
    }

    bool download(string url, string fileDestPath)
    {
		import core.thread;
		enforce(Fiber.getThis() !is null);
        auto future = _asyncIO.download(url, fileDestPath);
		yieldFuture(future);
		return future.get().success;
    }

	private struct FiberFutureWait
	{
		import core.thread;
		Fiber fiber;
		IFuture future;
	}

	FiberFutureWait[] _fiberFutureWaitList;

	private void yieldFuture(IFuture f)
	{
		import core.thread;
		assumeSafeAppend(_fiberFutureWaitList);
		_fiberFutureWaitList ~= FiberFutureWait(Fiber.getThis(), f);
		Fiber.yield();
	}

	private void handleFiberFutures()
	{
		bool done = false;
		assumeSafeAppend(_fiberFutureWaitList);
		while (!done)
		{
			done = true;
			foreach (i, ff; _fiberFutureWaitList)
			{
				if (ff.future.isValid)
				{
					_fiberFutureWaitList[i] = _fiberFutureWaitList[$-1];
					_fiberFutureWaitList.length = _fiberFutureWaitList.length - 1;
					done = false;

					// Future ready... resume fiber
                    try
                    {
    					ff.fiber.call();
                    }
                    catch (Exception e)
                    {
                        log.e("Fiber future resume error: %s", e.toString());
                    }
					break;
				}
			}
		}
	}

	private void doMainFiberWork()
	{
        foreach (ff; _mainFiberWorkList)
        {
            try
            {
                ff.dlg();
            }
            catch (Exception e)
            {
                log.e("Delayed main fiber work error: %s", e.toString());
            }
        }
		_mainFiberWorkList.length = 0;
        assumeSafeAppend(_mainFiberWorkList);
	}

	private void doCommandCalls()
    {
        foreach (cc; _commandCallList)
        {
	        try
            {
                commandManager.execute(cc);
            }
            catch (Exception e)
            {
                log.e("Command '%s' error: %s", cc.name, e.toString());
            }
        }
        _commandCallList.length = 0;
        assumeSafeAppend(_commandCallList);
    }

	//static import dccore.future;
	//dccore.future.Fiber getFiber()
	//{
	//    static import core.thread;
	//    auto f =  core.thread.Fiber.getThis();
	//    return cast(dccore.future.Fiber)f;
	//}

	void analyticEvent(string category, string action, string label = null, string value = null)
	{
		if (analytics !is null)
			analytics.addEvent(category, action, label, value);
	}

	void analyticTiming(string category, string variable, Duration d)
	{
		if (analytics !is null)
			analytics.addTiming(category, variable, d);
	}

	void analyticStartTiming(string category, string variable)
	{
		if (analytics !is null)
			analytics.startTiming(category, variable);
	}

	void analyticStopTiming(string category, string variable)
	{
		if (analytics !is null)
			analytics.stopTiming(category, variable);
	}

	void analyticException(string description, bool isFatal)
	{
		if (analytics !is null)
			analytics.addException(description, isFatal);
	}

    @RPC
    string getUserDataDir()
    {
        return resourceURI(".", ResourceBaseLocation.userDataDir).uriString;
    }

    @RPC
    string getExecutableDir()
    {
        return resourceURI(".", ResourceBaseLocation.executableDir).uriString;
    }
}


// Dispatch.
class WidgetLocationUpdater : IWidgetLocationUpdater
{
    private
    {
        static struct ScheduledLocationUpdate
        {
            bool done =  false;
            Widget w;
			string relativeWidget;
            RelativeLocation location;
        }
        ScheduledLocationUpdate[] _items;
		Application app;
    }

	this(Application a)
	{
		app = a;
	}

    // Schedule a widget to have its location relative to another widget
    // set.
	void scheduleWidgetPlacement(Widget placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc)
    {
        assumeSafeAppend(_items);
        _items ~= ScheduledLocationUpdate(false, placeThisWidget, relativeToWidgetWithThisName, loc);
    }

    void performLocationUpdates()
    {
        if (_items.empty)
            return;

        bool changed = true;
        bool anyChange = false;
        while (changed)
        {
            changed = false;
            foreach (ref i; _items)
            {
                if (!i.done)
                {
					auto res = app.placeWidgetRelative(i.w, i.relativeWidget, i.location);
					final switch (res)
					{
						case Application.WidgetPlacementResult.success:
							i.done = true;
							break;
						case Application.WidgetPlacementResult.placementInsideNotPossible:
							app.addMessage("Cannot place %s inside %s", i.w.name, i.relativeWidget);
							i.done = true;
							break;
						case Application.WidgetPlacementResult.unknownRelativeWidget:
							break;
					}
                    changed = changed || i.done;
                    anyChange = anyChange || changed;
                }
            }
        }

        if (anyChange)
        {
            assumeSafeAppend(_items);
            int nextSlot = 0;
            foreach (i, loc; _items)
            {
                if (!loc.done)
                {
                    swap(_items[nextSlot], loc);
                    nextSlot++;
                }
            }
        }
    }
}
















version (none):
import behavior.behavior;
import edit.buffer;
import edit.bufferview;
import dccore.command;
import core.stdc.errno;
import dccore.log;

import std.stdio;

class Application
{
	private
	{
		BufferViewManager _bufferViewManager;
		BufferView _currentBuffer;
		int _previousBufferID;
		EditorBehavior _editorBehavior;
		CommandManager _commandManager;
	    Log _log;
    }

	@property
	{
		BufferViewManager bufferViewManager() { return _bufferViewManager; }
		void currentBuffer(BufferView v) { _previousBufferID = _currentBuffer is null ? 0 : _currentBuffer.id; _currentBuffer = v; }
        BufferView currentBuffer() { return _currentBuffer; }
        BufferView previousBuffer() { return bufferViewManager[_previousBufferID]; }
		EditorBehavior editorBehavior() { return _editorBehavior; }
		CommandManager commandManager() { return _commandManager; }
        Log log() { return _log; }
	}

	this()
	{
		_commandManager = new CommandManager();
		_bufferViewManager = new BufferViewManager();
		auto buf = _bufferViewManager.create("ctrl+? for help.\nctrl+w for console\n\n", "*Messages*");
		buf.cursorToEndOfLine();
		_bufferViewManager.create("", "*CommandInput*");

		// Let text editing behave like emacs
		import behavior.emacs;
		_editorBehavior = new EmacsBehavior(this);
	}

    void setLogFile(string path)
    {
        _log = new Log(path);
        _log.onInfo.connect(&appendConsoleMessage);
    }

    private void appendConsoleMessage(string msg, LogLevel level)
    {
		import std.conv;
		auto view = bufferViewManager["*Messages*"];
		view.insert(text(msg));
		view.insert("\n");
    }

	void addMessage(Types...)(Types msgs)
	{
		_log(msgs);
/*
        import std.string;
		import std.conv;
        static import std.stdio;
		version (linux)
            std.stdio.writeln("*Messages* " ~ format(msgs));
        auto fmtmsg = format(msgs);
        if (_logFile.getFP() !is null)
        {
            _logFile.writeln(fmtmsg);
            _logFile.flush();
        }
        */
	}
}
