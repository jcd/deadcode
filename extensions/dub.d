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
    private string thisExecNormalizedPath; // special handling for building deadcode itself
    private int buildStatus;
    
	void run()
	{
		clearLog();
		showBuildWidget();
		newExecPath = null;
		buildStatus = -1;
		thisExecNormalizedPath = buildNormalizedPath(thisExePath());
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

		auto re = regex(r"Copying target from (.+?) to .+");
		auto res = matchFirst(msg, re);
		if (!res.empty)
		{
			newExecPath = res[1].idup;
		}
		w.append(msg);
		version (linux)
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
		string cmd = "./dub build -v --build=" ~ configuration;

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
            import std.conv;
		    log("Build done at " ~ newExecPath ~ " " ~ buildStatus.to!string);

		    // TODO: newExecPath snatches all target build (ie. also lib deps)
		    //       which is wrong!!!
		    if (!newExecPath.empty && buildStatus == 0)
		    {
			    showProgress(false);
			    scope (exit) newExecPath = null;
			    log("Restarting " ~ newExecPath);
			    app.saveSession();
			    respawn(newExecPath);
			    return false;
		    }

			return false;
		}

		import std.datetime;
		while (receiveTimeout(dur!"seconds"(0),
					   (string s) { log(s); return true; },
					   (int status) { tid = Tid.init; buildStatus = status; return true; })) {}

		return true; // reschedule update callbacks
	}

	private void spawnBuildTarget(string execPath)
	{
		import std.process;
		spawnProcess(execPath);
		          
	}

	private void respawn(string newExecPath)
	{
		//auto hwnd = FindWindowA("SDL_app", null);
		//writeln("existing is ", hwnd);

		//return;
		auto p = thisExecNormalizedPath;
		version (Windows)
        {
	        import std.file;
			import std.path;
			import std.string;
			auto ext = std.path.extension(p);
			auto np = stripExtension(p);
	
			// Special case when started using visual D and then compiled using dub
			if (np.endsWith("_d"))
				np = np[0..$-2];
	
			rename(p, setExtension(np ~ "-old", ext));
			rename(newExecPath, p);           
        }
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

	enum TargetType
    {
        autodetect,
        none,
        executable,
        library,
        sourceLibrary,
        staticLibrary,
        dynamicLibrary
    }
    
    enum BuildOption
    {
        debugMode,
        releaseMode,
        coverage,
        debugInfo,
        debugInfoC,
        alwaysStackFrame,
        stackStomping,
        inline,
        noBoundsCheck,
        optimize,
        profile,
        unittests,
        verbose,
        ignoreUnknownPragmas,
        syntaxOnly,
        warnings,
		warningsAsErrors,
        ignoreDeprecations,
        deprecationWarnings,
        deprecationErrors,
        property,
    }

    static class BuildSettings
    {
        string[] sourceFiles;
        string[] sourcePaths;
        string mainSourceFile;
	    TargetType targetType;
        string targetName;
        BuildOption[] buildOptions;
    }

	static class Configuration
	{
		bool isAutoConfiguration;
		string name;
        BuildSettings buildSettings;
    }

	string packageName;
    BuildSettings globalBuildSettings;
	Configuration[] configurations;
	BuildSettings[string] buildTypes; // Build types mostly just sets build options

	string activeBuildTypeName;
    string activeBuildConfigurationName;

	BuildSettings activeBuildSettings;
    
	string[] knownFiles;
	string   knownFilesCommonPrefix;

    @property string activeTargetName()
    {
        if (activeBuildSettings is null)
	        return null;
        version (Windows)
	        return activeBuildSettings.targetName ~ ".exe";
        else
            return activeBuildSettings.targetName;
    }
    
    @property bool unittestsEnabled()
    {
        if (activeBuildSettings is null)
	        return false;
        return activeBuildSettings.buildOptions.canFind(BuildOption.unittests);
    }

    override void init()
	{
        readPackageDirectory();
        app.onResourceBaseLocationChanged.connect(&updateResourceBaseLocations);
    }

    private void reset()
    {
        packageName = null;
        globalBuildSettings = null;
        configurations = null;
		buildTypes = typeof(buildTypes).init;
        activeBuildTypeName = "debug";
        activeBuildConfigurationName = null;
        
        activeBuildSettings = null;
        
        knownFiles = null;
        knownFilesCommonPrefix = null;
    
	    static BuildSettings bs(BuildOption[] o)
        {
            auto b = new BuildSettings;
            b.buildOptions = o;
            return b;
        }
        buildTypes = typeof(buildTypes).init;
        buildTypes["plain"]        = bs([]);
	    buildTypes["debug"]        = bs([BuildOption.debugMode, BuildOption.debugInfo]);
		buildTypes["release"]      = bs([BuildOption.releaseMode, BuildOption.optimize, BuildOption.inline]);
		buildTypes["unittest"]     = bs([BuildOption.unittests, BuildOption.debugMode, BuildOption.debugInfo]);
		buildTypes["docs"]         = bs([BuildOption.syntaxOnly]);
		buildTypes["ddox"]         = bs([BuildOption.syntaxOnly]);
		buildTypes["profile"]      = bs([BuildOption.profile, BuildOption.optimize, BuildOption.inline, BuildOption.debugInfo]);
		buildTypes["cov"]          = bs([BuildOption.coverage, BuildOption.debugInfo]);
		buildTypes["unittest-cov"] = bs([BuildOption.unittests, BuildOption.coverage, BuildOption.debugMode, BuildOption.debugInfo]);
    }

    private void updateResourceBaseLocations(uint changedLocations)
    {
        if (changedLocations & ResourceBaseLocation.currentDir)
            readPackageDirectory();
    }

    private void readPackageDirectory()
    {
        reset();

        try
        {
            if (readDubFile())
		    {
                if (configurations.length)
                    setActiveConfiguration(configurations[0].name);
		    }
        }
        catch (JSONException e)
        {
            app.addMessage("Error parsing dub.json: " ~ e.toString());
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

    private void setActiveConfiguration(Configuration conf)
    {
        string oldConfigName = activeBuildConfigurationName;
        activeBuildConfigurationName = conf.name;

		rebuildActiveSettings();
                   
        onActiveConfigurationChanged.emit(oldConfigName, conf.name);
    }
    
    private void setActiveBuildType(string buildTypeName)
    {
        string oldBuildTypeName = activeBuildTypeName;
        activeBuildTypeName = buildTypeName;

		rebuildActiveSettings();
                   
        //onActiveConfigurationChanged.emit(oldConfigName, conf.name);
    }

    private void rebuildActiveSettings()
    {
        knownFiles.length = 0;
        knownFilesCommonPrefix.length = 0;

		auto conf = lookupConfiguration(activeBuildConfigurationName);
        knownFiles = getConfigurationFiles(conf);
        knownFilesCommonPrefix = knownFiles.empty ? "" : knownFiles[0];
        foreach (name; knownFiles)
            knownFilesCommonPrefix = commonPrefix(name, knownFilesCommonPrefix);

        activeBuildSettings = resolveBuildSettings(buildTypes[activeBuildTypeName], globalBuildSettings, conf.buildSettings);        
    }

	private BuildSettings resolveBuildSettings(ARGS...)(ARGS settings)
    {
		BuildSettings result = new BuildSettings;
		foreach (s; settings)
        {
			    
			   if (s.sourceFiles !is null)
		            result.sourceFiles = s.sourceFiles;
		       if (s.sourcePaths !is null)
		            result.sourcePaths = s.sourcePaths;
               if (s.mainSourceFile !is null)
		            result.mainSourceFile = s.mainSourceFile;
               if (s.targetType != TargetType.autodetect)
		            result.targetType = s.targetType;
		       if (s.targetName !is null)
		            result.targetName = s.targetName;
			   if (s.buildOptions !is null)
		            result.buildOptions = s.buildOptions;
        }
        return result;
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
        globalBuildSettings = new BuildSettings;
		globalBuildSettings.targetType = TargetType.autodetect;
	
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
        
        if (auto buildTyps = "buildTypes" in dubObject)
        {
            foreach (string key; buildTyps.object.keys)
            {
                auto buildTyp = buildTyps.object[key];
                BuildSettings buildTypeBuildSettings = new BuildSettings;
                parseBuildSettings(buildTypeBuildSettings, buildTyp);
                buildTypes[key] = buildTypeBuildSettings;
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

		result.buildSettings.targetType = globalBuildSettings.targetType;
        result.buildSettings.targetName = globalBuildSettings.targetName;

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
		import std.conv;
        
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
        
        JSONValue* targetType = "targetType" in conf.object;
        if (targetType)
        {
            switch (targetType.str)
            {
                case "autodetect": 
	                s.targetType = TargetType.autodetect;
                    break;
                case "none": 
	                s.targetType = TargetType.none;
                    break;
                case "executable": 
	                s.targetType = TargetType.executable;
                    break;
                case "library": 
	                s.targetType = TargetType.library;
                    break;
                case "sourceLibrary": 
	                s.targetType = TargetType.sourceLibrary;
                    break;
                case "staticLibrary": 
	                s.targetType = TargetType.staticLibrary;
                    break;
                case "dynamicLibrary": 
	                s.targetType = TargetType.dynamicLibrary;
                    break;
                default:
	                app.addMessage("Unknown target type %s", targetType.str);
                    break;
            }
        }
        else
        {
            s.targetType = TargetType.autodetect;
        }
        
        if (auto targetName = "targetName" in conf.object)
            s.targetName = targetName.str;
            
        if (auto buildOpts = "buildOptions" in conf.object)
        {
            foreach (ref elm; buildOpts.array)
            {
                try
	                s.buildOptions ~= elm.str.to!BuildOption();
	            catch (ConvException e)
	                app.addMessage("Unknown build option '%s'", elm.str);
            }
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
		Configuration activeConfiguration = lookupConfiguration(activeBuildConfigurationName);

        string[] paths = globalBuildSettings.sourcePaths;

        if (activeConfiguration !is null && activeConfiguration.buildSettings.sourcePaths !is null)
	        paths = activeConfiguration.buildSettings.sourcePaths;
 
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
        {
            if (activeConfiguration is null)
                app.addMessage("Warning: No sourcePaths specified in dub config file and no default folders source or src present");
            else
                app.addMessage("Warning: No sourcePaths specified in dub config file and no default folders source or src present for configuration " ~ activeConfiguration.name);
        }
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

        import std.array;
        import std.typecons;
        import util.string;

		string prefix = data[0].get!string();
		auto stripPrefix = p.knownFilesCommonPrefix.length;
		auto r1 = p.knownFiles
            .map!(a => tuple(baseName(a), baseName(a).rank(prefix), a, a.rank(prefix)))
            .filter!(a => (a[1] > 0.0 || a[3] > 0.0))
            .array;
        auto r2 = r1
            .sort!((a,b) => a[1] > b[1] || ( a[1] == b[1] && a[3] > b[3]))
            .map!(a => CompletionEntry(a[2][stripPrefix..$], a[2]))
            .array;

            //.filter!(a => a[0].startsWith(prefix));
		//auto r2 = r1.map!(a => CompletionEntry(a[1][stripPrefix..$], a[1]));
		return r2;
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
