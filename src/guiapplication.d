module guiapplication;

import application;
import core.analytics;
import core.bufferview;
import core.copybuffer;
import core.uri;
import controls.command;
import controls.texteditor;
import graphics._;
import gui._;
import gui.resources.generic;
import math._; // Vec2f

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.path;
import std.string;

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

class DirectoryWatcher
{
	import std.datetime;

	string path;
	HANDLE dwChangeHandles[1];

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

/** The location that is use as base for relative paths/URIs.
*/
enum ResourceBaseLocation
{
	currentDir,    /// The current working directory 
	executableDir, /// The dir of this executable
	resourceDir,  /// The default resources dir
	userDataDir,   /// The user data dir which is platform specific
	sessionDir,    /// Session temporary dir. Is cleared upon start and stop of app.
}

import jsonx;

class GUIApplication : Application
{
	GUI guiRoot;

	static struct EditorInfo
	{
		this(uint fo, TextEditor ed)
		{
			focusOrder = fo;
			editor = ed;
		}
		uint focusOrder; // LRU ordering
		
		@noSerialize
		TextEditor editor;
	}

	static class Editors
	{
		uint focusOrderCounter;
		EditorInfo[string] editors;
	}

	enum appVersion = "0.4";
	string analyticsKey;

	Editors editors;

	Widget _mainWidget;
	DirectoryWatcher resourceDirWatcher;
	string resourcesRoot;
	StyleSheet defaultStyleSheet;
	
	GenericResource sessionData;

	Analytics analytics;

	class WindowData
	{
		CommandControl commandControl;
	}

	private this()
	{
		// This also sets up tracking keys for analytics
		setupRegistryEntries();
		
		analytics = new GoogleAnalytics("UA-42266538-2", analyticsKey, "Ded", "com.streamwinter.ded", appVersion);
		// analytics = new NullAnalytics;
		analyticEvent("core", "start");
		analyticStartTiming("core", "startup");

		super();
		editors = new Editors;
	}

	~this()
	{
	}

	URI resourceURI(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
		if (isAbsolute(path))
		{
			auto res = new URI(path);
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
				char[MAX_PATH] buffer;
				auto CSIDL_COMMON_APPDATA = 35;
				void* dummy;
				if (SHGetSpecialFolderPathA(dummy, buffer.ptr, CSIDL_COMMON_APPDATA, 0) == TRUE)
					basePath = buffer[0..strlen(buffer.ptr)].idup;
				else
					throw new Exception("Cannot get APPDATA dir");
				break;
		}
		
		auto u = new URI(buildNormalizedPath(basePath, path));
		u.normalize();
		return u;
	}

	static GUIApplication create(GUI gui = null)
	{
		if (gui is null)
			gui = GUI.create();
				
		auto app = new GUIApplication;
		app.guiRoot = gui;
		app.guiRoot.onFileDropped.connect(&app.onFileDropped);
		return app;
	}

	void onFileDropped(string path)
	{
		analyticEvent("core", "fileDrop");
		addMessage("Dropped file %s ", path);
		path = path.replace(r"\", "/");
		openFile(path);
	}

	void run()
	{		
		setupResourcesRoot();
		
		// guiRoot.locationsManager.baseURI = "resources/";

		resourceDirWatcher = new DirectoryWatcher(resourcesRoot);
		guiRoot.timeout(dur!"msecs"(200), &checkDirForChanges);
		
		scanResources();
		
		defaultStyleSheet = guiRoot.styleSheetManager.load(resourceURI("default.stylesheet", ResourceBaseLocation.resourceDir));
		guiRoot.styleSheetManager.onSourceChanged.connect(&styleSheetSourceChanged);
		guiRoot.textureManager.onSourceChanged.connect(&textureSourceChanged);

		commandManager.create("app.toggleCommandArea", "Toggle visibility of the command area in the current active window", 
							  delegate(std.variant.Variant v) 
							  {	 
								  auto cc = guiRoot.activeWindow.userData.get!WindowData().commandControl;
								  auto val = v.peek!string();		
								  if (val !is null)
									  cc.setCommand(*val);
								  cc.toggleShown();
							  });
		
		commandManager.create("app.cycleBuffers", "Cycle through buffers in the current active window", 
							  (std.variant.Variant v)
							  {
								  import std.conv;
								  auto cc = guiRoot.activeWindow.userData.get!WindowData().commandControl;									

								  if (!cc.show )
									  cc.toggleShown();
								
								  int val = 1;
								  auto valPtr = v.peek!string();
								  if (valPtr !is null)
									  val = (*valPtr).to!int();

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
		
		setupMainWindow();

		static import extension;
		extension.init(this);

		openFile(buildNormalizedPath(resourcesRoot,"default.stylesheet"));

		loadSession();
		analyticStopTiming("core", "startup");
		guiRoot.run();
		analyticEvent("core", "stop");
		analytics.stop();
		saveSession();
	}

	void setupResourcesRoot()
	{
		resourcesRoot = absolutePath("resources", thisExePath().dirName());
	}

	void setupRegistryEntries()
	{
		import std.uuid;
		import core.config;

		setupRegistryEntry(r"Software\Classes\*\shell\Open with Dedit\command", 
						   r"C:\Users\jonasd\Documents\Projects\D\ded>ded-debug_d.exe");
		analyticsKey = setupRegistryEntry(r"Software\SteamWinter\Ded", 
										  randomUUID().toString());		
	}
	

	void scanResources()
	{
		guiRoot.locationsManager.scan(resourceURI("*", ResourceBaseLocation.resourceDir));
	}

	Window createWindow(string name = "mainWindow", int width = 1000, int height = 1000)
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
		auto hwnd = FindWindowA("SDL_app", "Ded");
		writeln("Already running is ", hwnd);
		Rectf result;
		RECT r;
		if (hwnd !is null)
		{
			GetWindowRect(hwnd, &r);
			result = Rectf(r.left, r.top, r.bottom - r.top, r.right - r.left);
		}
		return result;
	}
}

	private void setupMainWindow()
	{
		auto existingRect = getExistingWindowRect();
		auto win = createWindow("Ded");
		if (!existingRect.empty)
		{
			win.position = existingRect.pos;
			win.size = existingRect.size;
		}

		// A main widget
		_mainWidget = new Widget(win, 100, 100, 20, 32);

		// A widget that can be mousedowned and resize the window
		Widget _resizerWidget = new Widget(win, 0, 0, 24, 24);
		_resizerWidget.features ~= new WindowResizer();
		
		// A widget that can be mousedowned and move the window
		Widget _draggerWidget = new Widget(win, 0, 0, 20, 32);
		_draggerWidget.features ~= new WindowDragger();
		
		// A widget that can be mousedowned and move the window
		Widget _draggerRightWidget = new Widget(win, 0, 0, 20, 32);
		_draggerRightWidget.features ~= new WindowDragger();

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
		_mainWidget.alignTo(_draggerWidget, Anchor.BottomLeft, Anchor.TopLeft);
		_mainWidget.alignTo(Anchor.BottomRight);
		_mainWidget.name = "main";

		// Layout setting resizerWidget at bottom left of mainWidget
		_resizerWidget.alignToWindow(Anchor.BottomRight, _resizerWidget.rect.size);
		_resizerWidget.name = "resizer";

		// Layout setting dragger widget fill top 20px of mainWidget
		_draggerWidget.alignToWindow(Anchor.TopLeft, Vec2f(220, 24), Vec2f(0,0f));
		_draggerWidget.name = "dragger";

		_draggerRightWidget.alignTo(_draggerWidget, Anchor.TopRight, Anchor.TopLeft, Vec2f(-1, 24));
		_draggerRightWidget.alignTo(NullWidgetID, Anchor.TopRight, Anchor.TopRight);
		_draggerRightWidget.name = "draggerRight";

		
		// _mainWidget.features ~= new BoxRenderer("window-main");
		
		// _draggerWidget.features ~= new BoxRenderer("window-head");
		// _resizerWidget.features ~= new BoxRenderer("window-resizer");
		
		_draggerWidget.onMouseClickCallback = (Event e, Widget w) 
		{
			std.stdio.writeln("clicked ", w.pos.v, " ", w.size.v);
			return EventUsed.no; 
		};

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
		cc.alignToWindow(Anchor.TopCenter, Vec2f(600,-1), Vec2f(0,0));
		// cc.visible = false;
		winData.commandControl = cc;

		

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

	GenericResource load(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
		return guiRoot.genericResourceManager.load(resourceURI(path, base));
	}	

	GenericResource loadOrCreate(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
	{
		// predeclare to sure that unsuccessful loads return a valid resource anyway.
		auto res = guiRoot.genericResourceManager.declare(resourceURI(path, base));
		guiRoot.genericResourceManager.load(resourceURI(path, base));
		return res;
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
		std.stdio.File file;
		try
			file = std.stdio.File(path, "rb");
		catch (std.exception.ErrnoException e)
		{
			string msg = std.conv.text(e);
			if (e.errno == core.stdc.errno.ENOENT)
				msg = "No such file";
			
			addMessage("Error opening file : %s", msg);
			return null;
		}
		auto view = bufferViewManager.create("", path);
		view.ensureCapacity(cast(uint)file.size);
		showBuffer(view);
		//view.buffer.gbuffer.ensureGapCapacity(cast(uint)file.size);
		auto r = file.byLine!(char,	char)(std.stdio.KeepTerminator.yes, '\x0a');
		foreach (line; r)
		{
			view.insert(std.conv.dtext(line));
		}
		view.cursorToStart();
		view.clearUndoStack();
		addMessage("Read %s", view.name);
		return view;
		//Application.activeEditor.show(view);			
	}

	string[] getActiveBufferCompletions(string prefix)
	{
		// current buffer name is most likely "command" buffer and not an active editor
		return editors.editors.values
					.filter!(a => a.editor.bufferView.name.startsWith(prefix))()
					.array()
					.sort!("a.focusOrder > b.focusOrder")()
					.map!"a.editor.bufferView.name"()
					.array();
	}

	string[] getBufferCompletions(string prefix)
	{
		return std.array.array(bufferViewManager.buffers.keys.filter!(a => a.startsWith(prefix))());
	}

	private auto setBufferVisible(BufferView buf)
	{
		_mainWidget.hideChildren();
		EditorInfo* w = buf.name in editors.editors;
		if (w is null)
		{
			//a create a new widget for this buffer
			auto editorWidget = new TextEditor(_mainWidget, buf);
			guiRoot.timeout(dur!"msecs"(500), () { editorWidget.toggleCursorVisibility(); return true; });
			editorWidget.alignTo(Anchor.TopLeft, Vec2f(-1, -1), Vec2f(6,0));
			editorWidget.alignTo(Anchor.BottomRight);
			editors.editors[buf.name] = EditorInfo(++editors.focusOrderCounter, editorWidget);
			editorWidget.name = "editor-" ~ buf.name;
			editorWidget.onKeyboardFocusCallback = (Event ev, Widget w) {
				editors.editors[buf.name].focusOrder = ++editors.focusOrderCounter;
				currentBuffer = buf;
				return EventUsed.yes;
			};
			editorWidget.renderer.textStyler = getTextStylerFromName(buf);
			w = buf.name in editors.editors;
		}
		w.editor.visible = true;
		return w;
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

	TextStyler!BufferView getTextStylerFromName(BufferView buf)
	{
		if (buf.name.endsWith(".d"))
			return new DSourceStyler!BufferView(buf);
		if (buf.name.endsWith(".stylesheet"))
			return new StyleSheetStyler!BufferView(buf);
		if (buf.name.toLower().startsWith("changelog"))
			return new ChangeLogStyler!BufferView(buf);
		else 
			return new TextStyler!BufferView(buf);
	}
	
	private void styleSheetSourceChanged(StyleSheet sheet)
	{
		analyticEvent("core", "changed", "stylesheet", sheet.uri.uriString);
		sheet.load();
		guiRoot.activeWindow.onStyleSheetChanged();
		guiRoot.activeWindow.repaint();
	}

	private void textureSourceChanged(gui.resources.Texture tex)
	{
		analyticEvent("core", "changed", "texture", tex.uri.uriString);
		tex.load();
	}

	private bool checkDirForChanges()
	{
		if (resourceDirWatcher.wait(dur!"seconds"(0)))
			scanResources();
		return true;
	}
	
	static class SessionBuffer
	{
		this() {}
		int focusOrder;
		string path;
		uint cursorPoint;
		uint lineOffset;
	}
	
	static class SessionCopyBuffer
	{
		string[] entries;
	}

	static class SessionData
	{
		int focusOrderCounter;
		SessionBuffer[] buffers;
		SessionCopyBuffer copyBuffer;
	}

	void saveSession()
	{
		auto s = sessionData.get!SessionData();
		s.focusOrderCounter = editors.focusOrderCounter;
		s.buffers.length = 0;
		foreach (key, ed; editors.editors)
		{
			if (key == "*Messages*")
				continue;
			SessionBuffer data = new SessionBuffer;
			data.focusOrder = ed.focusOrder;
			data.path = key;
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
		sessionData = loadOrCreate(".ded");
		auto s = sessionData.get!SessionData();
		if (s is null)
		{
			s = new SessionData;
			sessionData.set(s);
		}

		editors.focusOrderCounter = s.focusOrderCounter;

		string showBufferName;

		foreach (l; s.buffers)
		{
			openFile(l.path);
			if (l.focusOrder == s.focusOrderCounter)
				showBufferName = l.path;
			auto ed = editors.editors[l.path];
			ed.focusOrder = l.focusOrder;
			ed.editor.bufferView.cursorPoint = l.cursorPoint;
			ed.editor.bufferView.lineOffset = l.lineOffset;
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

	void analyticEvent(string category, string action, string label = null, string value = null)
	{
		analytics.addEvent(category, action, label, value);
	}

	void analyticTiming(string category, string variable, Duration d)
	{
		analytics.addTiming(category, variable, d);
	}

	void analyticStartTiming(string category, string variable)
	{
		analytics.startTiming(category, variable);
	}

	void analyticStopTiming(string category, string variable)
	{
		analytics.stopTiming(category, variable);
	}

	void analyticException(string description, bool isFatal)
	{
		analytics.addException(description, isFatal);
	}
}
