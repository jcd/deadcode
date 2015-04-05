module guiapplication;

import application;
import core.analytics;
import core.bufferview;
import core.copybuffer;
import core.commandparameter;
import core.command : CompletionEntry;
import core.future;
import core.container;
import core.uri;
import graphics;
import gui;
import gui.resources.texture : GTexture = Texture;
import controls.button;
import controls.command;
import controls.menu;
import controls.texteditor;
import gui.resources.generic;
import gui.layout;
import io.asyncio;

import math; // Vec2f

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.path;
import std.string;
static import std.exception;

enum appName = "DeadCode";

version (Windows)
{
import std.c.windows.windows;
extern (Windows)
{
	nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);
	nothrow export HANDLE FindFirstChangeNotificationA(LPCTSTR lpPathName, BOOL bWatchSubtree, DWORD dwNotifyFilter);
	nothrow export BOOL FindNextChangeNotification(HANDLE hChangeHandle);
	nothrow export BOOL FindCloseChangeNotificationA(HANDLE hChangeHandle);
	nothrow export BOOL SHGetSpecialFolderPathA(
											   HWND hwndOwner,
											   LPTSTR lpszPath,
											   int csidl,
											   BOOL fCreate
												   );
	//nothrow export BOOL ReadDirectoryChangesW(HANDLE hDirect1ory, LPVOID lpBuffer, DWORD nBufferLength,
	//                                  BOOL bWatchSubtree,
	//                                  DWORD dwNotifyFilter,
	//                                  LPDWORD lpBytesReturned,
	//                                  LPOVERLAPPED lpOverlapped,
	//								  LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
}

///

class DirectoryWatcher
{
	import std.datetime;

	string path;
	HANDLE[1] dwChangeHandles;

	this(string path)
	{
		this.path = buildNormalizedPath(path);
		dwChangeHandles[0] = FindFirstChangeNotificationA(
														 path.toStringz(),                         // directory to watch
														 true,                         // do not watch subtree
														 FILE_NOTIFY_CHANGE_LAST_WRITE); // watch file name changes
		import std.stdio;
		if (dwChangeHandles[0] == INVALID_HANDLE_VALUE)
		{
			writeln("\n ERROR: FindFirstChangeNotification function failed.\n", GetLastError());
		}
	}

	bool wait(Duration d)
	{
		// Watch the directory
		bool result = false;

		if (dwChangeHandles[0] == INVALID_HANDLE_VALUE)
			return result;

		// Change notification is set. Now wait on both notification
		// handles and refresh accordingly.

		// Wait for notification.
		DWORD dwWaitMs = cast(uint)d.total!"msecs"();
		DWORD dwWaitStatus = WaitForMultipleObjects(1, &dwChangeHandles[0],
												FALSE, dwWaitMs);

		switch (dwWaitStatus)
		{
			case WAIT_OBJECT_0:

				// A file was created, renamed, or deleted in the directory.
				// Refresh this directory and restart the notification.
				if ( FindNextChangeNotification(dwChangeHandles[0]) == FALSE )
				{
					writeln("\n ERROR: FindNextChangeNotification function failed.\n", GetLastError());
				}
				result = true;
				break;
			case WAIT_TIMEOUT:
				// A timeout occurred, this would happen if some value other
				// than INFINITE is used in the Wait call and no changes occur.
				// In a single-threaded environment you might not want an
				// INFINITE wait.
				break;
			default:
				writeln("\n ERROR: Unhandled dwWaitStatus.\n", GetLastError());
				break;
		}
		return result;
	}
}

} // version (Windows)

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

/** The location that is use as base for relative paths/URIs.
*/
enum ResourceBaseLocation
{
	currentDir,    /// The current working directory
	executableDir, /// The dir of this executable
	resourceDir,   /// The default resources dir
	userDataDir,   /// The user data dir which is platform specific
	sessionDir,    /// Session temporary dir. Is cleared upon start and stop of app.
}

import util.jsonx;

class GlobalStyle : Stylable
{
	@property
	{
		string name() const pure @safe { return null; }
		ubyte matchStylable(string stylableName) const pure nothrow @safe { return stylableName == "Globals" ? 10 : 0; }
		const(string[]) classes() const pure nothrow @safe { return null; }
		bool hasKeyboardFocus() const pure nothrow @safe { return false; }
		bool isMouseOver() const pure nothrow @safe { return false; }
		bool isMouseDown() const pure nothrow @safe { return false; }
        bool isVisible() const pure nothrow @safe { return true; }
		Stylable parent() pure nothrow @safe { return null; }
	}
}

interface IWidgetLocationUpdater
{
	void scheduleWidgetPlacement(Widget placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc);
	void performLocationUpdates();
}

class PromptQuery
{
	this(string q, string a, Promise!PromptQueryResult p, CompletionEntry[] delegate(string) _getCompletionsDg)
	{
		question = q;
		answer = a;
		promise = p;
		getCompletionsDg = _getCompletionsDg;
	}

	string question;
	string answer;
	Promise!PromptQueryResult promise;
	CompletionEntry[] delegate(string) getCompletionsDg;
}

class PromptQueryResult
{
	string answer;
	bool success;
}

class GUIApplication : Application
{
	GUI guiRoot;
	GlobalStyle globalStyle;
	Menu menu;

	import std.container;
	Stack!PromptQuery _promptStack;

	private string _restartExecutable;
	private IWidgetLocationUpdater _widgetLocationUpdater;

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

	Widget _mainWidget;
	version (Windows) DirectoryWatcher resourceDirWatcher;
	private string resourcesRoot;
	StyleSheet defaultStyleSheet;

	GenericResource sessionData;

	private Analytics analytics;
    private AsyncIO _asyncIO;

	T getGlobalStyle(T)(string name)
	{
		T res;
		defaultStyleSheet.getStyle(globalStyle).getProperty(name, res);
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

	private this(GUI gui)
	{
		// This also sets up tracking keys for analytics
		guiRoot = gui;
        globalStyle = new GlobalStyle();
		setupRegistryEntries();
		_promptStack = new Stack!PromptQuery();

		// analytics = new GoogleAnalytics("UA-42266538-2", analyticsKey, "Ded", "com.streamwinter.ded", appVersion);

		// analytics = new NullAnalytics;
		analyticEvent("core", "start");
		analyticStartTiming("core", "startup");
		_widgetLocationUpdater = new WidgetLocationUpdater(this);
		super();

        setLogFile(resourceURI("log.txt", ResourceBaseLocation.userDataDir).uriString);

		// editorcommands.register(this);
		editors = new Editors;
	}

	~this()
	{
	}

	core.uri.URI resourceURI(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
		if (isAbsolute(path))
		{
			auto res = new core.uri.URI(path);
			res.normalize();
			return res;
		}

		import core.stdc.string;
		string basePath;
		final switch (base)
		{
			case ResourceBaseLocation.currentDir:
				basePath = absolutePath(std.file.getcwd());
				break;
			case ResourceBaseLocation.executableDir:
				basePath = absolutePath(thisExePath().dirName());
				break;
			case ResourceBaseLocation.resourceDir:
				basePath = resourcesRoot;
				break;
			case ResourceBaseLocation.sessionDir:
				// TODO: implement
				addMessage("Implement sessionDir");
				break;
			case ResourceBaseLocation.userDataDir:
                            version (Windows)
                            {
				char[MAX_PATH] buffer;
				auto CSIDL_APPDATA = 0x001a;
				void* dummy;
				if (SHGetSpecialFolderPathA(dummy, buffer.ptr, CSIDL_APPDATA, 0) == TRUE)
					basePath = absolutePath(buildPath(buffer[0..strlen(buffer.ptr)].idup, appName));
				else
					throw new Exception("Cannot get APPDATA dir");
                            }
                            version (linux)
                            {
                                import std.process;
                                import std.path;
                                string home = environment.get("XDG_DATA_HOME", expandTilde("~/.local/share"));
                                basePath = absolutePath(buildPath(home, appName));
                            }
			    break;
		}

		auto u = new core.uri.URI(buildNormalizedPath(basePath, path));
		u.normalize();
		return u;
	}

	static GUIApplication create(GUI gui = null)
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

		auto app = new GUIApplication(gui);
		app.guiRoot.onFileDropped.connect(&app.onFileDropped);

        app._asyncIO = new AsyncIO();
		return app;
	}

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

    void loadKeyBindings(string fileName)
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

        GenericResource keyMappingsResource = getUpdated(fileName);

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
		setupResourcesRoot();

		// guiRoot.locationsManager.baseURI = "resources/";

		version (Windows) resourceDirWatcher = new DirectoryWatcher(resourcesRoot);

        // timeout(dur!"msecs"(500), &regularCheck);

		scanResources();

		defaultStyleSheet = guiRoot.styleSheetManager.load(resourceURI("default.stylesheet", ResourceBaseLocation.resourceDir));
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

		//guiRoot.timeout(dur!"msecs"(500), );

		setupMainWindow();

		static import extensions.base;
		extensions.base.init(this);

        loadKeyMappings();

		loadSession();
		analyticStopTiming("core", "startup");

		guiRoot.onActivity.connect(&handleActivity);

		guiRoot.run();
		analyticEvent("core", "stop");
		if (analytics !is null)
			analytics.stop();

		extensions.base.fini(this);
		saveSession();

		if (!_restartExecutable.empty)
		{
			import std.process;
			spawnProcess(_restartExecutable);
			import std.c.stdlib;
			import core.thread;
			Thread.sleep(dur!"seconds"(1));
		}
	}

	private void handleActivity()
	{
		// Since this is called by onActivity the futures supported currently are only those
		// being fulfilled by an activity ie. key press, mouse move etc.

	    doMainFiberWork();
		handleFiberFutures();
		handlePromptQuery();
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
		}, q.getCompletionsDg);
	}

	void scheduleRestart(string exePath)
	{
		_restartExecutable = exePath;
		guiRoot.stop();
	}

    void quit()
    {
		guiRoot.stop();
    }

	void setupResourcesRoot()
	{
        version (release)
        {
            import core.pack;
            resourcesRoot = buildPath(FilePack!"resources.pack"().unpack(), "resources");
            writeln("Unpack dir ", FilePack!"resources.pack"().unpack());
        }
        else
        {
            resourcesRoot = absolutePath("resources", thisExePath().dirName());
        }
	}

	void setupRegistryEntries()
	{
		import std.uuid;
		import core.config;

                version (Windows)
                {
                    setupRegistryEntry(r"Software\Classes\*\shell\Open with Dedit\command",
                                       r"C:\Projects\D\ded>ded-debug_d.exe");
                    analyticsKey = setupRegistryEntry(r"Software\SteamWinter\Ded",
                                                      randomUUID().toString());
                }
                version (linux)
                {
                    import std.file;

                    auto u = resourceURI("analyticsKey");

                    mkdirRecurse(u.dirName.uriString);

                    if (exists(u.uriString))
                        analyticsKey = readText(u.uriString);
                    else
                    {
                        analyticsKey = randomUUID().toString();
                        std.file.write(u.uriString, analyticsKey);
                    }
                }
	}


	void scanResources()
	{
		guiRoot.locationsManager.scan(resourceURI("*", ResourceBaseLocation.resourceDir));
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

version (Windows)
{
	private Rectf getExistingWindowRect()
	{
		auto hwnd = FindWindowA("SDL_app", "Deadcode");
		Rectf result;
		RECT r;
		if (hwnd !is null)
		{
			GetWindowRect(hwnd, &r);
			result = Rectf(r.left, r.top, r.right - r.left, r.bottom - r.top);
		}
		return result;
	}
}
version (linux)
{
    pragma(msg, "Warning: Missing getExistingWindowRect");
    private Rectf getExistingWindowRect()
    {
        return Rectf(0,0, 500, 500);
    }
}


    Widget getWidget(string name)
    {
        return guiRoot.activeWindow.getWidget(name);
    }

    T getWidget(T)(string name)
    {
        return cast(T) guiRoot.activeWindow.getWidget(name);
    }

	private void setupMainWindow()
	{
		auto existingRect = getExistingWindowRect();
		auto win = createWindow("Deadcode");
		if (!existingRect.empty)
		{
            import std.stdio;
			win.position = existingRect.pos;
			writeln(existingRect.size);
            win.size = existingRect.size;
		}

		// A main widget
		_mainWidget = new Widget(win, 100, 100, 20, 32);
		_mainWidget.layout = new StackLayout();

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
		_mainWidget.alignToWindow(Anchor.TopLeft);
		// _mainWidget.alignTo(_draggerWidget, Anchor.BottomLeft, Anchor.TopLeft);
		_mainWidget.alignToWindow(Anchor.BottomRight);
		_mainWidget.name = "main";

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

		// Let text editor handle events before normal gui
		win.onEvent = (ref Event ev) {
			// Let the shortcut handler do its magic before event is dispatched to
			// the widgets.
			if (ev.type == EventType.Focus)
				scanResources();

			auto used = editorBehavior.onEvent(ev);
			return used;
			//if (used == EventUsed.yes)

			//    return used;
			//return cc.onCommand(ev);
		};
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

	BufferView openFile(string path)
	{
		auto existingBuffer = bufferViewManager[path];
		if (existingBuffer !is null)
		{
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
			view.insert(std.conv.dtext(line));
		}
		view.cursorToStart();
		view.clearUndoStack();

        // In order to be able to center on line before a redraw we set the visible line count from the current
        // active buffer
        auto curBV = getVisibleBuffer();
        if (curBV)
            view.visibleLineCount = curBV.visibleLineCount;

		showBuffer(view);
		// debug view.enableUndoStackDumps();
		view.bufferModified.connect(&onBufferModified);
		// addMessage("Read %s", view.name);
		return view;
		//Application.activeEditor.show(view);
	}

	BufferView createBuffer()
	{
		auto view = bufferViewManager.create();
		addMessage("Create buffer %s", view.name);
		view.bufferModified.connect(&onBufferModified);
		return view;
	}

	private void onBufferModified(BufferView b, bool isModified)
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

	private auto setBufferVisible(BufferView buf)
	{
		import core.language;
		auto dinfo = manager().lookup("D");
		_mainWidget.hideChildren();
		EditorInfo* w = buf.id in editors.editors;
		if (w is null)
		{
			//a create a new widget for this buffer
			auto editorWidget = new TextEditor(buf);
            editorWidget.onGlyphMouseUp.connect(&textEditorGlyphClicked);

            editorWidget.parent = _mainWidget;
			// guiRoot.timeout(dur!"msecs"(500), () { editorWidget.toggleCursorVisibility(); return true; });
			//editorWidget.alignTo(Anchor.TopLeft, Vec2f(-1, -1), Vec2f(6,0));
			//editorWidget.alignTo(Anchor.BottomRight);
			editors.editors[buf.id] = EditorInfo(++editors.focusOrderCounter, editorWidget);
			editorWidget.name = "editor-buffer-" ~ buf.id.to!string;
			editorWidget.onKeyboardFocusCallback = (Event ev, Widget w) {
				editors.editors[buf.id].focusOrder = ++editors.focusOrderCounter;
				currentBuffer = buf;
				return EventUsed.yes;
			};
			editorWidget.renderer.textStyler = createTextStyler(buf);
			if (buf.name.endsWith(".d"))
				buf.codeModel = dinfo.createModel(buf);
			w = buf.id in editors.editors;
		}
		w.editor.visible = true;
		return w;
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

	TextEditor getCurrentTextEditor()
	{
		foreach (k,v; editors.editors)
		{
			if (v.editor.visible)
				return v.editor;
		}
		return null;
	}

	BufferView getVisibleBuffer()
	{
		auto e = getCurrentTextEditor();
		return e is null ? null : e.bufferView;
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
		w.editor.setKeyboardFocusWidget();
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
        checkDirForChanges();
        updateDelayedWidgetLocations();
        if (auto ed = getCurrentTextEditor())
            ed.toggleCursorVisibility();
        return true;
    }

    private void updateDelayedWidgetLocations()
    {
        _widgetLocationUpdater.performLocationUpdates();
    }

    private void checkDirForChanges()
	{
            version (Windows)
                {
		if (resourceDirWatcher.wait(dur!"seconds"(0)))
			scanResources();
                }
            version (linux)
                {
                    pragma(msg, "Warning: Missing checkDirForChanges on linux");
                }
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
				cb.entries ~= new CopyBuffer.Entry(data.to!dstring);
			}
		}
	}

    void loadKeyMappings()
    {
        static class Config
        {
            string keyMappings;
        }

        editorBehavior.currentKeyBindingsSet.clear();

        // Re-register command extension shortcuts as defined by @Shortcut attribute
        import extensions.base;
        registerCommandKeyBindings(this);

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

	Future!PromptQueryResult prompt(string question, string answer = "", CompletionEntry[] delegate(string) getCompletionsDg = null)
	{
		PromptQueryResult result;
		auto promise = new Promise!PromptQueryResult();
		auto q = new PromptQuery(question, answer, promise, getCompletionsDg);
		_promptStack.push(q);
		return promise.getFuture();
	}

	PromptQueryResult yieldPrompt(string question, string answer = "", CompletionEntry[] delegate(string) getCompletionsDg = null)
	{
		import core.thread;
		assert(Fiber.getThis() !is null);
		auto future = prompt(question, answer, getCompletionsDg);
		yieldFuture(future);
		return future.get();
	}

    string showSelectFolderDialogBasic(string defaultDir)
    {
         auto promise = new Promise!string();
         pushMainFiberWork( () {
             static import platform.dialog;
             string res = platform.dialog.showSelectFolderDialogBasic(defaultDir);
             promise.setValue(res);
         });
         yieldFuture(promise.getFuture());
         return promise.getFuture().get();
    }

    U yield(U, Args...)(U delegate(Args) dlg, Args args)
    {
        import core.thread;
        auto promise = new Promise!U();

        auto thread = new Thread( () {
            promise.setValue(dlg(args));
        });

        thread.start();
        yieldFuture(promise.getFuture());
        thread.join();
        return promise.getFuture().get();
    }

    U yield(U, Args...)(U function(Args) dlg, Args args)
    {
        import core.thread;
        auto promise = new Promise!U();

        auto thread = new Thread( () {
            promise.setValue(dlg(args));
        });

        thread.start();
        yieldFuture(promise.getFuture());
        thread.join();
        return promise.getFuture().get();
    }

	void timeout(Fn, Args...)(Duration d, Fn fn, Args args)
	{
		guiRoot.timeout(d, fn, args);
	}

    struct MainFiberWork
    {
        void delegate() dlg;
    }

    MainFiberWork[] _mainFiberWorkList;

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
					ff.fiber.call();
					break;
				}
			}
		}
	}

	private void doMainFiberWork()
	{
        foreach (ff; _mainFiberWorkList)
            ff.dlg();
		_mainFiberWorkList.length = 0;
        assumeSafeAppend(_mainFiberWorkList);
	}

	//static import core.future;
	//core.future.Fiber getFiber()
	//{
	//    static import core.thread;
	//    auto f =  core.thread.Fiber.getThis();
	//    return cast(core.future.Fiber)f;
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
		GUIApplication app;
    }

	this(GUIApplication a)
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
						case GUIApplication.WidgetPlacementResult.success:
							i.done = true;
							break;
						case GUIApplication.WidgetPlacementResult.placementInsideNotPossible:
							app.addMessage("Cannot place %s inside %s", i.w.name, i.relativeWidget);
							i.done = true;
							break;
						case GUIApplication.WidgetPlacementResult.unknownRelativeWidget:
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
