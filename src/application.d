module application;

import behavior.behavior;
import core.buffer;
import core.bufferview;
import core.command;
import core.stdc.errno;

class Application
{
	private
	{
		BufferViewManager _bufferViewManager;
		BufferView _currentBuffer;
		EditorBehavior _editorBehavior;
		CommandManager _commandManager;
	}
	
	@property
	{
		BufferViewManager bufferViewManager() { return _bufferViewManager; }
		ref BufferView currentBuffer() { return _currentBuffer; }
		EditorBehavior editorBehavior() { return _editorBehavior; }
		CommandManager commandManager() { return _commandManager; }
	}

	this()
	{
		_commandManager = new CommandManager();
		_bufferViewManager = new BufferViewManager();
		auto buf = _bufferViewManager.create("ctrl+? for help.\nctrl+w for console\nfoobar hfhff\n", "*Messages*");
		buf.cursorToEndOfLine();
		_bufferViewManager.create("", "*CommandInput*");

		// Let text editing behave like emacs
		import behavior.emacs;
		_editorBehavior = new EmacsBehavior(this);
	}

	void addMessage(Types...)(Types msgs)
	{
		import std.string;
		import std.conv;
		auto view = bufferViewManager["*Messages*"];
		std.stdio.writeln("*Messages* " ~ format(msgs));
		view.insert(dtext(format(msgs)));
		view.insert("\n"d);
	}
}
