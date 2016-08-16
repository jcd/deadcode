module app;

import dccore.ctx;
import dccore.log;
import std.getopt;

int main(string[] args)
{
	import application;
	import dccore.attr;

	// Command line options
	string testsOutput = null;
	string logPath = null;
	bool noRedirect = false;

	auto helpInformation = getopt(args,
								  "log",		   &logPath,
								  "unittest|u",    &testsOutput,
								  "noredirect|n",  &noRedirect);
	
	if (helpInformation.helpWanted)
	{
		showHelp(helpInformation.options);
		return 0;
	}

	// Show unit test report and exit - unittest are run before entering main
	if (testsOutput.length != 0)
		return reportUnittests(testsOutput);
	
    int exitCode = 0;
	try
	{
        import platform.config;

        if (Application.wakeExisting(args))
            return 0;

		ctx.set(new Log(logPath.length == 0 ? paths.userData("log.txt") : logPath));

		Application app = Application.create();

		app.queueWork(() {
			import std.range;
	        app.openFiles(args[].dropOne);
		});

		app.run();
	}
	catch (Throwable e)
	{
        exitCode = 1;
		lastChanceLogging(e);
	}

	import libasync.threads;
	destroyAsyncThreads(); // This shouldn't be necessary as libasync static ~this() does it. But it has a bug.
	return exitCode;
}

private void showHelp(Option[] opts)
{
	string headerText = "Deadcode text editor - version x.y.z (C) Jonas Drewsen - Boost 1.0 License\n"
		"Usage: deadcode [--unittest <output path>] [--nodirect] [paths...]";

	version (linux)
		defaultGetoptPrinter(headerText, opts);
	else
	{
		import platform.dialog;
		import std.array;
		auto app = appender!string;
		defaultGetoptFormatter(app, headerText, opts);
		messageBox("Help on usage", app.data, MessageBoxStyle.modal);	
	}
}

private int reportUnittests(string testsOutput)
{
	import std.stdio;
	File f =  testsOutput == "-" ? stdout : File(testsOutput, "w");
	import test;
	int result = printStats(f, true) ? 0 : 1;
	f.flush();
	return result;
}

// Something terrible has happened if this is called 
private void lastChanceLogging(Throwable e)
{
	import std.string;
	import platform.dialog;

	version (linux)
	{
		static import std.stdio;
		std.stdio.writeln("Caught Exception: ", e);
	}

	string s = e.toString();
	s ~= "\n" ~ "Help improve the editor by uploading this backtrace?";

	// Last attempt to log error
	try { log.e(s); } catch (Throwable) { /* pass */ }

	int res = messageBox("Caught Exception", e.toString(),
						 MessageBoxStyle.error | MessageBoxStyle.yesNo | MessageBoxStyle.modal);
	if (res)
	{
		import dccore.analytics;
		auto a = ctx.query!Analytics();
		if (a !is null)
			a.addException(e.toString()[0..700], true);
	}
}
