module editorcommands;

import command;
import editor;
import text;

import std.variant;

string createCmd(string name, string desc)
{
	string res = `cmgr.create("editor.` ~ name ~ `", "Move cursor to beginning of current line", delegate(Variant data) {
		EditorController.current.` ~ name ~ `();
	});`;
	return res;
}

void register()
{
	// The default emacs key mappings
	auto cmgr = CommandManager.singleton;
	
	cmgr.create("editor.clearBuffer", "Scroll editor window one page down", delegate(Variant data) {
		auto dl = "Hello world I am fine right now"d;
		EditorController.current.buffer = new TextGapBuffer(dl, 20);
		EditorController.current.view.buffer = EditorController.current.buffer; // TODO: fix
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
		EditorController.current.cursorLeft(1);
	});

	cmgr.create("editor.cursorToCharAfter", "Move cursor to char after cursor", delegate(Variant data) {
		EditorController.current.cursorRight(1);
	});

	cmgr.create("editor.cursorToCharAbove", "Move cursor to char before cursor", delegate(Variant data) {
		auto ctrl = EditorController.current;
		ctrl.cursorUp(1);
		uint lineNum = ctrl.buffer.lineNumber(ctrl.view.cursorPoint);
		if (lineNum < ctrl.view.lineOffset)
			ctrl.scrollUp();
	});

	cmgr.create("editor.cursorToCharBelow", "Move cursor to char after cursor", delegate(Variant data) {
		auto ctrl = EditorController.current;
		ctrl.cursorDown();
		uint lineNum = ctrl.buffer.lineNumber(ctrl.view.cursorPoint);
		if (lineNum > (ctrl.view.lineOffset + ctrl.view.rectLines))
			ctrl.scrollDown();
	});

	cmgr.create("editor.deleteCharBefore", "Delete character before cursor", delegate(Variant data) {
		EditorController.current.remove(-1);
	});

	cmgr.create("editor.deleteCharAfter", "Delete character after cursor", delegate(Variant data) {
		EditorController.current.remove(1);
	});

	cmgr.create("editor.insertNewline", "Insert a newline at cursor", delegate(Variant data) {
		EditorController.current.insert('\n');
	});
	
	cmgr.create("editor.scrollPageDown", "Scroll view one page down", delegate(Variant data) {
		auto ctrl = EditorController.current;
		for (int i = 0; i < ctrl.view.rectLines; i++)
		{
			ctrl.cursorDown();
			ctrl.scrollDown();
		}
	});
	
	cmgr.create("editor.scrollPageUp", "Scroll view one page up", delegate(Variant data) {
		auto ctrl = EditorController.current;
		for (int i = 0; i < ctrl.view.rectLines; i++)
		{
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

	cmgr.create("editor.scrollPagedUp", "Open file", delegate(Variant data) {
		auto ctrl = EditorController.current;
		for (int i = 0; i < ctrl.view.rectLines; i++)
		{
			ctrl.cursorUp();
			ctrl.scrollUp();
		}
	});

}
