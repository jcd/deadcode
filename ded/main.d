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
	auto resizerWidget = new Widget(Rectf(0, 0, 30, 30));
	resizerWidget.features ~= new WindowResizer();

	// A widget that can be mousedowned and move the window
	auto draggerWidget = new Widget(Rectf(0, 0, 20, 40));
	draggerWidget.features ~= new WindowDragger();

	// The main widget that spans the entire window
	auto mainWidget = new Widget(Rectf(0, 0, 1210, 1010));

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

	auto l = std.file.readText("math.d");
	mainWidget.features ~= new BoxRenderer();
	mainWidget.features ~= new TextRenderer(l);
	draggerWidget.features ~= new BoxRenderer();
	resizerWidget.features ~= new BoxRenderer();
			
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
	//window.run();
   	return 0; 
}


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