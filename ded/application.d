module application;

import behavior.behavior;
import buffer;
import bufferview;
import gui._;
import math._; // Vec2f

class Application
{
	private
	{
		Window _window;
		Widget _mainWidget, _draggerWidget, _resizerWidget;
		BufferViewManager _bufferViewManager;
		BufferView _currentBuffer;

		static Application _singleton;
	}
	
	@property
	{
		Window window() { return _window; }
		Widget mainWidget() { return _mainWidget; }
		Widget dragWidget() { return _draggerWidget; }
		Widget resizeWidget() { return _resizerWidget; }
		static BufferViewManager bufferViewManager() { return get()._bufferViewManager; }
		static BufferView currentBuffer() { return get()._currentBuffer; }
		static Application get() { return _singleton; }
	}

	static void AddMessage(Types...)(Types msgs)
	{
		import std.string;
		import std.conv;
		auto view = bufferViewManager["*Messages*"];
		view.insert(dtext(format(msgs)));
		view.insert("\n"d);
	}

	this()
	{
		assert (_singleton is null);
		_singleton = this;
		std.exception.enforceEx!Exception(graphics._.init(), "Error initializing graphics");
		
		setupMainWindow();

		_bufferViewManager = new BufferViewManager();
		_currentBuffer = _bufferViewManager.create("ctrl+w for console\n", "*Messages*");
		_currentBuffer.cursorToEnd();
		mainWidget.content = _currentBuffer;

		// Let text editing behave like emacs
		import behavior.emacs;
		EditorBehavior.current = new EmacsBehavior();
	}
	
	~this()
	{
		graphics._.destroy();
	}

	void run()
	{
		// Let text editor handle events before normal gui
		window.onEvent = (Event ev) {
			
			bool used = window.send(ev);
			
			// If the widgets themselves did not handle the event 
			// and it is a keyboard event we let the shortcut/input handler have a chance
			if (used)
				return;

			switch (ev.type)
			{
				case EventType.KeyDown:
				case EventType.KeyUp:
				case EventType.Text:
				case EventType.MouseScroll:
					EditorBehavior.current.onEvent(ev, currentBuffer);
					break;
				default:
					break;
			}
		};
		
		// Start main loop
		window.run();
	}
	
	void showCommandBuffer(string commandStr = "")
	{
		//BufferView b = _bufferViewManager.getOrCreate("CommandInput");
	}


	private void setupMainWindow()
	{
		// import derelict.sdl2.sdl;   
		import graphics._;
		_window = new Window("Ded", 1280, 1024); 
		
		// A widget that can be mousedowned and resize the window
		_resizerWidget = _window.createWidget(0, 0, 30, 30);
		_resizerWidget.features ~= new WindowResizer();
		
		// A widget that can be mousedowned and move the window
		_draggerWidget = _window.createWidget(0, 0, 20, 32);
		_draggerWidget.features ~= new WindowDragger();
		
		// The main widget that spans the entire window
		_mainWidget = _window.createWidget(0, 0, 1210, 1010);
		
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
		_mainWidget.features ~= new Constraint(_draggerWidget.id, 
		                                       Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Bottom,
		                                       Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top, 
		                                       Vec2f(-1,-1),
		                                       Vec2f(0,0));
		
		_mainWidget.features ~= new Constraint(_resizerWidget.id, 
		                                       Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top,
		                                       Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom, 
		                                       Vec2f(-1,-1),
		                                       Vec2f(0,0));
		
		
		// Layout setting resizerWidget at bottom left of mainWidget
		_resizerWidget.features ~= new Constraint(NullWidgetID,
		                                          Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		                                          Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom, 
		                                          _resizerWidget.rect.size);
		
		// Layout setting dragger widget fill top 20px of mainWidget
		_draggerWidget.features ~= new Constraint(NullWidgetID, 
		                                          Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top,
		                                          Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top, 
		                                          Vec2f(-1f, _draggerWidget.rect.size.y), Vec2f(0,-8f));
		
		
		_mainWidget.features ~= new BoxRenderer(gui.style.StyleSet.base[4]);
		_draggerWidget.features ~= new BoxRenderer();
		_resizerWidget.features ~= new BoxRenderer();

		_draggerWidget.onMouseClick = (Event e, Widget w) 
		{
			std.stdio.writeln("clicked");
			return false; 
		};
	}
}
