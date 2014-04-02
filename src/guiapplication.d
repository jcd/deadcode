module guiapplication;

import application;
import core.bufferview;
import core.uri;
import controls.command;
import controls.texteditor;
import graphics._;
import gui._;
import math._; // Vec2f

import std.algorithm;
import std.array;
import std.datetime;
import std.string;


import std.c.windows.windows;
extern (Windows) 
{
	nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);
	nothrow export HANDLE FindFirstChangeNotificationA(LPCTSTR lpPathName, BOOL bWatchSubtree, DWORD dwNotifyFilter);
	nothrow export BOOL FindNextChangeNotification(HANDLE hChangeHandle);
	nothrow export BOOL FindCloseChangeNotificationA(HANDLE hChangeHandle);
	//nothrow export BOOL ReadDirectoryChangesW(HANDLE hDirect1ory, LPVOID lpBuffer, DWORD nBufferLength,
	//                                  BOOL bWatchSubtree,
	//                                  DWORD dwNotifyFilter,
	//                                  LPDWORD lpBytesReturned,
	//                                  LPOVERLAPPED lpOverlapped,
	//								  LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
}

class DirectoryWatcher
{
	import std.path;
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


class GUIApplication : Application
{
	GUI guiRoot;

	struct EditorInfo
	{
		static uint focusOrderCounter = 0;
		uint focusOrder; // LRU ordering
		TextEditor editor;
	}
	EditorInfo[string] editors;
	Widget _mainWidget;
	DirectoryWatcher resourceDirWatcher;

	class WindowData
	{
		CommandControl commandControl;
	}

	private this()
	{
		super();
	}

	static GUIApplication create(GUI gui = null)
	{
		if (gui is null)
			gui = GUI.create();
				
		auto app = new GUIApplication;
		app.guiRoot = gui;
		return app;
	}

	void run()
	{		
		// guiRoot.locationsManager.baseURI = "resources/";
		resourceDirWatcher = new DirectoryWatcher("resources");
		guiRoot.timeout(dur!"msecs"(200), &checkDirForChanges);
		
		scanResources();
		
		guiRoot.styleSheetManager.load("default", new URI("resources/default.stylesheet"));
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

		openFile("resources/default.stylesheet");

		guiRoot.run();
	}

	void scanResources()
	{
		guiRoot.locationsManager.scan(new URI("resources/*"));
	}

	Window createWindow(string name = "mainWindow", int width = 1000, int height = 1000)
	{
		return guiRoot.createWindow(name, width, height);
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
		_draggerWidget.alignToWindow(Anchor.TopRight, Vec2f(-1f, _draggerWidget.rect.size.y), Vec2f(0,-8f));
		_draggerWidget.name = "dragger";
		
		// _mainWidget.features ~= new BoxRenderer("window-main");
		
		// _draggerWidget.features ~= new BoxRenderer("window-head");
		_resizerWidget.features ~= new BoxRenderer("window-resizer");
		
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
		CommandControl cc = new CommandControl(win, 200f, bufferView, this);
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
		//view.buffer.gbuffer.ensureGapCapacity(cast(uint)file.size);
		auto r = file.byLine!(char,	char)(std.stdio.KeepTerminator.yes, '\x0a');
		foreach (line; r)
		{
			view.insert(std.conv.dtext(line));
		}
		view.cursorToStart();
		view.clearUndoStack();
		addMessage("Read %s", view.name);
		showBuffer(view);
		return view;
		//Application.activeEditor.show(view);			
	}

	string[] getActiveBufferCompletions(string prefix)
	{
		// current buffer name is most likely "command" buffer and not an active editor
		return editors.values
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
		EditorInfo* w = buf.name in editors;
		if (w is null)
		{
			// create a new widget for this buffer
			auto editorWidget = new TextEditor(_mainWidget, buf);
			editorWidget.alignTo(Anchor.TopLeft, Vec2f(-1, -1), Vec2f(6,0));
			editorWidget.alignTo(Anchor.BottomRight);
			editors[buf.name] = EditorInfo(++EditorInfo.focusOrderCounter, editorWidget);
			editorWidget.name = "editor-" ~ buf.name;
			editorWidget.onKeyboardFocusCallback = (Event ev, Widget w) {
				editors[buf.name].focusOrder = ++EditorInfo.focusOrderCounter;
				currentBuffer = buf;
				return EventUsed.yes;
			};
			editorWidget.renderer.textStyler = getTextStylerFromName(buf);
			w = buf.name in editors;
		}
		w.editor.visible = true;
		return w;
	}
	
	BufferView getVisibleBuffer()
	{
		foreach (k,v; editors)
		{
			if (v.editor.visible)
				return v.editor.bufferView;
		}
		return null;
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
		sheet.load();
	}

	private void textureSourceChanged(gui.resources.Texture tex)
	{
		tex.load();
	}

	private bool checkDirForChanges()
	{
		if (resourceDirWatcher.wait(dur!"seconds"(0)))
			scanResources();
		return true;
	}
}
