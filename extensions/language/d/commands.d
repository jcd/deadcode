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
	v.insert(m.getSuggestedPath());
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
        anchorManager.ensureLineAnchor(editor, cast(int)msg.line - 1, msg);
        //writeln(msg.key, " ", msg.message);
    }

	auto c2 = new CommaExpressionCheck(v.name);
	m.accept(c2);
	//Analysis.the.setMessages(v, c2.messages);

    foreach (msg; c2.messages)
    {
        anchorManager.ensureLineAnchor(editor, cast(int)msg.line - 1, msg);
        //writeln(msg.key, " ", msg.message);
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


void dFormat(BufferView b)
{
    static import extensions.language.d.dfmt;
    import std.conv;
    // extensions.language.d.dfmt.format(string source_desc, ubyte[] buffer, Output output);

    auto r = b.getRegion(RegionQuery.selection);
	bool formatEntireBuffer = r.empty;
	if (formatEntireBuffer)
	{
		r.a = 0;
		r.b = int.max;
	}
	else
	{
		r = r.normalized();
		r.a = b.buffer.offsetToBeginningOfLine(r.a);
		r.b = b.buffer.offsetToEndOfLine(r.b);
	}

    char[] buf = b.getText(r).to!(char[]);

    extensions.language.d.dfmt.FormatterConfig cfg = {
	indentSize : 4,
	useTabs : false,
	tabSize : 4,
	columnSoftLimit: 80,
	columnHardLimit: 120,
	braceStyle: extensions.language.d.dfmt.BraceStyle.allman
    };

	if (formatEntireBuffer)
	{
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
		extensions.language.d.dfmt.format!Writer(b.name, cast(ubyte[]) buf, writer, &cfg);
	}
	else
	{
		import std.array;
		import std.conv;
		auto result = appender!string();
	    extensions.language.d.dfmt.format(b.name, cast(ubyte[]) buf, result, &cfg);
		b.replace(result.data, r);
	}
}


private string getIndentStringForLineAtIndex(BufferView bv, int index)
{
    import std.range;
    import core.buffer;

    int tabSize = 4;
    int indentSize = 4;
    bool useTabs = false;

    int startOfLine = bv.buffer.offsetToBeginningOfLine(index);
    int firstNonSpace = bv.buffer.offsetBy(startOfLine, 1,
										   TextBoundary.lineEnd | TextBoundary.wordBegin | TextBoundary.punctuationBegin,
	                                       TextBoundaryStrength.hard);

    if (firstNonSpace != InvalidIndex)
    {
        int spaces = 0;
        int tabs = 0;
        foreach (c; bv[startOfLine..firstNonSpace])
        {
            if (c == ' ')
                spaces++;
            else if (c == '\t')
                tabs++;
        }

        int lastIndent = (tabs * tabSize + spaces) / indentSize;

        if (useTabs)
           return "\t".repeat(lastIndent * indentSize / tabSize).join;
        else
           return " ".repeat(lastIndent * indentSize).join;
    }
	return "";
}

void dInsertNewline(BufferView bv)
{
    import std.array;
    import std.range;
    import core.buffer;

    bv.insert('\n');

	bool isElse = bv.isCursorFollowing("else\n");

    // indent equal to indent level of previous line unless previous line ends with a { then add an extra indent.
    int p = bv.buffer.prev(bv.cursorPoint);
	string indentStr = getIndentStringForLineAtIndex(bv, p);
	bv.insert(indentStr);

	if (isElse)
    {
		dInsertScopeBegin(bv);
    }
}

void dInsertScopeBegin(BufferView bv)
{
    import std.array;
    import std.range;
    import core.buffer;

    int tabSize = 4;
    int indentSize = 4;
    bool useTabs = false;

    bv.insert('{');
    string indentStr = getIndentStringForLineAtIndex(bv, bv.cursorPoint);
	bv.insert('\n');
    bv.insert(indentStr);
    if (useTabs)
	    bv.insert("ffff");
    else
	    bv.insert(" ".repeat(indentSize).join);
	int cp = bv.cursorPoint;
    bv.insert("\n");
    bv.insert(indentStr);
    bv.insert("}");
    bv.cursorPoint(cp);
}


version (OFF):
class DAutoFormat : Extension
{
	override @property string name() { return "unittests"; }

	override void init()
	{
		import core.runtime;

		app.bufferViewManager.onBufferViewCreated.connect(&onBufferViewCreated);
		foreach (bv; app.bufferViewManager.buffers)
			onBufferViewCreated(bv);
	}

	private void onBufferViewCreated(BufferView bv)
	{
		// TODO: maybe make a single onLinesChanged that can be used instead of the two below
		bv.onInsert.connect(&textInserted);
	}

	private void textInserted(BufferView bv, string txt, int index)
	{
		import std.array;
		import std.range;
		import core.buffer;

		int tabSize = 4;
		int indentSize = 4;
		bool useTabs = false;

		if (txt.length && txt[$-1] == '\n' && bv.cursorPoint == (index + txt.length))
		{
			// indent equal to indent level of previous line unless previous line ends with a { then add an extra indent.
			int startOfPrevLine = bv.buffer.offsetToBeginningOfLine(bv.buffer.endOfPreviousLine(bv.cursorPoint));
			int firstNonSpace = bv.buffer.offsetBy(startOfPrevLine, 1, TextBoundary.lineEnd | TextBoundary.wordBegin | TextBoundary.punctuationBegin,  TextBoundaryStrength.hard);
			if (firstNonSpace != InvalidIndex)
			{
				int spaces = 0;
				int tabs = 0;
				foreach (c; bv[startOfPrevLine..firstNonSpace])
				{
					if (c == ' ')
						spaces++;
					else if (c == '\t')
						tabs++;
				}

				int lastIndent = (tabs * tabSize + spaces) / indentSize;

				if (useTabs)
					bv.insert("\t".repeat(lastIndent * indentSize / tabSize).join);
				else
					bv.insert(" ".repeat(lastIndent * indentSize).join);
			}
		}
	}
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
