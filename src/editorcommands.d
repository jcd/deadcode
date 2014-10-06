module editorcommands;

import application;
import core.buffer;
import core.bufferview;
import core.command;
import core.commandparameter;
import guiapplication;
static import std.conv;

// move imports into func when compiler does break on it
import std.algorithm;

auto filesystemCompletions(string path)
{	
	import std.file;
	import std.path; 
	import std.string;

	string relDirPath = path;
	string filenamePrefix;
	if (!path.empty)
	{
		auto ch = path[$-1];
		if (!isDirSeparator(ch))
		{
			relDirPath = dirName(path);
			filenamePrefix = baseName(path);
		}
			
		if (relDirPath == ".")
			relDirPath = "";
	}

	//auto dirPath = dirName(absolutePath(path));
	//	auto filenamePrefix = baseName(path);	

	debug std.stdio.writeln(path, " ", relDirPath, " : ", filenamePrefix, " ", dirEntries(relDirPath, SpanMode.shallow));

	return dirEntries(relDirPath, SpanMode.shallow)
		.filter!(a => a.name.baseName.startsWith(filenamePrefix))
		.map!(a => a.isDir ? tr(a.name, r"\", "/") ~ '/' : tr(a.name, r"\", "/"));
		//.filter!(a => a.name.baseName.startsWith(filenamePrefix))
		//.map!(a => a.isDir ? buildNormalizedPath(relDirPath, a.name.baseName, "") : a.name);
}

enum getBufferOrReturn = q{
	auto b = app.currentBuffer;
	if (b is null)
		return;
};

string createCmd(string name, string desc)
{
	string res = `cmgr.create("edit.` ~ name ~ `", "Move cursor to beginning of current line", null, delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.` ~ name ~ `();
	});`;
	return res;
}

void register(GUIApplication app)
{
	CommandManager cmgr = app.commandManager;

	// The default emacs key mappings
	cmgr.create("edit.clearBuffer", "Scroll editor window one page down", 
				null,
				delegate(CommandParameter[] data) {
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

	cmgr.create("edit.cursorToCharBefore", "Move cursor to char before cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.cursorLeft(1);
	});

	cmgr.create("edit.cursorToCharAfter", "Move cursor to char after cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.cursorRight(1);
	});

	cmgr.create("edit.cursorToCharAbove", "Move cursor to char before cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.cursorUp(1);
		uint lineNum = ctrl.lineNumber;
		//std.stdio.writeln("key down ", lineNum, " ", ctrl.lineOffset," ", ctrl.visibleLineCount /*, " ", ctrl.buffer.lineCount*/);
		if (lineNum < ctrl.lineOffset)
			ctrl.scrollUp();
	});

	cmgr.create("edit.cursorToCharBelow", "Move cursor to char after cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.cursorDown();
		uint lineNum = ctrl.lineNumber;
		if (lineNum > (ctrl.lineOffset + ctrl.visibleLineCount))
			ctrl.scrollDown();
	});

	cmgr.create("edit.selectToCharBefore", "Select to char before cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.selectLeft(1);
	});

	cmgr.create("edit.selectToCharAfter", "Select to char after cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.selectRight(1);
	});

	cmgr.create("edit.selectToCharAbove", "Select to char before cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.selectUp(1);
		uint lineNum = ctrl.lineNumber;
		//std.stdio.writeln("key down ", lineNum, " ", ctrl.lineOffset," ", ctrl.visibleLineCount /*, " ", ctrl.buffer.lineCount*/);
		if (lineNum < ctrl.lineOffset)
			ctrl.scrollUp();
	});

	cmgr.create("edit.selectToCharBelow", "Select to char after cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		ctrl.selectDown();
		uint lineNum = ctrl.lineNumber;
		if (lineNum > (ctrl.lineOffset + ctrl.visibleLineCount))
			ctrl.scrollDown();
	});

	cmgr.create("edit.selectPageUp", "Select page up from cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		foreach (i; 0 .. ctrl.visibleLineCount)
		{
			ctrl.selectUp();
			// TODO: optimize
			ctrl.scrollUp();
		}
	});

	cmgr.create("edit.selectPageDown", "Select page down from cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;

		if (ctrl.bufferEndOffset == ctrl.length)
		{
			// end of buffer already in view
			foreach (i; 0 .. ctrl.visibleLineCount)
				ctrl.selectDown();
		}
		else
		{
			foreach (i; 0 .. ctrl.visibleLineCount)
			{
				ctrl.selectDown();

				// TODO: optimize
				ctrl.scrollDown();
			}
		}
	});

	cmgr.create("edit.deleteCharBefore", "Delete character before cursor", 
				null,
				delegate(CommandParameter[] data) {	
		mixin(getBufferOrReturn);
		b.remove(-1);
	});

	cmgr.create("edit.deleteCharAfter", "Delete character after cursor", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.remove(1);
	});

	cmgr.create("edit.insert", "Insert a newline at cursor", 
				createParams(""),
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto str = data[0].get!string();
		import std.conv;
		b.insert(to!dstring(str));
	});
	
	cmgr.create("edit.scrollPageDown", "Scroll view one page down", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;

		if (ctrl.bufferEndOffset == ctrl.length)
		{
			// End of buffer already in view.
			// Goto last line
			for (int i = 0; i < ctrl.visibleLineCount; i++)
				ctrl.cursorDown();
		}
		else
		{
			for (int i = 0; i < ctrl.visibleLineCount; i++)
			{
				ctrl.cursorDown();
				ctrl.scrollDown();
			}
		}
	});
	
	cmgr.create("edit.scrollPageUp", "Scroll view one page up", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;

		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	cmgr.create("edit.scrollPagedUp", "Open file", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto ctrl = b;
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{ 
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	
	cmgr.create("edit.cursorToLine", "Move cursor up or down until cursor reaches the line number given as argument", 
				createParams(1),
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto i = data[0].peek!int;
		assert(i !is null);
		b.cursorToLine(*i);

	//    if (i is null)
	//    {
	//        import controls.command;
	//        auto cc = app.guiRoot.activeWindow.userData.get!(GUIApplication.WindowData)().commandControl;
	//        cc.setCommand("edit.cursorToLine ");
	//        cc.show(CommandControl.Mode.oneline);
	//    }
	//    else
	//    {
	////		auto str = data.get!string();
	//        import std.conv;
	//        b.cursorToLine(*i);
	//    }
	});

	cmgr.create("edit.saveBuffer", "Save file", 
				null,
				delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		auto view = b;
    	auto file = std.stdio.File(view.name, "wb");
		view.write(file);
    	file.flush();
    	file.close();
    	std.stdio.writefln("Wrote %s", view.name);
    });

	cmgr.create("edit.save", "Save file", 
				null,
				delegate(CommandParameter[] data) {
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

		this()
		{
			super(createParams(""));
		}

		override void execute(CommandParameter[] data)
		{
			auto path = data[0].get!string;
			app.openFile(path);
		}

		override CompletionEntry[] getCompletions(CommandParameter[] data)
		{
			return std.array.array(filesystemCompletions(data[0].get!string()).map!(a => CompletionEntry(a,a))());
		}
	}

	cmgr.add(new OpenFileCommand);

	class ShowBufferCommand : Command
	{
		override @property string name() const { return "edit.showBuffer"; }
		override @property string description() const { return "Show named buffer in active window"; }

		this()
		{
			super(createParams(""));
		}

		override void execute(CommandParameter[] data)
		{
			auto path = data[0].get!string;
			app.showBuffer(path);
		}
		
		override CompletionEntry[] getCompletions(CommandParameter[] data)
		{
			auto prefix = data[0].get!string();
			auto a = app.getActiveBufferCompletions(prefix);
			
			// If the prefix is empty we know that the active buffer is the first entry. And we don't 
			// want to return that since you never want to activate the current active buffer.
			//if (prefix.empty && app.currentBuffer !is null && !app.currentBuffer.name.empty)
			//    a = a[1..$];

			return a.toCompletionEntries();
		}
	}
	
	cmgr.add(new ShowBufferCommand);

	class IncrementalSearchCommand : Command
	{
		override @property string name() const { return "edit.incrSearch"; }
		override @property string description() const { return "Incremental search active buffer"; }

		struct SearchData
		{
			uint startPos;
			uint lastPos;
		}

		this()
		{
			super(createParams(""));
		}

		override void execute(CommandParameter[] data)
		{
			// If command window is not open the open it with the command in place and no arg
			// else
			// if the command is already running then search for the next item from the end of current selection or
			// cursorPoint in no selection. 
			auto b = app.currentBuffer;
			if (b is null)
				return;
			import std.stdio;
			
			if (b.name == "*CommandInput*")
			{
				writeln("got " ~ data[0].get!string());
			}
			else
			{
				auto cmd = app.commandManager.lookup("app.toggleCommandArea");
				auto args = createArgs("edit.incrSearch ");
				cmd.execute(args);
			}
		}

		override CompletionEntry[] getCompletions(CommandParameter[] data)
		{
			return [data[0].get!string()].toCompletionEntries();
		}
	}

	// cmgr.add(new IncrementalSearchCommand);

	/*
	cmgr.create("edit.commitCompletion", "Commit the active completion", delegate(Variant data) {
		std.stdio.writeln("commit completion");
	});
*/

	import util.build;
	cmgr.create("core.rebuildEditor", "Rebuild the editor and replace the running instance with it", 
				null,
				delegate(CommandParameter[] data) {
//	            	build.buildIt();
	            	// Serialize
	            	// rename build version to xx
	            	// start xx
	            	//    The spawned instance will check if it is called xx then deserialize by piping to the running.exe, and then kill the original ded.exe running
	            	// timeout starting and notify
	            });

	cmgr.create("core.quit", "Quit the application", 
				null,
				delegate(CommandParameter[] data) {
		app.guiRoot.stop();		
		//	            	build.buildIt();
		// Serialize
		// rename build version to xx
		// start xx
		//    The spawned instance will check if it is called xx then deserialize by piping to the running.exe, and then kill the original ded.exe running
		// timeout starting and notify
	});

}
