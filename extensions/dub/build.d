module extensions.dub.build;

//import application;
import extensionapi.common;

import dccore.signals;
import dccore.log : LogLevel;
import core.time;

import std.concurrency;
import std.regex;
import std.process;

struct BuildStatus
{
    string packageRoot;
    string buildType;
    int exitCode = int.min;
    string target;
}

class Builder
{
    mixin Signal!(string, LogLevel) onBuildMessage;
    mixin Signal!(BuildStatus) onBuildFinished;

	private
    {
       Tid tid;
       BuildStatus status;
    }

	this(string packageRoot, string buildType, string targetName)
    {
        status.packageRoot = packageRoot;
		status.buildType = buildType;
        status.target = targetName;
    }

	void run()
	{
        assert(tid == Tid.init);
		tid = spawn(&build, thisTid);
        tid.send(status);
	}

	// In worker thread
	private static void sendLog(Tid pTid, string msg)
	{
		send(pTid, msg);
	}

	// In worker thread
	private static void build(Tid pTid)
	{
		// TODO: Get build configuration from package settings
		auto status = receiveOnly!BuildStatus();

		string cmd = "dub build -v --build=" ~ status.buildType ~ " --root=\"" ~ status.packageRoot ~ "\"";

		auto pipes = pipeShell(cmd, Redirect.stdout | Redirect.stderr, null, Config.suppressConsole);

		static void parseTargetPath(string msg, ref BuildStatus status)
        {
			enum re = ctRegex!(r"Copying target from (.+?) to .+");
			auto res = matchFirst(msg, re);
			if (!res.empty)
				status.target = res[1].idup;
        }

		foreach (line; pipes.stderr.byLine)
		{
			string l = line.idup;
//			parseTargetPath(l, status);
			sendLog(pTid, l);
		}

		foreach (line; pipes.stdout.byLine)
		{
			string l = line.idup;
//			parseTargetPath(l, status);
			sendLog(pTid, l);
		}

		status.exitCode = wait(pipes.pid);

		send(pTid, status);
	}

	// Call continuously on a timeout until false is returned ie. build is done
	bool checkBuildStatus()
	{
		if (tid == Tid.init)
		{
            import std.format;
		    onBuildMessage.emit(format("Build done at %s (exitcode %s)", status.target, status.exitCode), LogLevel.info);
            onBuildFinished.emit(status);
			return false;
		}

		import std.datetime;
		while (receiveTimeout(dur!"seconds"(0),
                              (string s) { onBuildMessage.emit(s, LogLevel.info); return true; },
                              (BuildStatus st) { tid = Tid.init;
						                         status = st;
		                                         return true;
                                               })) {}

		return true; // reschedule update callbacks
	}
}
