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


import std.c.windows.windows;
extern (Windows): nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);


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
		guiRoot.locationsManager.load("resources", new URI("scan:resources/*"));
		guiRoot.styleSetManager.load("default", new URI("resources/stylesets/default.styleset"));
		
		commandManager.create("app.toggleCommandArea", "Toggle visibility of the command area in the current active window", 
							  delegate(std.variant.Variant v) 
							  {	 
								  auto cc = guiRoot.activeWindow.userData.get!WindowData().commandControl;
								  auto val = v.peek!string();		
								  if (val !is null)
									  cc.setCommand(*val);
								  cc.toggleShown();
							  });

		guiRoot.init();
		
		setupMainWindow();

		static import extension;
		extension.init(this);

		guiRoot.run();
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

		// Let text editor handle events before normal gui
		win.onEvent = (ref Event ev) {
			// Let the shortcut handler do its magic before event is dispatched to
			// the widgets.
			return editorBehavior.onEvent(ev);
		};
		
		// A main widget
		_mainWidget = new Widget(win, 100, 100, 20, 32);

		// A widget that can be mousedowned and resize the window
		Widget _resizerWidget = new Widget(win, 0, 0, 30, 30);
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
		
		_draggerWidget.features ~= new BoxRenderer("window-head");
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
		winData.commandControl = cc;
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
		string currentBufferName = currentBuffer is null ? null : currentBuffer.name;
		return editors.values
					.filter!(a => a.editor.bufferView.name.startsWith(prefix) && a.editor.bufferView.name != currentBufferName)()
					.array()
					.sort!("a.focusOrder > b.focusOrder")()
					.map!"a.editor.bufferView.name"()
					.array();
	}

	string[] getBufferCompletions(string prefix)
	{
		return std.array.array(bufferViewManager.buffers.keys.filter!(a => a.startsWith(prefix))());
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
			auto styler = getTextStylerFromName(buf.name);
			if (styler !is null)
				editorWidget.renderer.styledText.textStyler = styler;
			w = buf.name in editors;
		}
		w.editor.visible = true;
		w.editor.setKeyboardFocusWidget();
		currentBuffer = buf;
	}

	TextStyler!BufferView getTextStylerFromName(string name)
	{
		if (name.endsWith(".d"))
			return new DSourceStyler!BufferView;
		else 
			return DefaultStyler!BufferView.the;
	}
}
