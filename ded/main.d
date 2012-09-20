module main;

import std.stdio;
import editorcommands;

import behavior.emacs;
import graphics;
import gui;
import math;
  
int main(){ 
   	import derelict.sdl2.sdl;   
	
	auto initOK = graphics.init();
   //	writeln("Init graphics: ", initOK);
	if (!initOK) return 1;
	scope (exit) graphics.destroy();
	
	EditorBehavior.current = new EmacsBehavior();
			
	Window window = Window("Ded", 1280, 1024); 
	
	auto mat = Material.builtIn;
//	auto triangle1 = createWindowQuad(Rectf(100, 100, 700, 500), mat);
	//auto triangle2 = createWindowQuad(Rectf(710, 510, 750, 540), mat);
//	auto widget1 = new Widget(Rectf(10, 10, 70, 50));
	auto widget2 = new Widget(Rectf(0, 0, 1210, 1010));
	auto resizerWidget = new Widget(Rectf(0, 0, 30, 30));
	auto draggerWidget = new Widget(Rectf(0, 0, 20, 40));

	//widget2.features ~= new WindowDragger(Rectf(0,0, 200, 30));
	resizerWidget.features ~= new WindowResizer();
	draggerWidget.features ~= new WindowDragger();
	
	widget2.features ~= new Constraint(NullWidgetID, 
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom, 
		Vec2f(-1,-1),
		Vec2f(0,0));
	
	widget2.features ~= new Constraint(draggerWidget.id, 
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Bottom,
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top, 
		Vec2f(-1,-1),
		Vec2f(0,0));

	resizerWidget.features ~= new Constraint(widget2.id, 
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom, 
		resizerWidget.rect.size);
	
	/*
	draggerWidget.features ~= new Constraint(widget2.id, 
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top,
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top, 
		Vec2f(-1f, draggerWidget.rect.size.y));
	 */
	draggerWidget.features ~= new Constraint(NullWidgetID, 
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top, 
		Vec2f(-1f, draggerWidget.rect.size.y));

	import font;
	//auto f = new Font("arial.ttf", 16);

	//auto m = new Material();
	//m.texture = f.fontMap;
	//m.shader = ShaderProgram.builtIn;
	//widget2.activeStyle.model = createWindowQuad(widget2.rect, m);
	
	import editor;
	import text;
	import std.file;
	import std.conv;
	auto l = std.file.readText("math.d");
	dstring dl = to!dstring(l);
	//dl = "Hello world I am fine right now";
	auto buffer = new TextGapBuffer(dl, 20);
	
	/*
	void printBuffer()
	{
	for (size_t i = 0; i < buffer.length; i++)
	{
		//std.stdio.write(buffer[i]);
	}
	}
	printBuffer();
	buffer.remove(buffer.length-1);
	printBuffer();
	buffer.insert('X');	
	printBuffer();
	
	//printBuffer();
	buffer.insert('A', 0);
	//printBuffer();
	buffer.insert('B', 6);
	//printBuffer();
	buffer.insert('C', 16);
	buffer.insert('D', 16);
	//printBuffer();
	 */
/*
		buffer.remove(6);
	printBuffer();
	buffer.remove(0);
	printBuffer();
	buffer.remove(14);
	printBuffer();
	*/
	auto gf = new Font("arial.ttf", 16);

	auto view = new SourceCodeView(gf);
	widget2.features ~= new Editor(buffer, view);
		
	//widget2.features ~= new Text("Hello world");
	
/*
	for (int i = 0; i < 5; i++)
	{
		auto wi = new Widget(Rectf(0,0,0,0), widget2.id);
		wi.features ~= new Dragger(Rectf(0,0, 70, 70));
	}
	*/
	
	//widget1.features ~= new Constraint(widget2.id, 
//		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top,
		//Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Top);

/*
		widget1.features ~= new Constraint(widget1.id, 
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Top,
		Vec2f(-80,-80));

 	widget1.features ~= new Constraint(widget2.id, 
		Constraint.HorizontalAnchor.Left, Constraint.VerticalAnchor.Middle,
		Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Middle);
*/
	window.onEvent = (Event ev) {
					//writeln(e.motion.state);
		gui.update(ev);
//		triangle1.draw();
		//triangle2.draw();
	}; 
	window.onUpdate = () {
		gui.update();
		gui.draw();
	};
	
	window.run();
	
   	return 0; 
}

class ListWidget : Widget
{
	private Layout layout;
	private Widgets items;
	
	this()
	{
		widget = new Widget();
		layout = Layout(Layout.Vertical);
		w.features ~= layout;	
	}
		
	void add(Widget item)
	{
		items ~= item;
	}
	
	void add(string item)
	{
		items ~= new TextWidget(item);
	}
		
	void clear()
	{
		items = null;
	}
	
	
}

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
