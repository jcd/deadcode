module extensions.dub;

import core.time;

import extensions;
import math;
import gui.layout.constraintlayout;

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

import extensions.statuspanel;

mixin registerCommands;

@MenuItem("Dub/Build")
@Shortcut("<f10>")
class DubBuildCommand : BasicCommand
{
	//override @property string description() const { return "Build using dub"; }
	// override @property string name() const { return "dub.build"; }
	//override @property string shortcut() const { return "<f7>"; }

	private Tid tid;
	private string newExecPath;

	void run()
	{
		clearLog();
		showBuildWidget();
		newExecPath = null;
		tid = spawn(&build, thisTid);
		app.guiRoot.timeout(dur!"msecs"(200), &buildUpdate);
	}

	void showBuildWidget()
	{
		import extensions.errorlist;
		auto w = getWidget!ErrorListWidget("errorlist");

		if (w is null)
			return;

		w.visible = true;
		w.showProgress(true);

		auto p = getWidget!StatusPanel("statuspanel");
		if (p is null)
			return;

		p.mode = StatusPanel.Mode.discrete;

		//auto we = cast(ErrorListWidget)w;
		//if (we !is null)
		//{
		//    we.
		//}

	}

	void log(string msg)
	{
		// Use messages instead of calls
		import extensions.errorlist;
		auto w = getWidget!ErrorListWidget("errorlist");
		if (w is null)
			return;

		auto re = regex(r"Copying target from (.+?\.exe) to .+");
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
		auto w = getWidget!ErrorListWidget("errorlist");
		if (w is null)
			return;
		w.clear();
	}

	static void build(Tid pTid)
	{
		// TODO: Get build configuration from project settings
		string configuration = "debug";
		string cmd = "dub build -v --config=" ~ configuration;

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

		send(pTid, res);
	}

	final private void showProgress(bool f)
	{
		import extensions.errorlist;
		auto w = getWidget!ErrorListWidget("errorlist");
		if (w !is null)
			w.showProgress(f);
	}

	bool buildUpdate()
	{
		if (tid == Tid.init)
		{
			showProgress(false);
			return false;
		}

		import std.datetime;
		while (receiveTimeout(dur!"seconds"(0),
					   (string s) { log(s); return true; },
					   (int status) { tid = Tid.init; return true; })) {}

		if (!newExecPath.empty)
		{
			showProgress(false);
			scope (exit) newExecPath = null;
			log("Restarting " ~ newExecPath);
			app.saveSession();
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
		import std.string;
		auto p = buildNormalizedPath(thisExePath());
		auto ext = std.path.extension(p);
		auto np = stripExtension(p);

		// Special case when started using visual D and then compiled using dub
		if (np.endsWith("_d"))
			np = np[0..$-2];

		rename(p, setExtension(np ~ "-old", ext));
		rename(newExecPath, p);
		app.scheduleRestart(p);
	}
}

// extern (Windows) nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);


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
	string   knownFilesCommonPrefix;

	override void init()
	{
		if (readDubFile() && !configurations.empty)
		{
			knownFiles = getConfigurationFiles(configurations.front.name);
			knownFilesCommonPrefix = knownFiles.empty ? "" : knownFiles[0];
			foreach (name; knownFiles)
				knownFilesCommonPrefix = commonPrefix(name, knownFilesCommonPrefix);
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
			dubConf = readText("dub.json");
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
					result ~= buildNormalizedPath(e.name);
			}
			return result;
		}
		return null;
	}
}

//class DubProjectHierarchy : BasicWidget
//{
//
//}

class DubQuickOpenCommand : BasicCommand
{
	// override @property string description() const { return "Quick open file in dub project"; }
	// override @property string name() const { return "dub.quickopen"; }
	// override @property string shortcut() const { return "<ctrl> + ,"; }

	void run(string path)
	{
		// auto path = v[0].get!string;
		app.openFile(path);
	}

	override CompletionEntry[] getCompletions(CommandParameter[] data)
	{
		Project p = getExtension!Project("dub.project");
		if (p is null)
			return null;
		import std.typecons;

		string prefix = data[0].get!string();
		auto stripPrefix = p.knownFilesCommonPrefix.length;
		auto r1 = p.knownFiles.map!(a => tuple(baseName(a),a))().filter!(a => a[0].startsWith(prefix))();
		auto r2 = r1.map!(a => CompletionEntry(a[1][stripPrefix..$], a[1]))();
		return std.array.array(r2);
	}
}


// import extensions.search;
// import extensions.attr;

//alias isPublicFunctionInModule2(T) = isPublicFunctionInModule!T;

// pragma (msg, moduleMembers);

//pragma (msg, isPublicFunctionInModule2!"search2");
/*
template moduleSymbolNameToSymbol(alias Mod)
{
pragma (msg, "Moda ", moduleName!Mod ~ "." ~ symName);
template moduleSymbolNameToSymbol(string symName)
{
pragma (msg, "Modb ", moduleName!Mod ~ "." ~ symName);
alias moduleSymbolNameToSymbol = mixin(moduleName!Mod ~ "." ~ symName);
}
}
*/
// import std.typetuple;

//pragma (msg, __traits(getMember, extensions.search, "search2"));

// enum moduleMembers = Filter!(isPublicFunctionInModule!(extensions.search), __traits(allMembers, extensions.search));
//enum moduleCommandFunctions(alias Mod) = staticMap!(getModuleFunctionByName!Mod, Filter!(isPublicFunctionInModule!(Mod), __traits(allMembers, Mod)));


//alias searchCmds = moduleCommandFunctions!(extensions.search);
//pragma (msg, searchCmds);


//enum extensionCommands = staticMap!(getModuleFunctionByName2!(extensions.search), searchCmds);
//alias X = RegisterCommand!(__traits(getMember, extensions.search, "search2"));

//alias Y(alias Mod, string symName) = RegisterCommand!(__traits(getMember, extensions.search, "search2"));
//alias Y2 = Y!(extensions.search, "search2");
//pragma (msg, Y2);

//alias extensionCommands = staticMap!(getModuleFunctionByName2!(extensions.search), searchCmds);


//pragma (msg, extensionCommands!(__MODULE__));
// pragma (msg, extensionCommands!());
//mixin registerCommands;

//pragma (msg, extensionCommands!(extensions.search));
//pragma (msg, extensionCommands!(extensions.search));
