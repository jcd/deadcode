module extensions.dub;

import core.time;	

import extension;
import math._;
import gui.widgetfeature.constraintlayout;
import gui.window;

import std.algorithm;
import std.concurrency;
import std.file;
import std.json;
import std.string;
import std.path;
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

extern (Windows) nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);


/**
	Dub project navigation
*/
class Project : BasicExtension!Project
{
	override @property string name() { return "dub.project"; }

	static class Configuration
	{
		bool isAutoConfiguration;
		bool isAutoSourcePaths;
		string name;
		string[] sourceFiles;
		string[] sourcePaths;
		string mainSourceFile;
	}

	string projectName;
	Configuration[] configurations;
	string activeConfiguration;
	
	string[] knownFiles;

	override void init()
	{
		if (readDubFile() && !configurations.empty)
		{
			knownFiles = getConfigurationFiles(configurations.front.name);
		}
	}

	private string[] getConfigurationFiles(string configurationName)
	{
		auto r = find!(a => a.name == configurationName)(configurations);
		if (r.empty)
		{
			app.addMessage("Cannot get files for unknown configuration " ~ configurationName);
			return null;
		}

		string[] result;
		Configuration conf = r.front;
		foreach (p; conf.sourceFiles)
			result ~= scanForFiles(p);
		
		foreach (p; conf.sourcePaths)
			result ~= scanForFiles(p);

		result ~= scanForFiles(conf.mainSourceFile);
		return result;
	}

	private bool readDubFile()
	{
		configurations = null;
		activeConfiguration = null;

		string dubConf;
		if (exists("package.json"))
			dubConf = readText("package.json");
		else if (exists("dub.json"))
			dubConf = readText("package.json");
		else
		{
			app.addMessage("No dub configuration file found");
			return false;
		}

		JSONValue[string] dubObject = parseJSON(dubConf).object;
		JSONValue* nameTxt = "name" in dubObject;
		if (nameTxt is null)
		{
			app.addMessage("No package name specified in dub json file");
			return false;
		}

		projectName = nameTxt.str;

		JSONValue* configs = "configurations" in dubObject;
		if (configs is null)
		{
			auto autoConf = createAutoConfiguration();
			if (autoConf !is null)
				configurations ~= autoConf;
		}
		else
		{
			
			foreach (ref JSONValue conf; configs.array)
			{
				auto newConf = createConfiguration(conf);
				if (newConf !is null)
					configurations ~= newConf;
			}
		}
		return true;
	}

	private Configuration createAutoConfiguration()
	{
		Configuration result = new Configuration;
		result.isAutoConfiguration = true;
		result.isAutoSourcePaths = true;
		result.name = "library";
		
		foreach (p; [ "source", "src" ])
		{
			if (exists(p) && isDir(p))
			{
				result.sourcePaths = [p];
				break;
			}
		}

		if (result.sourcePaths.empty)
		{
			app.addMessage("Warning: No configuration specified in dub json file and no src or source folders present to use as default");
		}

		foreach (n; ["app.d", name ~ ".d"])
		{
			auto mainSourceFile = buildPath(result.sourcePaths.front, n);
			if (isFile(mainSourceFile))
			{
				result.name = "application";
				result.mainSourceFile = mainSourceFile;
				break;
			}
		}

		return result;
	}
	
	private Configuration createConfiguration(ref JSONValue conf)
	{
		auto c = new Configuration;
		c.isAutoConfiguration = false;
		c.name = conf.object["name"].str;
		
		JSONValue* srcFiles = "sourceFiles" in conf.object;
		
		if (srcFiles !is null)
		{
			foreach (ref p; srcFiles.array)
				c.sourceFiles ~= p.str;
		}

		JSONValue* srcPaths = "sourcePaths" in conf.object;

		if (srcPaths is null)
		{
			c.isAutoSourcePaths = true;
			foreach (p; [ "source", "src" ])
			{
				if (exists(p) && isDir(p))
				{
					c.sourcePaths = [p];
					break;
				}
			}
			
			if (c.sourcePaths.empty)
				app.addMessage("Warning: No sourcePaths specified in dub config file and not default folders source or src present for configuration " ~ c.name);
		}
		else
		{
			c.isAutoSourcePaths = false;
			foreach (ref p; srcPaths.array)
				c.sourcePaths ~= p.str;			

			if (c.sourcePaths.empty)
				app.addMessage("Warning: No paths in sourcePaths field in dub config file for configuration " ~ c.name);
		}

		return c;
	}

	private string[] scanForFiles(string path)
	{
		if (!exists(path))
			return null;

		if (isFile(path))
		{
			return [path];
		}
		else if (isDir(path))
		{
			string[] result;
			auto entries = dirEntries(path, "*.{d,di}", SpanMode.depth);
			foreach (e; entries)
			{
				if (e.isFile())
					result ~= e.name;
			}
			return result;
		}
		return null;
	}
}

class QuickOpenCommand : BasicCommand!QuickOpenCommand
{
	override @property string description() const { return "Quick open file in dub project"; }
	override @property string name() const { return "dub.quickopen"; }
	override @property string shortcut() const { return "<ctrl> + ,"; }

	override void execute(Variant v)
	{
		auto path = v.get!string;
		app.openFile(path);
	}

	override string[] getCompletions(Variant data)
	{
		Project p = getExtension!Project("dub.project");
		if (p is null) 
			return null;
		import std.typecons;

		string prefix = data.get!string(); 
		auto r1 = p.knownFiles.map!(a => tuple(baseName(a),a))().filter!(a => a[0].startsWith(prefix))();
		auto r2 = r1.map!(a => a[1])();
		return std.array.array(r2);
	}
}
