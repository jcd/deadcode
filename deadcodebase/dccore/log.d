module dccore.log;

import std.stdio;
import dccore.signals;

import extensionapi.rpc;
mixin registerRPC;


enum LogLevel : ubyte
{
    verbose,
    info,
    warning,
    error
}

@RPC
class Log
{
    int id;

    private
    {
        File _file;
        static int sNextID = 1;
    }

    mixin Signal!(string, LogLevel) onVerbose;
    mixin Signal!(string, LogLevel) onInfo;
    mixin Signal!(string, LogLevel) onWarning;
    mixin Signal!(string, LogLevel) onError;

    this(string path)
    {
        id = sNextID++;
        _file = File(path, "a");
    }

    File getLogFile()
    {
        return _file;
    }

    void opCall(Types...)(Types msgs)
	{
        _log(LogLevel.info, msgs);
    }

    alias log = opCall;
    alias info = opCall;
    alias i = opCall;

    void verbose(Types...)(Types msgs)
    {
        _log(LogLevel.verbose, msgs);
    }

    alias v = verbose;

    void warning(Types...)(Types msgs)
    {
        _log(LogLevel.warning, msgs);
    }

    alias w = warning;

    void error(Types...)(Types msgs)
    {
        _log(LogLevel.error, msgs);
    }

    alias e = error;

    private void _log(Types...)(LogLevel level, Types msgs)
    {
        import std.string;
		import std.conv;
        static import std.stdio;
		version (linux)
            std.stdio.writeln("*Messages* " ~ format(msgs));

        static if (msgs.length == 1)
            auto fmtmsg = format(msgs[0].to!string);
        else
            auto fmtmsg = format(msgs[0].to!string, msgs[1..$]);

        if (_file.getFP() !is null)
        {
            _file.writeln(fmtmsg);
            _file.flush();
        }

        final switch (level) with (LogLevel)
        {
            case verbose:
                onVerbose.emit(fmtmsg, verbose);
                break;
            case info:
                onInfo.emit(fmtmsg, verbose);
                break;
            case warning:
                onWarning.emit(fmtmsg, warning);
                break;
            case error:
                onError.emit(fmtmsg, error);
                break;
        }
	}
}
