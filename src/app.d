module app;

import guiapplication;


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
int main(string args[])
{ 
	version (unittest) return 0;

	try
	{
		auto app = GUIApplication.create();
		// Create a text buffer and add show it in the mainWidget
		//auto fileName = "testmath.d";
		//app.mainWidget.content = std.file.readText(fileName); 

		app.run();
	} 
	catch (Exception e)
	{
		std.stdio.writeln("Caught Exception: ", e);
		version (Windows)
		{
			import std.string;
			import core.sys.windows.windows;
			MessageBoxA(null, e.toString().toStringz(), "Caught Exception", MB_ICONERROR | MB_OK | MB_TASKMODAL);
		}
	}
	return 0; 
}
