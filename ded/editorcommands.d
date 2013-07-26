module editorcommands;

import buffer;
import bufferview;
import gui.command;
import gui.widgetfeature;
import std.conv;
import std.variant;

string createCmd(string name, string desc)
{
	string res = `cmgr.create("editor.` ~ name ~ `", "Move cursor to beginning of current line", delegate(Variant data) {
		data.get!(BufferView).` ~ name ~ `();
	});`;
	return res;
}

void register()
{
	// The default emacs key mappings
	auto cmgr = CommandManager.singleton;
	
	cmgr.create("editor.clearBuffer", "Scroll editor window one page down", delegate(Variant data) {
		auto dl = "Hello world I am fine right now"d;
	    data.get!(BufferView).buffer = new TextGapBuffer(dl, 20);
	});

	mixin(createCmd("cursorToBeginningOfLine", "Move cursor to beginning of current line"));
	mixin(createCmd("cursorToEndOfLine", "Move cursor to end of current line"));
	mixin(createCmd("cursorToWordBefore", "Move cursor to word before cursor"));
	mixin(createCmd("cursorToWordAfter", "Move cursor to word after cursor"));
	mixin(createCmd("deleteWordBefore", "Delete word before cursor"));
	mixin(createCmd("deleteWordAfter", "Delete word after cursor"));
	mixin(createCmd("deleteToEndOfLine", "Delete line part after cursor"));
	mixin(createCmd("clear", "Clear buffer"));

	
	cmgr.create("editor.cursorToCharBefore", "Move cursor to char before cursor", delegate(Variant data) {
	            	data.get!(BufferView).cursorLeft(1);
	});

	cmgr.create("editor.cursorToCharAfter", "Move cursor to char after cursor", delegate(Variant data) {
	            	data.get!(BufferView).cursorRight(1);
	});

	cmgr.create("editor.cursorToCharAbove", "Move cursor to char before cursor", delegate(Variant data) {
	    auto ctrl = data.get!(BufferView);
		ctrl.cursorUp(1);
		uint lineNum = ctrl.buffer.lineNumber(ctrl.cursorPoint);
		std.stdio.writeln("key down ", lineNum, " ", ctrl.lineOffset," ", ctrl.visibleLineCount, " ", ctrl.buffer.lineCount);
		if (lineNum < ctrl.lineOffset)
			ctrl.scrollUp();
	});

	cmgr.create("editor.cursorToCharBelow", "Move cursor to char after cursor", delegate(Variant data) {
	    auto ctrl = data.get!(BufferView);
		ctrl.cursorDown();
		uint lineNum = ctrl.buffer.lineNumber(ctrl.cursorPoint);
		if (lineNum > (ctrl.lineOffset + ctrl.visibleLineCount))
			ctrl.scrollDown();
	});

	cmgr.create("editor.deleteCharBefore", "Delete character before cursor", delegate(Variant data) {
	            	data.get!(BufferView).remove(-1);
	});

	cmgr.create("editor.deleteCharAfter", "Delete character after cursor", delegate(Variant data) {
	            	data.get!(BufferView).remove(1);
	});

	cmgr.create("editor.insertNewline", "Insert a newline at cursor", delegate(Variant data) {
	            	data.get!(BufferView).insert('\n');
	});
	
	cmgr.create("editor.scrollPageDown", "Scroll view one page down", delegate(Variant data) {
	            	auto ctrl = data.get!(BufferView);
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{
			ctrl.cursorDown();
			ctrl.scrollDown();
		}
	});
	
	cmgr.create("editor.scrollPageUp", "Scroll view one page up", delegate(Variant data) {
	            	auto ctrl = data.get!(BufferView);
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	cmgr.create("editor.scrollPagedUp", "Open file", delegate(Variant data) {
	            	auto ctrl = data.get!(BufferView);
		for (int i = 0; i < ctrl.visibleLineCount; i++)
		{ 
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	cmgr.create("editor.saveBuffer", "Save file", delegate(Variant data) {
	            	auto view = data.get!(BufferView);
	            	auto file = std.stdio.File(view.name, "wb");
	            	file.rawWrite(std.conv.text(view.buffer.beforeGap));
	            	file.rawWrite(std.conv.text(view.buffer.afterGap));
	            	file.flush();
	            	file.close();
	            	std.stdio.writefln("Wrote %s", view.name);
	            });

	cmgr.create("editor.open", "Open file", delegate(Variant data) {
	            	auto path = data.get!string;
	            	import application;
	            	Application.AddMessage("Opening %s", path);
	            	auto view = Application.bufferViewManager.create("", path);
	            	auto file = std.stdio.File(path, "rb");
	            	view.buffer.gbuffer.ensureGapCapacity(cast(uint)file.size);
	            	auto r = file.byLine!(char,	char)(std.stdio.KeepTerminator.yes, '\x0a');
	            	foreach (line; r)
	            	{
	            		view.buffer.gbuffer.insert(std.conv.dtext(line));
	            	}
	            	Application.AddMessage("Read %s", view.name);
	            	//Application.activeEditor.show(view);
	            });

	import build;
	cmgr.create("core.rebuildEditor", "Rebuild the editor and replace the running instance with it", delegate(Variant data) {
//	            	build.buildIt();
	            	// Serialize
	            	// rename build version to xx
	            	// start xx
	            	//    The spawned instance will check if it is called xx then deserialize by piping to the running.exe, and then kill the original ded.exe running
	            	// timeout starting and notify
	            });
}
