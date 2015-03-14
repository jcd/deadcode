module extensions.language.d.commands;

import extensions;
import extensions.language.d;
mixin registerCommands;

import std.typecons;
import extensions.language.d.analysis.base;

@MenuItem("Edit/foo")
void dlangInsertModuleName(BufferView v)
{
DCodeModel dCodeModel(BufferView bv)
{
	return cast(DCodeModel)(bv.codeModel);
}
	import std.conv;
	DCodeModel m = dCodeModel(v);
	if (m is null)
		return;
	v.insert(m.getSuggestedPath().to!dstring);
}

void dCheckIfElse(TextEditor editor)
{
	BufferView v = editor.bufferView;

    import extensions.language.d.analysis.ifelsesame;
	import extensions.language.d.analysis.comma_expression;

	DCodeModel dCodeModel(BufferView bv)
	{
		return cast(DCodeModel)(bv.codeModel);
	}

	import std.stdio;
	DCodeModel m = dCodeModel(v);
	if (m is null)
		return;
	m.updateAST();

	auto c1 = new IfElseSameCheck(v.name);
	m.accept(c1);
//	Analysis.the.setMessages(v, c1.messages);
    foreach (msg; c1.messages)
    {
        anchorManager.ensureLineAnchor(editor, msg.line - 1, msg);
        writeln(msg.key, " ", msg.message);
    }

	auto c2 = new CommaExpressionCheck(v.name);
	m.accept(c2);
	//Analysis.the.setMessages(v, c2.messages);

    foreach (msg; c2.messages)
    {
        anchorManager.ensureLineAnchor(editor, msg.line - 1, msg);
        writeln(msg.key, " ", msg.message);
    }
	// Analysis.the.setMessages(v, c.messages);
}

unittest
{
	int a = 3;
	if (true)
		a = 4;
	else
		a = 4;
	a++, a++;
}


void dFormatBuffer(BufferView b)
{
    static import extensions.language.d.dfmt;
    import std.conv;
    // extensions.language.d.dfmt.format(string source_desc, ubyte[] buffer, Output output);
    char[] buf = b.getText().to!(char[]);
    b.clear();
    struct Writer
    {
        BufferView bv;
        void put(string s)
        {
	    bv.append(s);
        }
    }
    auto writer = Writer(b);
    extensions.language.d.dfmt.format!Writer(b.name, cast(ubyte[]) buf, writer);

}



//class AnalysisAnchor2 : TextEditorAnchor
//{
//    import gui.label;
//    Label label;
//    int anchorID;
//    this(int anchorID, TextEditor ed)
//    {
//        this.anchorID = anchorID;
//        editor = ed;
//    }
//
//    override void update()
//    {
//        super.update();
//        if (label is null)
//        {
//            auto m = Analysis.the.getMessage(anchorID);
//            if (m.message.length)
//            {
//                label = new Label(m.message);
//                label.parent = this;
//            }
//        }
//    }
//}





/+
/**
Tools and GUI for the builtin dlang unittests
*/
class Analysis : BasicExtension!Analysis // , TextEditorAnchorOwner
{
	import core.buffer;
	override @property string name() { return "D Language Analysis"; }

   TextEditorAnchorManager!(Message, AnalysisAnchor) anchorManager;

    //TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
    //{
    //    return new AnalysisAnchor(anchor.id);
    //}

	static Analysis the;

    //Message[int] _anchorMessages;

	void setMessages(BufferView bv, Message[] msgs)
	{
		foreach (m; msgs)
		{
			auto anchor = bv.buffer.ensureLineAnchor(m.line - 1, this);
			_anchorMessages[anchor.id] = m;
		}
	}

    //Message getMessage(int anchorID) const pure nothrow @safe
    //{
    //    if (auto m = anchorID in _anchorMessages)
    //        return *m;
    //    else
    //        return Message();
    //}

	override void init()
	{
		the = this;
		//import core.runtime;
		//
		//app.bufferViewManager.onBufferViewCreated.connect(&onBufferViewCreated);
		//foreach (bv; app.bufferViewManager.buffers)
		//    onBufferViewCreated(bv);
	}

	//private void onBufferViewCreated(BufferView bv)
	//{
	//    // TODO: maybe make a single onLinesChanged that can be used instead of the two below
	//    bv.buffer.lbuffer.onLineModified.connect(&onLineModified);
	//    bv.buffer.lbuffer.onLinesInserted.connect(&onLinesInserted);
	//}

	// Next three handler is in charge of detecting unittest lines and adding/removing anchors
	// for them.
	//void onLineModified(int lineNumber)
	//{
	//    auto editor = currentTextEditor;
	//    auto line = editor.bufferView.buffer.lineString(lineNumber);
	//
	//    if (line.startsWith("unittest"))
	//    {
	//        editor.bufferView.buffer.ensureLineAnchor(lineNumber, this);
	//    }
	//    else
	//    {
	//        editor.bufferView.buffer.removeLineAnchorByLine(lineNumber, this);
	//    }
	//}
	//
	//void onLinesInserted(int lineNumber, int lineCount)
	//{
	//    foreach (i; lineNumber..lineNumber+lineCount)
	//        onLineModified(i);
	//}
}
+/
