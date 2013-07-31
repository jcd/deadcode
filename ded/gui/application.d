module gui.application;

import gui._;
import math._; // Vec2f

class Application
{
	private
	{
		Window[WindowID] _windows;
		WindowID nextWindowID = 1u; // TODO: use pool

		// not singleton as in global variable, but just here to prevent 
		// two instances of application because opengl init doesn't
		// like that.
		static Application _singleton; 
	}
/*	
	@property
	{
		Window mainWindow() { return _windows[1u]; } // TODO: handle if 1st window is removed ie. cannot be main window
	}
*/
	this()
	{
		assert (_singleton is null);
		_singleton = this;
		std.exception.enforceEx!Exception(graphics._.init(), "Error initializing graphics");
	}
	
	~this()
	{
		graphics._.destroy();
	}
	
	void run()
	{
		// Start main loop
		// TODO: handle multiple windows
		_windows[_windows.keys()[0]].run();
	}
		
	Window createWindow(int width, int height, string name = "")
	{
		Window win = new Window(nextWindowID++, name, width, height);
		_windows[win.id] = win;
		setupMainWidget(win.getWidget(win.id << 24 + 1));
		return win;
	}

	protected void setupMainWidget(Widget widget)
	{
		widget.features ~= new Constraint(NullWidgetID, 
		                                  Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top,
		                                  Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top);
		
		widget.features ~= new Constraint(NullWidgetID, 
		                                  Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		                                  Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom);
	}
}
