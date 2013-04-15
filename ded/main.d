module main;

import std.stdio;// writeln debugging
import graphics; // window and graphics
import gui;      // main loops
import widget;   // widget definition
import widgetfeature; 
import math; // Rectf
import bufferview;

/** TODO:
 * 
 * Shortcut chain ie. app, window, widget in that order
 * Let component register shortcuts in one of the three categories
 * and for the last category some constraints on the widget types
 * it will act on. (need some kind of tagging of widgets?)
 */
int main()
{ 
	// import derelict.sdl2.sdl;   
	
	if (!graphics.init())
	{
		writeln("Error initializing graphics");
		return 1;
	}
	scope (exit) graphics.destroy();
	
	Window window = Window("Ded", 1280, 1024); 
		
	// A widget that can be mousedowned and resize the window
	auto resizerWidget = new Widget(0, 0, 30, 30);
	resizerWidget.features ~= new WindowResizer();

	// A widget that can be mousedowned and move the window
	auto draggerWidget = new Widget(0, 0, 20, 40);
	draggerWidget.features ~= new WindowDragger();

	// The main widget that spans the entire window
	auto mainWidget = new Widget(0, 0, 1210, 1010);
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
	mainWidget.features ~= new Constraint(draggerWidget.id, 
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Bottom,
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top, 
		Vec2f(-1,-1),
		Vec2f(0,0));

	mainWidget.features ~= new Constraint(resizerWidget.id, 
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom, 
		Vec2f(-1,-1),
		Vec2f(0,0));
	
	
	// Layout setting resizerWidget at bottom left of mainWidget
	resizerWidget.features ~= new Constraint(NullWidgetID,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom, 
		resizerWidget.rect.size);
		
	// Layout setting dragger widget fill top 20px of mainWidget
	draggerWidget.features ~= new Constraint(NullWidgetID, 
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top, 
		Vec2f(-1f, draggerWidget.rect.size.y));

	// Create a text buffer and add show it in the mainWidget
	import std.file; // readText
	import std.conv; // to!

	auto fileName = "testmath.d";

	auto l = std.file.readText(fileName);
	mainWidget.features ~= new BoxRenderer();
	mainWidget.features ~= new TextRenderer(l, fileName);
	draggerWidget.features ~= new BoxRenderer();
	resizerWidget.features ~= new BoxRenderer();
	
	draggerWidget.events[Event.Type.MouseClick] = (Event e, ref Widget w) 
	{ 
		std.stdio.writeln("clicked");
		return false; 
	};

	// Let text editing behave like emacs
	import behavior.emacs;
	EditorBehavior.current = new EmacsBehavior();
	
	// Let GUI handle events
	window.onEvent = (Event ev) {
		bool used = gui.send(ev);
		// If the widgets themselves did not handle the event 
		// and it is a keyboard event we let the shortcut/input handler have a chance
		if (used)
			return;
		switch (ev.type)
		{
		case Event.Type.KeyDown:
		case Event.Type.KeyUp:
		case Event.Type.Text:
		case Event.Type.MouseScroll:
			EditorBehavior.current.onEvent(ev, BufferView.current);
			break;
		default:
			break;
		}
	};

	// Update GUI when needed
	window.onUpdate = () {
		gui.update();
		gui.draw();
	};
	
	// Start main loop
	window.run();
   	return 0; 
}

alias TextGapBuffer Buffer;

class Application
{
	Buffer[string] buffers;

	void createBuffer(string name)
	{
		enforceEx!Exception(! (name in buffers), text("A buffer with the name ", name, "already exists"));
		auto b = new Buffer(""d, 6);
		buffers[name] = b;
	}

	/**
	 * Params:
	 * path = path to file
	 * name = name of buffer. Leave empty to use the path as the name
	 */
	void createBufferFromPath(string path, string name = "")
	{
		auto b = createBuffer(name.empty ? path : name);
		auto f = std.stdio.File(path, "rb");
		ulong size = f.size();
		b.ensureGapCapacity(size);
		auto range = f.byLine!(dchar,char)(KeepTerminator.yes, '\n');
		foreach (line; range)
		{
			b.insert(line);
		}
	}

	void destroyBuffer(string name)
	{
		auto b = name in buffers;
		if (b)
			buffer.remove(name); // TODO: make sure dependent actors get notified? or rely on GC?
	}

	destroyBuffer(Buffer b)
	{
		foreach (item; buffer)
		{
			if (item == b)
			{
				destroyBuffer(b.name);
				return;
			}
		}
	}

	void showCommandBuffer(string commandStr = "")
	{

	}
}


/*
class CommandField
{
	Widget widget;

	this()
	{
		widget.events[Event.Type.KeyUp] = onKeyUp;
	}

	void onKeyUp(Widget w, Event ev)
	{
		if (ev.keyCode == stringToKeyCode("return"))
		{
			// Accept input

		}
	}
}
*/

/*
void showOpenFileWidget()
{
	static openFileWindow = ll;
	
	// Model
	string[] fileNames;
	
	// View
	auto w = new Widget();
	auto l = Layout(Layout.Vertical);
	w.features ~= l;	
	
	// Controller
	
}
*/