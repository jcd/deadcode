/** Extension to allow for easy setup and doing developent of deadcode itself

*/
module extensions.language.deadcodedev;

import extensions;
mixin registerCommands;

import std.file;
import std.path;
import std.stdio;
import std.string;
import util.system;
import util.semver;

private class DeadcodeDevConfig
{
    string path; /// path to root dir of deadcode development setup
}

@MenuItem("New/Deadcode Dev Env")
void deadcodeSetupDevelopmentEnvironment(GUIApplication app)
{
    import platform.dialog;

    // Look in user config for a path to deadcode dev dir
    auto sessionData = app.get("deadcodedev");
    if (sessionData is null)
        return;

    auto s = sessionData.get!DeadcodeDevConfig();
    if (s is null)
    {
        s = new DeadcodeDevConfig();
        sessionData.add(s);
    }

    if (s.path.length)
    {
        auto res = queryDeadcodeDevelopmentDir(s.path);

        final switch (res.match)
        {
            case DeadcodeDirMatch.notDevelopmentDir:
                app.addMessage("Error: Configured Deadcode development dir is invalid or does not exist");
                break;
            case DeadcodeDirMatch.versionInvalid:
                app.addMessage("Error: Configured Deadcode development dir contains an invalid version file");
                return;
            case DeadcodeDirMatch.versionMismatch:
                app.addMessage("Error: Configured Deadcode development dir has version mismatch with running Deadcode instance");
                return;
            case DeadcodeDirMatch.OK:
                app.addMessage("Using previously configured Deadcode development dir");
                return;
        }
    }

    // Look at current running Deadcode instance working dir to see if it is a Deadcode development dir
    string p = getRunningExecutablePath();
    auto res = queryDeadcodeDevelopmentDir(p.dirName);

    final switch (res.match)
    {
        case DeadcodeDirMatch.notDevelopmentDir:
            break;
        case DeadcodeDirMatch.versionInvalid:
            app.addMessage("Error: Deadcode is currently running in a dir containing an invalid formatted version file.");
            return;
        case DeadcodeDirMatch.versionMismatch:
            app.addMessage("Error: Deadcode version does not work with the version file in the directory that deadcode is currently running in.");
            return;
        case DeadcodeDirMatch.OK:
            app.addMessage("Deadcode is already running in a valid development directory.");
            s.path = p.dirName;
            sessionData.save();
            return;
    }

    // Prompt user for where to make a working directory
    string dir = showSelectFolderDialogBasic("c:\\");
    res = queryDeadcodeDevelopmentDir(dir);

    final switch (res.match)
    {
        case DeadcodeDirMatch.notDevelopmentDir:
            // This is not already a dev dir. Set it up.
            if (setupNewDeadcodeDevelopmentDir(app, dir))
            {
                s.path = p.dirName;
                sessionData.save();
            }
            break;
        case DeadcodeDirMatch.versionInvalid:
            app.addMessage("Error: Configured Deadcode development dir contains an invalid version file");
            return;
        case DeadcodeDirMatch.versionMismatch:
            app.addMessage("Error: Configured Deadcode development dir has version mismatch with running Deadcode instance");
            return;
        case DeadcodeDirMatch.OK:
            app.addMessage("Using previously configured Deadcode development dir");
            return;
    }
}

private bool setupNewDeadcodeDevelopmentDir(GUIApplication app, string dir)
{
    import std.stdio;
    app.addMessage("Setting up Deadcode development dir %s", dir);
    if (!exists(dir))
    {
        app.addMessage("Error: Dir %s doesn't exist", dir);
        return false;
    }

    if (!dirEntries(dir, SpanMode.shallow).empty)
    {
        app.addMessage("Error: Dir %s not empty", dir);
        return false;
    }

    if (!shellCommandExists("git"))
    {
        app.addMessage("Cannot locate git command. Please install git.");
        return false;
    }

    if (!shellCommandExists("dmd"))
    {
        app.addMessage("dmd command not present. Downloading and installing dmd");
        if (installDMD(app))
        {
            app.addMessage("Successfully installed dmd");
        }
        else
        {
            app.addMessage("Error installing dmd");
            return false;
        }
    }

    if (gitClone(dir))
    {
        version (Windows)
        {
            import std.c.windows.windows;
            import std.conv;

            if (SetCurrentDirectoryW(dir.to!wstring.ptr))
                app.addMessage("Current working dir %s", dir);
            else
                app.addMessage("Error: Current working dir not %s", dir);
        }
    }
    else
    {
        app.addMessage("Couldn't clone deadcode from github");
    }
    return false;
}

bool gitClone(string dir)
{
    import std.process;
    string cmd = "git.exe clone https://github.com/jcd/deadcode.git " ~ dir;
    auto res = pipeShell(cmd, Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);
    foreach (line; res.stdout.byLine)
    {
        writeln(line);
    }
    return wait(res.pid) == 0;
}


private bool shellCommandExists(string cmd)
{
    import std.process;
    import std.regex;

    auto res = pipeShell(cmd, Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);
    version (Windows)
    {
        auto re = regex(r"is not recognized as an internal or external command");
    }
    foreach (line; res.stdout.byLine)
    {
        if (!line.matchFirst(re).empty)
            return false;
    }
    wait(res.pid);
    return true;
}

bool installDMD(GUIApplication app)
{
    import std.file;
    import std.net.curl;
    import std.path;
    import std.process;

    // TODO: This need to be async
    /*
    auto notice = app.getWidget!Notice("noticeDialog");
    notice.visible = true;
    notice.text = "Downloading dmd... please wait");
    */
    enum url = "http://downloads.dlang.org/releases/2014/dmd-2.066.0.exe";
    auto dest = buildPath(tempDir(), "dmd-install.exe");
    download(url, dest);
    if (!exists(dest))
    {
        app.addMessage("Couldn't download dmd for install");
        return false;
    }

    auto res = pipeShell(dest, Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);
    int exitCode = wait(res.pid);
    return exitCode == 0;
}

private enum DeadcodeDirMatch
{
    notDevelopmentDir,
    versionInvalid,
    versionMismatch,
    OK,
}

private struct DeadcodeDirQueryResult
{
    DeadcodeDirMatch match;
    SemanticVersion semver;
}

private DeadcodeDirQueryResult queryDeadcodeDevelopmentDir(string path)
{
    string versionFilePath = buildPath(path, "version");
    auto result = DeadcodeDirQueryResult();

    if (!exists(versionFilePath))
    {
        result.match = DeadcodeDirMatch.notDevelopmentDir;
        return result;
    }

    immutable string runningVersion = "0.13"; // TODO: fetch from somewhere generated

    // This is already running in a suitable working dir it seems.
    string verStr = readText(versionFilePath);
    bool success;
    auto execVer = SemanticVersion.parse(runningVersion, &success);
    if (success)
    {
        auto dirVer  = SemanticVersion.parse(verStr, &success);
        result.semver = dirVer;
        if (success)
        {
            // For now the version must match major.minor ... this should probably be relaxed later.
            if (execVer.major == dirVer.major && execVer.minor == dirVer.minor)
            {
                // All ok!
                result.match = DeadcodeDirMatch.OK;
            }
            else
            {
                result.match = DeadcodeDirMatch.versionMismatch;
            }
        }
        else
        {
            result.match = DeadcodeDirMatch.versionInvalid;
        }
    }
    else
    {
        throw new Exception("Cannot parse running executables version string");
    }
    return result;
}


class Notice : BasicWidget
{
    import gui.label;

    private Label _label;

    override void init()
	{
		name = "noticeDialog";
        _label = new Label("");
        _label.parent = this;
        visible = false;
    }

    void setMessage(string m)
    {
        _label.text = m;
    }
}
