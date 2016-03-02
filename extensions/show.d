module extensions.show;

import extensionapi;
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

void showEndOfLIne(Application a, TextEditor e, BufferView b)
{
    //import gui.event;
    //e.setLineAnchor(2, "myanchor")
    // .onMouseClickCallback = (Event e, Widget w) { b.insert("Hello world"); return EventUsed.yes; };

	EOLAnchor.anchorManager.ensureAnchors(e);

}

import controls.texteditor : TextEditorDataAnchorManager, TextEditorDataAnchorWidget, TextEditorAnchorWidget;
import edit.buffer;
import extensions.language.d.analysis.base;

class EOLAnchor : TextEditorDataAnchorWidget!(EOLType)
{
	import gui.label;
	Label label;

    // enum CHARS = [ "\u240A", "\u240D", "\u240A\u240D", "\u240D\u240A", "<LINE SEPARATOR>", "<PARAGRAPH SEPARATOR>" ];
    enum CHARS = [ "<lf>", "<cr>", "<lf+cr>", "<cr+lf>", "<LINE SEPARATOR>", "<PARAGRAPH SEPARATOR>" ];

    static EOLAnchorManager anchorManager;
    static this()
    {
        anchorManager = new typeof(anchorManager);
    }

	override void update()
	{
		super.update();
		if (label is null)
		{
			auto m = anchorData;
			if (!m)
			{
                ubyte idx = cast(ubyte) m;
                assert(idx < 6);
				label = new Label(CHARS[idx]);
				label.parent = this;
			}
		}
	}
}

class EOLAnchorManager : TextEditorDataAnchorManager!EOLAnchor
{
    override TextEditorAnchorWidget createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
    {
		editor.bufferView.onChanged.connectTo((BufferView bv, int index, int count, bool isInsert) {
			// Deleted lines will automatically have their anchors removed.
            // We look for new lines and set anchors in that case
			if (!isInsert)
            {
				// Look for last newline before index and next newline after index+count and
                // ensure anchors for that range.
				EOLAnchor.anchorManager.ensureAnchors(editor, index, index + count);
            }
        });
		return super.createAnchorWidget(anchor, editor);
    }

    void ensureAnchors(TextEditor e, int begin = 0, int end = int.max)
    {
	    import edit.buffer : InvalidIndex;

	    auto buf = e.bufferView.buffer;
		auto bufLen = buf.length;
		end = end == int.max ? bufLen : end;

		int idx = buf.findOneOf(0, "\r\n");

		while (idx != -1 && idx != InvalidIndex && idx < end)
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
	 }
}

