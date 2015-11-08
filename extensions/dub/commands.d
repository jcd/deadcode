module extensions.dub.commands;
import core.signals;
import core.time;
import core.log;

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

import extensions.dub.dubpackage;
import extensions.dub.build;

mixin registerCommands;

/*
@MenuItem("Dub/Debug")
@Shortcut("<f5>")
void dubDebug(Services s, Log log)
{
auto dubService = s.get("dub");
if (dubService is null)
log("Couldn't get dub service");
else if (dubService.activePackage is null)
log("Couldn't get active dub package");
else if (dubService.activePackage.executable is null)
log("Active dub package is not creating an excutable");
else
{
spawnProcess(dubService.activePackage.executable);
}
}
*/


@MenuItem("Dub/Build")
@Shortcut("<f10>")
class DubBuildCommand : BasicCommand
{

	void run()
	{
		clearLog();
		showBuildWidget();
        auto ext = getExtension!Dub;
		auto builder = ext.createBuilder(ext.activePackage.packageRoot);
        builder.onBuildFinished.connect(&setBuildFinished);
		builder.onBuildMessage.connect(&log);
        builder.run(app);
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

	void log(string msg, LogLevel logLevel)
	{
		// Use messages instead of calls
		import extensions.errorlist;
		auto w = getWidget!ErrorListWidget("errorlist");
		if (w is null)
			return;

		w.append(msg);
		version (linux)
            writeln(msg);
	}

	final private void showProgress(bool f)
	{
		import extensions.errorlist;
		auto w = getWidget!ErrorListWidget("errorlist");
		if (w !is null)
			w.showProgress(f);
	}

	void setBuildFinished(BuildStatus status)
	{
	    showProgress(false);
		if (status.exitCode == 0)
        {
	        // showProgress(false);
			//spawn(status.target);
        }

	    // TODO: newExecPath snatches all target build (ie. also lib deps)
	    //       which is wrong!!!
		/*
	    if (!newExecPath.empty && buildStatus == 0)
	    {
		    showProgress(false);
		    scope (exit) newExecPath = null;
		    log("Restarting " ~ newExecPath);
		    app.saveSession();
		    respawn(newExecPath);
		    return false;
	    }
        */
	}

	private void spawn(string newExecPath)
	{
        import std.file;
		import std.path;
		import std.string;

        auto thisExecNormalizedPath = absolutePath(buildNormalizedPath(thisExePath()));
        auto newExecNormalizedPath = absolutePath(buildNormalizedPath(newExecPath));

        if (newExecNormalizedPath == thisExecNormalizedPath)
        {
			version (Windows)
            {
                // Need to rename existing exe because windows locks the executable for write
                // when in use.
				auto ext = std.path.extension(thisExecNormalizedPath);
				auto np = stripExtension(thisExecNormalizedPath);
                rename(thisExecNormalizedPath, setExtension(np ~ "-old", ext));
                rename(newExecNormalizedPath, thisExecNormalizedPath);
            }
		    app.saveSession();
        }

		std.process.spawnProcess(newExecPath);
		//app.scheduleRestart(p);
	}
}

@MenuItem("Dub/Run")
@Shortcut("<f5>")
void DubRun()
{
	auto ext = getExtension!Dub;
    ext.runPackage(ext.activePackage.packageRoot);
}

/**
Dub package navigation
*/
class Dub : Extension
{
	override @property string name() { return "dub"; }

    // from name, to name
    mixin Signal!(string, string) onActivePackageChanged;

    Package[] packages;

	// package root => status
    BuildStatus[string] buildStatus;

    private int activePackageIndex = -1;

    private Package _activePackage;

    @property
    {
        Package activePackage() { return _activePackage; }
        void activePackage(Package p)
        {
            Package old = activePackage;
            _activePackage = p;
            onActivePackageChanged.emit(old is null ? null : old.packageRoot, p is null ? null : p.packageRoot);
        }
    }

    override void init()
	{
        auto p = new Package(getcwd(), app.log);
        p.refreshFromDisk();
        if (p.isValid())
        {
            packages ~= p;
            activePackage = p;
        }

        app.onResourceBaseLocationChanged.connect(&updateResourceBaseLocations);
        app.onFileOpened.connect(&enableUnittest);
    }

    Package getPackageByRootPath(string rootPath)
    {
        string normPath = buildNormalizedPath(absolutePath(rootPath));
        foreach (p; packages)
        {
            if (normPath == p.packageRoot)
                return p;
        }
        return null;
    }

    // Slot
    private void updateResourceBaseLocations(uint changedLocations)
    {
        import platform.config;

        if (changedLocations & ResourceBaseLocation.currentDir)
        {
            auto p = getPackageByRootPath(resourcesRoot);
            if (p !is null)
                activePackage = p;
        }
    }

    Builder createBuilder(string packageRoot)
    {
		auto buildPack = packages.find!(a => a.packageRoot == packageRoot);
		if (buildPack.empty)
	        return null;

        auto p = buildPack[0];
        auto b = new Builder(p.packageRoot, p.activeBuildTypeName, p.activeTargetName);
        b.onBuildFinished.connect(&setBuildResult);
        return b;
    }

    private void setBuildResult(BuildStatus status)
    {
        buildStatus[status.packageRoot] = status;
    }

    void runPackage(string packageRoot)
    {
        auto s = packageRoot in buildStatus;
        if (s !is null)
        {
            spawnProcess([s.target], cast(const(string[string]))(null));
        }
    }

    private void bufferChanged(BufferView bv, int index, int count, bool addOrRemove)
    {
        doUnittest(bv);
    }

    private void enableUnittest(BufferView bv)
    {
        app.bufferViewManager.onBufferChanged.connect(&bufferChanged);
        doUnittest(bv);
    }

    private void doUnittest(BufferView bv)
    {
        import std.datetime;
        import core.time;

        if (bv.codeModel is null || bv.codeModel.codeIntel.languageName != "D")
            return;

        SysTime now = Clock.currTime;
        auto newinfo = UnittestRunInfo(now - dur!"weeks"(1), now, false);

        auto v = UnittestRunInfo.key in bv.userData;
        if (v !is null)
            newinfo = v.get!UnittestRunInfo;

        newinfo.lastChanged = now;

        if (!newinfo.isRunning && now > newinfo.lastRun + dur!"msecs"(500))
        {
            newinfo.lastRun = now;
            newinfo.isRunning = true;
            bv.userData[UnittestRunInfo.key] = newinfo;
            app.commandManager.execute("dub.runModuleUnittests");
        }
        else
        {
            bv.userData[UnittestRunInfo.key] = newinfo;
        }

        app.pushCommandCall(CommandCall("d.checkIfElse",null));
    }
}

private
{
    struct UnittestRunInfo
    {
        import std.datetime;
        enum key = "dub.last-unittest-time";
        SysTime lastRun;
        SysTime lastChanged;
        bool isRunning;
    }
}

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
		Dub p = getExtension!Dub;
		if (p is null)
			return null;

        import std.array;
        import std.typecons;
        import util.string;

		string prefix = data[0].get!string();

        bool includePackageName = p.packages.length > 1;
        CompletionEntry[] result;

        foreach (pack; p.packages)
        {
            string packPrefix = includePackageName ? "(" ~ pack.packageName ~ ") " : "";
            auto stripPrefix = pack.knownFilesCommonPrefix.length;
		    auto r1 = pack.knownFiles
                .map!(a => tuple(baseName(a), baseName(a).rank(prefix), a, a.rank(prefix)))
                .filter!(a => (a[1] > 0.0 || a[3] > 0.0))
                .array;
            auto r2 = r1
                .sort!((a,b) => a[1] > b[1] || ( a[1] == b[1] && a[3] > b[3]))
                .map!(a => CompletionEntry(packPrefix ~ a[2][stripPrefix..$], a[2]))
                .array;
            result ~= r2;
        }

        //.filter!(a => a[0].startsWith(prefix));
		//auto r2 = r1.map!(a => CompletionEntry(a[1][stripPrefix..$], a[1]));
		return result;
	}
}

@InFiber
@MenuItem("Open/Dub Package", "")
void DubOpenPackage(Application app, string path)
{
    if (path.empty)
        path = app.showSelectFolderDialogBasic(r"C:\");
    app.setCurrentDirectory(path);
}

enum unitTestsID = 0xFF00FF00;

static TextEditorAnchorManager!(ubyte, GenericTextEditorAnchorCSS!"unittest-result") unittestResultAnchorManager;
static this()
{
    unittestResultAnchorManager = new typeof(unittestResultAnchorManager);
}

enum buildErrorsID = 0xFF00FFFF;

static TextEditorAnchorManager!(ubyte, GenericTextEditorAnchorCSS!"build-result") buildResultAnchorManager;
static this()
{
    buildResultAnchorManager = new typeof(buildResultAnchorManager);
}


@MenuItem("Open/Dub Unittest", "")
@Shortcut("<ctrl> + l")
@InFiber()
void dubRunModuleUnittests(Application app, BufferView bv)
{
	if (bv.codeModel is null || bv.codeModel.codeIntel.languageName != "D")
        return;

    Dub p = getExtension!Dub;
    if (p is null)
	    return;

	import std.algorithm;
	import std.conv;
    import std.path;
    import std.file;

	if (bv.name.endsWith("deadcodetest.d"))
    {
	    remove(bv.name);
		return;
    }

    string path = bv.name.stripExtension() ~ "deadcodetest.d";

    auto target = path.stripExtension();

	enum setupAssertHandlerSource = q"{
        module deadcodeasserthandler;
        void deadcodeAssetHandler(string file, size_t line, string msg) nothrow
    {
        import std.stdio;
        try
        {
	    writeln("deadcode-test-error;", file, ";", line, ";", msg);
        }
        catch (Exception)
        {
        ; // ignore
        }
}

static this()
{
	static import core.exception;
        core.exception.assertHandler = &deadcodeAssetHandler;
}
}";

auto tempPath = buildPath(tempDir(), "deadcode_unittest_asserthandler.d");
int[] anchors;
auto editor = app.getTextEditorForBufferView(bv);
import extensions.errorlist;
ErrorListWidget err = app.getWidget!ErrorListWidget("errorlist");

while (true)
{
	anchors.length = 0;
    write(path, bv.getText().to!string);
    std.file.write(tempPath, setupAssertHandlerSource);
string[] flags = [ "-version=TestingByDeadcode" ];
auto runInfo = buildAndRun(target, [tempPath,path], p.activePackage.activeBuildSettings.importPaths ~ p.activePackage.activeBuildSettings.sourcePaths, flags);

app.yield(&wait, runInfo[0]);
if (exists(path))
    remove(path);
runInfo[1].rewind();

//auto bv = app.openFile(path);


auto oldAnchorIDs = unittestResultAnchorManager.getAnchorIDs(editor);

import extensions.errorlist;
import std.array;
bool unittestFailed = false;

ErrorListWidget.Message[] messages;

foreach (l; runInfo[1].byLine())
{
    if (l.startsWith("deadcode-test-error"))
    {
        unittestFailed = true;
        auto toks = l.split(";");

        if (err !is null)
        {
            auto msg = toks[3..$].join(" ");
            auto filename = text(toks[1].chomp("deadcodetest.d"), ".d");
            auto line = ErrorListWidget.Message(ErrorListWidget.MessageType.test, text(filename, "(", toks[2], "): ", msg, "\n"),
                                                filename, toks[2].to!int - 1, 0);
            // Link test result and messages in the errorlist so that we can later remove them from
            // the error list when tests goes green.
            line.owner = editor;
            line.ownerID = unitTestsID;
			messages ~= line;
            app.addMessage(line.message.to!string);
        }
    }
    else
    {
        string msgStr = l.idup;
        auto msg = ErrorListWidget.parseMessage(msgStr);
        msg.owner = editor;
        msg.ownerID = buildErrorsID;
        msg.file = msg.file.endsWith("deadcodetest.d") ? msg.file.chomp("deadcodetest.d") ~ ".d" : msg.file;

        app.addMessage("<unittest> " ~ l.replace("%", "%%"));
        if (msg.file !is null)
        {
    		messages ~= msg;
        }
    }
}

    // Todo: should be signal based or something
    auto v = UnittestRunInfo.key in bv.userData;
    if (v !is null)
    {
        auto info = v.get!UnittestRunInfo;
        if (info.lastRun < info.lastChanged && info.isRunning)
        {
            // Do a rerun if the buffer changed and it was automatically scheduled
            info.lastRun = info.lastChanged;
            bv.userData[UnittestRunInfo.key] = info;
        }
        else
        {
            // All done
            info.isRunning = false;
            bv.userData[UnittestRunInfo.key] = info;
			// app.pushCommandCall(CommandCall("d.checkIfElse",null));
	        goto done;
        }
    }
    else
    {
done:
		if (err !is null)
		{
		    // Remove existing error lines associated with unittest for this editor
    	    err.removeMessages(editor, buildErrorsID);
			buildResultAnchorManager.removeLineAnchors(editor);

            bool gotBuildError = false;
            foreach (m; messages)
            {
                if (m.ownerID == buildErrorsID)
                {
	                err.append(m);
              	  buildResultAnchorManager.ensureLineAnchor(editor, m.line, 0);
					gotBuildError = true;
                }
            }

            if (!gotBuildError)
            {
			    err.removeMessages(editor, unitTestsID);
				unittestResultAnchorManager.removeLineAnchors(editor);
	            foreach (m; messages)
	            {
	                if (m.ownerID == unitTestsID)
                    {
                  	  unittestResultAnchorManager.ensureLineAnchor(editor, m.line, 0);
		                err.append(m);
                    }
	            }
            }
    	}

       break;
    }
    messages.length = 0;
}

}

private auto spawnProcess(
                             in char[][] args,
                             const string[string] env = null,
                             in char[] workDir = null)
    {
        static import std.process;
        import std.typecons;
        auto tempPath = buildPath(tempDir(), "deadcode_unittest.log");
        auto tempLog = File(tempPath, "w+");
		import std.array;
        tempLog.writeln(args.join(" "));
        auto pid = std.process.spawnProcess(args, std.stdio.stdin, tempLog, tempLog, env, Config.suppressConsole | Config.retainStdout | Config.retainStderr, workDir);
        return tuple(pid, tempLog);
    }

    private auto buildAndRun(string targetPath, string[] sourcePaths, string[] importPaths, string[] flags)
    {
        import std.conv;
        enum compiler = r"C:\D\dmd2\windows\bin\rdmd.exe";
	    import std.algorithm;

        string[] args = [compiler, "-of"~targetPath, "-unittest","-main"];
		args ~= flags;
		args ~= "-vcolumns";

        importPaths.each!((a) { args ~= "-I\"" ~ a ~ "\""; });
	    if (sourcePaths.length > 1)
        {
            sourcePaths[0..$-1].each!((a) { args ~= "--extra-file=" ~ a; });
        }
        args ~= sourcePaths[$-1];
        return spawnProcess(args);

        //return spawnProcess(log, format("%s -of%s %s %s", compiler, targetPath, flags, text(srcs)));
    }
