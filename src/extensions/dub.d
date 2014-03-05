module extensions.dub;

import core.time;	

import extension;
import math._;
import gui.widgetfeature.constraintlayout;
import gui.window;

import std.concurrency;
import std.string;
import std.process;
import std.range;
import std.regex;
import std.stdio;

import std.c.windows.windows;

// pragma (lib, "Ws2_32.lib");
// pragma (lib, "User32.lib");

//@CommandDesc("Build using dub") 
//@CommandName("dub.build") 
//@CommandShortcut("<f7>")
class DubBuildCommand : BasicCommand!DubBuildCommand
{
	override @property string description() const { return "Build using dub"; }
	override @property string name() const { return "dub.build"; }
	override @property string shortcut() const { return "<f7>"; }

	private Tid tid;
	private string newExecPath;

	override void execute(Variant v)
	{
		showBuildWidget();		
		newExecPath = null;
		clearLog();	
		tid = spawn(&build, thisTid);
		app.guiRoot.timeout(dur!"msecs"(200), &buildUpdate);
	}

	void showBuildWidget()
	{
		auto w = getBasicWidget("errorlist");
		
		if (w is null)
			return;
		
		w.visible = true;
	}

	void log(string msg)
	{
		// Use messages instead of calls
		import extensions.errorlist;
		auto w = cast(ErrorListWidget)(getBasicWidget("errorlist"));
		if (w is null)
			return;

		auto re = regex("Copying target from (.+?) to .+");
		auto res = matchFirst(msg, re);
		if (!res.empty)
		{
			newExecPath = res[1].idup;
		}		
		w.append(msg);
		writeln(msg);
	}

	static void sendLog(Tid pTid, string msg)
	{
		send(pTid, msg);
	}

	void clearLog()
	{
		// Use messages instead of calls
		import extensions.errorlist;
		auto w = cast(ErrorListWidget)(getBasicWidget("errorlist"));
		if (w is null)
			return;
		w.clear();
	}

	static void build(Tid pTid)
	{
		// TODO: Get build configuration from project settings
		string configuration = "debug";
		string cmd = "dub build -v --config=" ~ configuration;

		bool result = true;
		auto pipes = pipeShell(cmd, Redirect.stdout | Redirect.stderr);
		
		foreach (line; pipes.stderr.byLine)
		{
			sendLog(pTid, line.idup);
		}

		foreach (line; pipes.stdout.byLine)
		{

			sendLog(pTid, line.idup);
		}

		int res = wait(pipes.pid);
		if (res != 0)
		{
			sendLog(pTid, format("status %s:", res));
		}
	}

	bool buildUpdate()
	{		
		if (tid == Tid.init)
			return false;
		
		import std.datetime;
		while (receiveTimeout(dur!"seconds"(0), 
					   (string s) { log(s); return true; },
					   (int status) { tid = Tid.init; return true; })) {}
		
		if (!newExecPath.empty)
		{
			scope (exit) newExecPath = null;
			respawn(newExecPath);
			return false;
		}

		return true; // reschedule update callbacks
	}

	private void respawn(string newExecPath)
	{
		//auto hwnd = FindWindowA("SDL_app", null);
		//writeln("existing is ", hwnd);
		
		//return;
		import std.file;
		import std.path;
		auto p = buildNormalizedPath(thisExePath());
		auto ext = std.path.extension(p);
		auto np = stripExtension(p);

		rename(p, setExtension(np ~ "-old", ext));
		rename(newExecPath, p);
		spawnProcess(p);
		import std.c.stdlib;
		import core.thread;
		Thread.sleep(dur!"seconds"(1));
		exit(0);
	}
}

extern (Windows): nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);
