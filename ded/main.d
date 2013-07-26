module main;

import application;
import controls._;
import gui.command;
import gui.widgetfeature;

/** TODO:
 * 
 * zOrder show be derived by children widgets
 * 
 * Animating properties does not propagate changes to constraints
 * 
 * Shortcut chain ie. app, window, widget in that order
 * Let component register shortcuts in one of the three categories
 * and for the last category some constraints on the widget types
 * it will act on. (need some kind of tagging of widgets?)
 */
int main()
{ 
	auto app = new Application();

	// Create a text buffer and add show it in the mainWidget
	//auto fileName = "testmath.d";
	//app.mainWidget.content = std.file.readText(fileName);

	CommandControl cc = new CommandControl(200f);
	CommandManager.singleton.create("app.toggleCommandArea", "Toggle visibility of the command area in the current active window", &cc.toggleShown); 
	app.run();

	return 0; 
}




/*
class CommandFields
{
	WFFidget widget;

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