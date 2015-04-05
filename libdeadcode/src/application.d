module application;

import behavior.behavior;
import core.buffer;
import core.bufferview;
import core.command;
import core.stdc.errno;

import std.stdio;

class Application
{
	private
	{
		BufferViewManager _bufferViewManager;
		BufferView _currentBuffer;
		int _previousBufferID;
		EditorBehavior _editorBehavior;
		CommandManager _commandManager;
	    File _logFile;
    }

	@property
	{
		BufferViewManager bufferViewManager() { return _bufferViewManager; }
		void currentBuffer(BufferView v) { _previousBufferID = _currentBuffer is null ? 0 : _currentBuffer.id; _currentBuffer = v; }
        BufferView currentBuffer() { return _currentBuffer; }
        BufferView previousBuffer() { return bufferViewManager[_previousBufferID]; }
		EditorBehavior editorBehavior() { return _editorBehavior; }
		CommandManager commandManager() { return _commandManager; }
	}

	this()
	{
		_commandManager = new CommandManager();
		_bufferViewManager = new BufferViewManager();
		auto buf = _bufferViewManager.create("ctrl+? for help.\nctrl+w for console\n\n", "*Messages*");
		buf.cursorToEndOfLine();
		_bufferViewManager.create("", "*CommandInput*");

		// Let text editing behave like emacs
		import behavior.emacs;
		_editorBehavior = new EmacsBehavior(this);
	}

    void setLogFile(string path)
    {
        _logFile = File(path, "a");
    }

	void addMessage(Types...)(Types msgs)
	{
		import std.string;
		import std.conv;
        static import std.stdio;
		auto view = bufferViewManager["*Messages*"];
		std.stdio.writeln("*Messages* " ~ format(msgs));
        auto fmtmsg = format(msgs);
        if (_logFile.getFP() !is null)
        {
            _logFile.writeln(fmtmsg);
            _logFile.flush();
        }

		view.insert(dtext(fmtmsg));
		view.insert("\n"d);
	}
}
