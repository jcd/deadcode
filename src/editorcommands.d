module editorcommands;

import application;
import core.buffer;
import core.bufferview;
import core.command;
import guiapplication;
static import std.conv;
import std.variant;

// move imports into func when compiler does break on it
import std.algorithm;

auto filesystemCompletions(string path)
{	
	import std.file;
	import std.path;
	auto dirPath = dirName(absolutePath(path));
	auto filenamePrefix = baseName(path);
	return dirEntries(dirPath, SpanMode.shallow).map!(a => baseName(a.name))().filter!(a => a.startsWith(filenamePrefix))();
}

enum getBufferOrReturn = q{
	auto b = app.currentBuffer;
	if (b is null)
		return;
};

string createCmd(string name, string desc)
{
	string res = `cmgr.create("edit.` ~ name ~ `", "Move cursor to beginning of current line", delegate(Variant data) {
		mixin(getBufferOrReturn);
		b.` ~ name ~ `();
	});`;
	return res;
}

void register(Application _app)
{
	CommandManager cmgr = _app.commandManager;
	GUIApplication app = cast(GUIApplication) _app;

	// The default emacs key mappings
	cmgr.create("edit.clearBuffer", "Scroll editor window one page down", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto dl = "Hello world I am fine right now"d;
		b.clear(dl);
	});

	mixin(createCmd("cursorToBeginningOfLine", "Move cursor to beginning of current line"));
	mixin(createCmd("cursorToEndOfLine", "Move cursor to end of current line"));
	mixin(createCmd("cursorToWordBefore", "Move cursor to word before cursor"));
	mixin(createCmd("cursorToWordAfter", "Move cursor to word after cursor"));

	mixin(createCmd("selectToBeginningOfLine", "Expand selection to beginning of current line"));
	mixin(createCmd("selectToEndOfLine", "Expand selection cursor to end of current line"));
	mixin(createCmd("selectToWordBefore", "Expand selection to word before cursor"));
	mixin(createCmd("selectToWordAfter", "Expand selection to word after cursor"));

	mixin(createCmd("deleteWordBefore", "Delete word before cursor"));
	mixin(createCmd("deleteWordAfter", "Delete word after cursor"));
	mixin(createCmd("deleteToEndOfLine", "Delete line part after cursor"));
	mixin(createCmd("clear", "Clear buffer"));
	mixin(createCmd("undo", "Undo buffer"));
	mixin(createCmd("redo", "Redo buffer"));
	mixin(createCmd("copy", "Copy selection"));
	mixin(createCmd("paste", "Paste entry from copy buffer"));
	mixin(createCmd("pasteCycle", "Paste previous entry in instead of the last one just pasted copy buffer"));
	mixin(createCmd("cut", "Cut selection"));

	cmgr.create("edit.cursorToCharBefore", "Move cursor to char before cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		b.cursorLeft(1);
	});

	cmgr.create("edit.cursorToCharAfter", "Move cursor to char after cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		b.cursorRight(1);
	});

	cmgr.create("edit.cursorToCharAbove", "Move cursor to char before cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.cursorUp(1);
		uint lineNum = ctrl.lineNumber;
		//std.stdio.writeln("key down ", lineNum, " ", ctrl.lineOffset," ", ctrl.visibleLineCount /*, " ", ctrl.buffer.lineCount*/);
		if (lineNum < ctrl.lineOffset)
			ctrl.scrollUp();
	});

	cmgr.create("edit.cursorToCharBelow", "Move cursor to char after cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.cursorDown();
		uint lineNum = ctrl.lineNumber;
		if (lineNum > (ctrl.lineOffset + ctrl.visibleLineCount))
			ctrl.scrollDown();
	});

	cmgr.create("edit.selectToCharBefore", "Select to char before cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		b.selectLeft(1);
	});

	cmgr.create("edit.selectToCharAfter", "Select to char after cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		b.selectRight(1);
	});

	cmgr.create("edit.selectToCharAbove", "Select to char before cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.selectUp(1);
		uint lineNum = ctrl.lineNumber;
		//std.stdio.writeln("key down ", lineNum, " ", ctrl.lineOffset," ", ctrl.visibleLineCount /*, " ", ctrl.buffer.lineCount*/);
		if (lineNum < ctrl.lineOffset)
			ctrl.scrollUp();
	});

	cmgr.create("edit.selectToCharBelow", "Select to char after cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.selectDown();
		uint lineNum = ctrl.lineNumber;
		if (lineNum > (ctrl.lineOffset + ctrl.visibleLineCount))
			ctrl.scrollDown();
	});

	cmgr.create("edit.deleteCharBefore", "Delete character before cursor", delegate(Variant data) {	
		mixin(getBufferOrReturn);
		b.remove(-1);
	});

	cmgr.create("edit.deleteCharAfter", "Delete character after cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		b.remove(1);
	});

	cmgr.create("edit.insert", "Insert a newline at cursor", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto str = data.get!string();
		import std.conv;
		b.insert(to!dstring(str));
	});
	
	cmgr.create("edit.scrollPageDown", "Scroll view one page down", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{
			ctrl.cursorDown();
			ctrl.scrollDown();
		}
	});
	
	cmgr.create("edit.scrollPageUp", "Scroll view one page up", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	cmgr.create("edit.scrollPagedUp", "Open file", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{ 
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	cmgr.create("edit.saveBuffer", "Save file", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto view = b;
    	auto file = std.stdio.File(view.name, "wb");
		view.write(file);
    	file.flush();
    	file.close();
    	std.stdio.writefln("Wrote %s", view.name);
    });

	cmgr.create("edit.save", "Save file", delegate(Variant data) {
		mixin(getBufferOrReturn);
		auto view = b;
		// handle encoding
		auto file = std.stdio.File(view.name, "wb");
		view.write(file);
		file.flush();
		file.close();
		std.stdio.writefln("Wrote %s", view.name);
	});

	class OpenFileCommand : Command
	{
		override @property string name() const { return "edit.open"; }
		override @property string description() const { return "Open file"; }

		override void execute(Variant data)
		{
			auto path = data.get!string;
			app.openFile(path);
		}

		override string[] getCompletions(Variant data)
		{
			return std.array.array(filesystemCompletions(data.get!string()));
		}
	}

	cmgr.add(new OpenFileCommand);

	class ShowBufferCommand : Command
	{
		override @property string name() const { return "edit.showBuffer"; }
		override @property string description() const { return "Show named buffer in active window"; }

		override void execute(Variant data)
		{
			auto path = data.get!string;
			app.showBuffer(path);
		}
		
		override string[] getCompletions(Variant data)
		{
			auto prefix = data.get!string();
			auto a = app.getActiveBufferCompletions(prefix);
			
			// If the prefix is empty we know that the active buffer is the first entry. And we don't 
			// want to return that since you never want to activate the current active buffer.
			//if (prefix.empty && app.currentBuffer !is null && !app.currentBuffer.name.empty)
			//    a = a[1..$];

			return a;
		}
	}
	
	cmgr.add(new ShowBufferCommand);

	/*
	cmgr.create("edit.commitCompletion", "Commit the active completion", delegate(Variant data) {
		std.stdio.writeln("commit completion");
	});
*/

	import util.build;
	cmgr.create("core.rebuildEditor", "Rebuild the editor and replace the running instance with it", delegate(Variant data) {
//	            	build.buildIt();
	            	// Serialize
	            	// rename build version to xx
	            	// start xx
	            	//    The spawned instance will check if it is called xx then deserialize by piping to the running.exe, and then kill the original ded.exe running
	            	// timeout starting and notify
	            });

	cmgr.create("core.quit", "Quit the application", delegate(Variant data) {
		app.guiRoot.stop();		
		//	            	build.buildIt();
		// Serialize
		// rename build version to xx
		// start xx
		//    The spawned instance will check if it is called xx then deserialize by piping to the running.exe, and then kill the original ded.exe running
		// timeout starting and notify
	});

}
