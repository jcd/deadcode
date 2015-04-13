module extensions.dub;

import core.signals;
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
		// TODO: Get build configuration from package settings
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

/**
	Dub package navigation
*/
class Package : BasicExtension!Package
{
	override @property string name() { return "dub.package"; }

    // from name, to name
    mixin Signal!(string, string) onActiveConfigurationChanged;

    static class BuildSettings
    {
        string[] sourceFiles;
        string[] sourcePaths;
        string mainSourceFile;
    }

    BuildSettings globalBuildSettings;

	static class Configuration
	{
		bool isAutoConfiguration;
		string name;
        BuildSettings buildSettings;
    }

	string packageName;
	Configuration[] configurations;
	Configuration   activeConfiguration;

	string[] knownFiles;
	string   knownFilesCommonPrefix;

    override void init()
	{
        readPackageDirectory();
        app.onResourceBaseLocationChanged.connect(&updateResourceBaseLocations);
    }

    private void reset()
    {
        packageName = null;
        configurations = null;
        globalBuildSettings = null;
        activeConfiguration = null;
        knownFiles = null;
        knownFilesCommonPrefix = null;
    }

    private void updateResourceBaseLocations(uint changedLocations)
    {
        if (changedLocations & ResourceBaseLocation.currentDir)
            readPackageDirectory();
    }

    private void readPackageDirectory()
    {
        reset();

        if (readDubFile())
		{
            if (configurations.length)
                setActiveConfiguration(configurations[0].name);
		}
	}

    void setActiveConfiguration(string name)
    {
		auto r = find!(a => a.name == name)(configurations);
		if (r.empty)
		{
			app.addMessage("Cannot set unknown active configuration " ~ name);
            return;
		}
        auto conf = r.front;
        setActiveConfiguration(conf);
    }

    void setActiveConfiguration(Configuration conf)
    {
        string oldConfigName = activeConfiguration is null ? null : activeConfiguration.name;
        activeConfiguration = conf;

        knownFiles.length = 0;
        knownFilesCommonPrefix.length = 0;

        knownFiles = getConfigurationFiles(conf);
        knownFilesCommonPrefix = knownFiles.empty ? "" : knownFiles[0];
        foreach (name; knownFiles)
            knownFilesCommonPrefix = commonPrefix(name, knownFilesCommonPrefix);

        onActiveConfigurationChanged.emit(oldConfigName, activeConfiguration.name);
    }

    private Configuration lookupConfiguration(string name)
    {
		auto r = find!(a => a.name == name)(configurations);
		if (r.empty)
		{
			app.addMessage("Cannot get unknown configuration '%s'", name);
			return null;
		}
        return r.front;
    }

	private string[] getConfigurationFiles(Configuration conf)
	{
		string[] result;

        foreach (p; conf.buildSettings.sourceFiles)
			result ~= scanForFiles(p);

		foreach (p; globalBuildSettings.sourceFiles)
			result ~= scanForFiles(p);

		foreach (p; resolveSourcePaths())
			result ~= scanForFiles(p);

		if (conf.buildSettings.mainSourceFile.length)
            result ~= scanForFiles(conf.buildSettings.mainSourceFile);
        else
		    result ~= scanForFiles(globalBuildSettings.mainSourceFile);

		return result;
	}

	private bool readDubFile()
	{
		configurations = null;
		activeConfiguration = null;
        globalBuildSettings = new BuildSettings;

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

		JSONValue val = parseJSON(dubConf);
        JSONValue[string] dubObject = val.object;
		JSONValue* nameTxt = "name" in dubObject;
		if (nameTxt is null)
		{
			app.addMessage("No package name specified in dub json file");
			return false;
		}

		packageName = nameTxt.str;

        parseBuildSettings(globalBuildSettings, val);

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
        result.buildSettings = new BuildSettings;

        result.isAutoConfiguration = true;
		result.name = "library";

		if (globalBuildSettings.sourcePaths.empty)
            addAutoSourcePaths(result.buildSettings.sourcePaths);

		if (globalBuildSettings.sourcePaths.empty && result.buildSettings.sourcePaths.empty)
		{
			app.addMessage("Warning: No configuration specified in dub json file and no src or source folders present to use as default");
		}

		foreach (src; [ "source", "src" ])
        {
            foreach (n; ["app.d", "main.d", buildPath(packageName, "app.d"), buildPath(packageName, "main.d")])
		    {
			    auto mainSourceFile = buildPath(src, n);
			    if (exists(mainSourceFile) && isFile(mainSourceFile))
			    {
				    result.name = "application";
				    result.buildSettings.mainSourceFile = mainSourceFile;
				    break;
			    }
		    }
        }

		return result;
	}

    private void addAutoSourcePaths(ref string[] sourcePaths)
    {
        foreach (p; [ "source", "src" ])
		{
			if (exists(p) && isDir(p))
			{
			    sourcePaths ~= p;
			}
		}
    }

    private void parseBuildSettings(BuildSettings s, ref JSONValue conf)
    {
        JSONValue* srcFiles = "sourceFiles" in conf.object;
		if (srcFiles !is null)
		{
			foreach (ref p; srcFiles.array)
				s.sourceFiles ~= p.str;
		}

        JSONValue* srcPaths = "sourcePaths" in conf.object;
        if (srcPaths)
        {
			foreach (ref p; srcPaths.array)
				s.sourcePaths ~= p.str;
        }
    }

	private Configuration createConfiguration(ref JSONValue conf)
	{
		auto c = new Configuration;
        c.buildSettings = new BuildSettings;
		c.isAutoConfiguration = false;
		c.name = conf.object["name"].str;

        parseBuildSettings(c.buildSettings, conf);

		return c;
	}

    // The source paths is dependant on active configuration, global build settings and in case they are both empty
    // it will fall back on auto detected source paths (according to dub format spec).
    string[] resolveSourcePaths()
    {
        if (activeConfiguration is null)
            return null;
        string[] paths = globalBuildSettings.sourcePaths;
        foreach (p; activeConfiguration.buildSettings.sourcePaths)
            paths ~= p;

        if (paths.empty)
        {
            // Auto detect
			foreach (p; [ "source", "src" ])
			{
				if (exists(p) && isDir(p))
				{
					paths ~= p;
				}
			}
        }

        if (paths.empty)
            app.addMessage("Warning: No sourcePaths specified in dub config file and no default folders source or src present for configuration " ~ activeConfiguration.name);
        return paths;
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
		Package p = getExtension!Package("dub.package");
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

@InFiber
@MenuItem("Open/Dub Package", "")
void DubOpenPackage(GUIApplication app, string path)
{
    if (path.empty)
        path = app.showSelectFolderDialogBasic(r"C:\");
    app.setCurrentDirectory(path);
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
