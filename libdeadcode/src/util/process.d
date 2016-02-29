module util.process;

auto spawnProcess(in char[][] args,
                  in char[] tempFileName = null,
                  const string[string] env = null,
                  in char[] workDir = null)
{
    import dccore.path;

    static import std.process;
	import std.array;
    import std.file;
    import std.stdio;
    import std.typecons;

    auto tempPath = buildPath(tempDir(), tempFileName);
    auto tempLog = File(tempPath, "w+");
    tempLog.writeln(args.join(" "));
    auto pid = std.process.spawnProcess(args, std.stdio.stdin, tempLog, tempLog, env, std.process.Config.suppressConsole | std.process.Config.retainStdout | std.process.Config.retainStderr, workDir);
    return tuple(pid, tempLog);
}
