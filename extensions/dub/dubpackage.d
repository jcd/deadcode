module extensions.dub.dubpackage;

import dccore.path;
import dccore.signals;

import std.algorithm;
import std.file;
import std.json;
import std.range;
import dccore.log;


/** Dub package

*/
class Package
{
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
        string[] importPaths;
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
    string packageRoot;

    BuildSettings globalBuildSettings;
	Configuration[] configurations;
	BuildSettings[string] buildTypes; // Build types mostly just sets build options

	string activeBuildTypeName;
    string activeBuildConfigurationName;

	BuildSettings activeBuildSettings;

	string[] knownFiles;
	string   knownFilesCommonPrefix;

    @property bool isValid() const
    {
        return activeBuildConfigurationName !is null;
    }

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

    this(string packageRoot)
    {
        this.packageRoot = buildNormalizedPath(absolutePath(packageRoot));
    }

    void refreshFromDisk()
	{
        readPackageDirectory();
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
            log.error("Error parsing dub.json: %s", e.toString());
        }
	}

    bool setActiveConfiguration(string name)
    {
		auto r = find!(a => a.name == name)(configurations);
		if (r.empty)
            return false;
        auto conf = r.front;

        if (!setActiveConfiguration(conf))
        {
            log.error("Cannot set configuration '%s'", name);
            return false;
        }
        return true;
    }

    private bool setActiveConfiguration(Configuration conf)
    {
        string oldConfigName = activeBuildConfigurationName;
        activeBuildConfigurationName = conf.name;

		if (!rebuildActiveSettings())
        {
            log.error("Cannot activate dub configuration '%s'", conf.name);
            activeBuildConfigurationName = oldConfigName;
            return false;
        }

        onActiveConfigurationChanged.emit(oldConfigName, conf.name);
        return true;
    }

    private bool setActiveBuildType(string buildTypeName)
    {
        string oldBuildTypeName = activeBuildTypeName;
        activeBuildTypeName = buildTypeName;

		if (rebuildActiveSettings())
        {
            log.error("Failed setting active build type to '%s'", buildTypeName);
            return false;
        }

        return true;
        //onActiveConfigurationChanged.emit(oldConfigName, conf.name);
    }

    private bool rebuildActiveSettings()
    {
        knownFiles.length = 0;
        knownFilesCommonPrefix.length = 0;

		auto conf = lookupConfiguration(activeBuildConfigurationName);
        if (conf is null)
            return false;

        knownFiles = getConfigurationFiles(conf);
        knownFilesCommonPrefix = knownFiles.empty ? "" : knownFiles[0];
        foreach (name; knownFiles)
            knownFilesCommonPrefix = commonPrefix(name, knownFilesCommonPrefix);

        activeBuildSettings = resolveBuildSettings(buildTypes[activeBuildTypeName], globalBuildSettings, conf.buildSettings);
        return true;
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
            if (s.importPaths !is null)
                result.importPaths = s.importPaths;
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
		if (exists(buildPath(packageRoot, "package.json")))
			dubConf = readText(buildPath(packageRoot, "package.json"));
		else if (exists(buildPath(packageRoot, "dub.json")))
			dubConf = readText(buildPath(packageRoot, "dub.json"));
		else
		{
			log.info("No dub configuration file found");
			return false;
		}

		JSONValue val = parseJSON(dubConf);
        JSONValue[string] dubObject = val.object;
		JSONValue* nameTxt = "name" in dubObject;
		if (nameTxt is null)
		{
			log.error("No package name specified in dub json file in %s ", packageRoot);
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
		result.buildSettings.importPaths = globalBuildSettings.importPaths;

		if (globalBuildSettings.sourcePaths.empty)
            addAutoSourcePaths(result.buildSettings.sourcePaths);

		if (globalBuildSettings.sourcePaths.empty && result.buildSettings.sourcePaths.empty)
		{
			log.warning("Warning: No configuration specified in dub json file and no src or source folders present to use as default in %s", packageRoot);
		}

		foreach (src; [ "source", "src" ])
        {
            foreach (n; ["app.d", "main.d", buildPath(packageName, "app.d"), buildPath(packageName, "main.d")])
		    {
			    auto mainSourceFile = buildPath(packageRoot, src, n);
			    if (exists(mainSourceFile) && isFile(mainSourceFile))
			    {
				    result.name = "application";
				    result.buildSettings.mainSourceFile = buildPath(src, n);
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
            string absPath = buildPath(packageRoot, p);
			if (exists(absPath) && isDir(absPath))
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
	                log.warning("Unknown dub target type %s", targetType.str);
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
	                log.warning("Unknown dub build option '%s'", elm.str);
            }
        }

        JSONValue* importPaths = "importPaths" in conf.object;
        if (importPaths)
        {
			foreach (ref p; importPaths.array)
				s.importPaths ~= p.str;
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
                string absPath = buildPath(packageRoot, p);
				if (exists(absPath) && isDir(absPath))
				{
					paths ~= p;
				}
			}
        }

        if (paths.empty)
        {
            if (activeConfiguration is null)
                log.warning("Warning: No sourcePaths specified in dub config file and no default folders source or src present in %s", packageRoot);
            else
                log.warning("Warning: No sourcePaths specified in dub config file and no default folders source or src present for configuration %s in %s", activeConfiguration.name, packageRoot);
        }
        return paths;
    }

	private string[] scanForFiles(string path)
	{
		path = buildPath(packageRoot, path);

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
