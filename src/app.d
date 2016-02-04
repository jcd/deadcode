module app;

import application;
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
	import dccore.attr;

    int result = 0;

	version (unittest)
	{
		import test;
        import std.stdio;

        File f = args.length > 1 ? File(args[1], "w") : stdout;
        result = printStats(f, true) ? 0 : 1;
        f.flush();
	}
	else
	{
		Application app;
        import dccore.log;

		try
		{
            import platform.config;
            auto l = new Log(resourceURI("log.txt", ResourceBaseLocation.userDataDir).uriString);
            setGlobalLog(l);

            if (Application.wakeExisting(args))
                return 0;

			app = Application.create();

            // Create a text buffer and add show it in the mainWidget
			//auto fileName = "testmath.d";
			//app.mainWidget.content = std.file.readText(fileName);
			app.pushMainFiberWork(() {
               if (args.length > 1)
               	app.openFile(args[1]);
            });

			app.run();
		}
		catch (Exception e)
		{
            static import std.stdio;
            import std.string;
			import platform.dialog;

			version (linux)
                std.stdio.writeln("Caught Exception: ", e);

			string s = e.toString();
			s ~= "\n" ~ "Help improve the editor by uploading this backtrace?";

            try
            {
                log.e(s);
            }
            catch (Throwable)
            {
                // pass
            }

            int res = messageBox("Caught Exception", e.toString(),
                                 MessageBoxStyle.error | MessageBoxStyle.yesNo | MessageBoxStyle.modal);
			if (res)
			{
				app.analyticException(e.toString()[0..700], true);
			}

            result = 1;
		}
	}
	import libasync.threads;
	destroyAsyncThreads();
	return result;
}
