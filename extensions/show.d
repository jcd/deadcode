module extensions.show;

import extensions;
mixin registerCommands;

private enum EOLType : ubyte
{
    lf,   // line feed
    cr,    // carriage return
    lfCR,
    crLF,
    ls,   // line separator
    ps,   // paragraph separator
}

void showEndOfLIne(GUIApplication a, TextEditor e, BufferView b)
{
    //import gui.event;
    //e.setLineAnchor(2, "myanchor")
    // .onMouseClickCallback = (Event e, Widget w) { b.insert("Hello world"); return EventUsed.yes; };

    auto buf = e.bufferView.buffer;
	auto bufLen = buf.length;

	int idx = buf.findOneOf(0, "\r\n");
	while (idx != -1 && idx != InvalidIndex)
	{
		assert(idx >= 0);
		dchar curChar = buf[idx];
		int curLine = buf.lineNumberAt(idx);
		if (idx == bufLen-1)
		{
			EOLAnchor.anchorManager.ensureLineAnchor(e, curLine, curChar == '\r' ? EOLType.cr : EOLType.lf);
		}
		else if (curChar == '\r')
		{
			dchar nextChar = buf[idx+1];
			if (nextChar == '\n')
			{
				EOLAnchor.anchorManager.ensureLineAnchor(e, curLine, EOLType.crLF);
			}
			else
			{
				EOLAnchor.anchorManager.ensureLineAnchor(e, curLine, EOLType.cr);
			}
		}
		else
		{
			dchar nextChar = buf[idx+1];
			if (nextChar == '\r')
			{
				EOLAnchor.anchorManager.ensureLineAnchor(e, curLine, EOLType.lfCR);
			}
			else
			{
				EOLAnchor.anchorManager.ensureLineAnchor(e, curLine, EOLType.lf);
			}
		}
        idx = buf.findOneOf(idx+1, "\r\n");
	}
	import std.conv;
	a.bufferViewManager.create(b.getText().to!string);
	b.insert("Hello");
}

import controls.texteditor;
import extensions.language.d.analysis.base;

class EOLAnchor : ManagedTextEditorAnchor!(EOLType)
{
	import gui.label;
	Label label;

    // enum CHARS = [ "\u240A", "\u240D", "\u240A\u240D", "\u240D\u240A", "<LINE SEPARATOR>", "<PARAGRAPH SEPARATOR>" ];
    enum CHARS = [ "<lf>", "<cr>", "<lf+cr>", "<cr+lf>", "<LINE SEPARATOR>", "<PARAGRAPH SEPARATOR>" ];

    static TextEditorAnchorManager!(EOLType, EOLAnchor) anchorManager;
    static this()
    {
        anchorManager = new typeof(anchorManager);
    }

	override void update()
	{
		super.update();
		if (label is null)
		{
			auto m = getAnchorData();
			if (!m.isNull)
			{
                ubyte idx = cast(ubyte) m.get;
                assert(idx < 6);
				label = new Label(CHARS[idx]);
				label.parent = this;
			}
		}
	}
}

