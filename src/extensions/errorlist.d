module extensions.errorlist;

import extension;

import gui.event;
import gui.widgetfeature.constraintlayout;
import gui.widgetfeature.ninegridrenderer;
import gui.widgetfeature.textrenderer;
import gui.styledtext;
import gui.style;
import math.rect;
import math.region;
import math.smallvector;
import std.conv;
import std.regex;

class ErrorListWidget : BasicWidget!ErrorListWidget
{
	static WidgetID widgetID;
	
	private TextRenderer!BufferView textRenderer;

	private int lines = 0;
	private int preferredEmptyBottomLines = 1;

	void append(string msg)
	{
		import std.conv;
		textRenderer.text.insert(to!dstring(msg ~ "\n"));
		lines++;
		if ((textRenderer.text.visibleLineCount - preferredEmptyBottomLines) < lines)
			textRenderer.text.bufferOffset = 
				textRenderer.text.buffer.startOfNextLine(textRenderer.text.bufferOffset);
	}

	void clear()
	{
		textRenderer.text.clear();
		textRenderer.text.bufferOffset = 0;
		lines = 0;
	}

	override void init()
	{
		name = "errorlist";
		auto n = new NineGridRenderer("box");
		n.color = Vec3f(0.25, 0.25, 0.25);
		features ~= n;

		auto v = app.bufferViewManager.create("Build messages");

		auto textStyler = new ErrorListStyler!BufferView(v);
		textRenderer = new TextRenderer!BufferView(textStyler);
		features ~= textRenderer;

		// textRenderer = content(this, v);
		// size = Vec2f(-1, 200);
		size = Vec2f(10, 200);
		alignToWindow(this, Anchor.BottomRight, rect.size);
		acceptsKeyboardFocus = true;
		lines = 0;
		// TODO: Remove line below to enable errorlist
		visible = false;
	}
	
	override EventUsed onMouseScroll(Event event)
	{
		// Scroll view
		int d = cast(int) event.scroll.y;
		if (d < 0)
		{
			foreach (i; 0..d*d)
				textRenderer.text.scrollDown();
		}
		else
		{
			foreach (i; 0..d*d)
				textRenderer.text.scrollUp();
		}
		return EventUsed.yes;
	}

	override EventUsed onMouseDoubleClick(Event event)
	{
		auto info = textRenderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
		{
			auto buf = textRenderer.text.buffer;
			auto line = buf.lineContaining(info.index);
			
			import std.regex;		
			auto ctr = regex(ErrorListStyler!BufferView.errorLineRe, "mg");
			auto m = match(line, ctr);
			import std.stdio;
			if (!m.captures.empty)
			{
				writeln(m.captures[2]);
				BufferView bv = app.openFile(to!string(m.captures[1]));
				uint errorLine = to!uint(m.captures[2][1..$-1]) - 1; // lines are 0 indexed in buffer but 1 indexed in error message
				uint errorStartOfLineIndex = bv.buffer.startAtLineNumber(errorLine);
				bv.cursorPoint = errorStartOfLineIndex;
				bv.bufferOffset = errorStartOfLineIndex;
			}

			//uint lineNum = textRenderer.text.buffer.lineNumber(info.index);
			// uint offsetLineNum = textRenderer.text.buffer.lineNumber(textRenderer.text.bufferOffset);
			writeln(line);
		}
		return EventUsed.yes;
	}

	override void update()
	{
		super.update();
		import std.stdio;
		//writeln("update");
	}

	override void draw()
	{
		super.draw();
		import std.stdio;
		//writeln("draw");
	}
}


class ErrorListStyler(Text) : TextStyler!Text
{
	enum defaultID = 0;
	enum declarationID = 1;
	enum typeID = 2;

	enum errorLineRe = "(.*?)(\\(\\d+\\)): (Error.*)"d;
	
	this(Text text)
	{
		super(text);
	}

	override void update()
	{
		regionSet.clear();

		import std.array;
		auto buf = array(text[0..text.length]);

		size_t lastEndIdx = 0;

		import std.regex;		
		auto ctr = regex(errorLineRe, "mg");

		foreach (m; match(buf, ctr))
		{
			if (m.empty)
				continue;
			auto begin = m.pre.length;

			auto filePath = m.captures[1];
			auto end = begin + filePath.length;
			if (begin != lastEndIdx)
				regionSet.merge(lastEndIdx, begin, 0);
			regionSet.merge(begin, end, declarationID);			

			auto lineInFile = m.captures[2];
			begin = end;
			end = begin + lineInFile.length;
			regionSet.merge(begin, end, typeID);			

			auto errorMessage = m.captures[3];
			begin = end + 1;
			end = begin + errorMessage.length;
			regionSet.merge(begin, end, 0);
			lastEndIdx = end;
		}

		if (lastEndIdx != text.length)
			regionSet.merge(lastEndIdx, text.length, 0);

		onChanged.emit();
	}
}
