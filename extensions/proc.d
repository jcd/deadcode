module extensions.proc;

import extensionapi;
mixin registerCommands;

void procFilter(Application app, BufferView bv, string batchFile)
{
    import std.array;
    import std.process;
	import std.file;

    if (!exists(batchFile))
    {
        app.addMessage("No such batch file " ~ batchFile);
        return;
    }

    auto res = pipeProcess(batchFile);

    res.stdin.write(bv.getText(0, bv.length));
    res.stdin.flush();
    res.stdin.close();

    auto apnd = appender!(ubyte[])();

    foreach (ubyte[] chunk; res.stdout.byChunk(4096))
	    apnd.put(chunk);

    if (wait(res.pid) != 0)
    {
	    app.addMessage("Error running batch file " ~ batchFile);
    }
    else
    {
        bv.clear(cast(string)apnd.data);
    }
}

void procRunCommands(Application app, BufferView bv, string cmdFile)
{
    import std.array;
    import std.exception;
    import std.stdio;
	import std.file;
    import std.string;

    if (!exists(cmdFile))
    {
        app.addMessage("No such batch file " ~ cmdFile);
        return;
    }

	foreach (l; File(cmdFile).byLine())
    {
		app.addMessage("Running " ~ l);
		auto cmdName = munch(l, "a-zA-Z_.");
        munch(l, " \t");
		collectExceptionMsg(app.commandManager.parseArgumentsAndExecute(cmdName.idup, l.idup));
    }
}

