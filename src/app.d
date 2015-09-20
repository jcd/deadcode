module app;

import guiapplication;
import platform.system;

mixin platformMain!myMain;

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
private int myMain(string[] args)
{
	import core.attr;

	version (unittest)
	{
		import test;
		printStats(true);
	}
	else
	{

		GUIApplication app;
		try
		{
			app = GUIApplication.create();
			// Create a text buffer and add show it in the mainWidget
			//auto fileName = "testmath.d";
			//app.mainWidget.content = std.file.readText(fileName);

			app.run();
		}
		catch (Exception e)
		{
            static import std.stdio;
            import std.string;
			import platform.dialog;

			std.stdio.writeln("Caught Exception: ", e);

			string s = e.toString();
			s ~= "\n" ~ "Help improve the editor by uploading this backtrace?";
			int res = messageBox(e.toString(), "Caught Exception",
                                 MessageBoxStyle.error | MessageBoxStyle.yesNo | MessageBoxStyle.modal);
			if (res)
			{
				app.analyticException(e.toString()[0..700], true);
			}

            return 1;
		}
	}
	import libasync.threads;
	destroyAsyncThreads();
	return 0;
}
