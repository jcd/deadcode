module gui.textlayout;

import gui.style;
import gui.text;
import math._;
import std.range;

struct TextBoxLayout
{
	TextModel model;
	Rectf rect;
	bool done;
	TextModel.LineBox[] lines;
	private TextModel.LineBox* curLine;
	
	this(TextModel m, Rectf bound)
	{
		done = false;
		model = m;
		rect = bound;
	}
	
	size_t add(Text)(Text text, Style style)
	{
		static int c = 0;
		
		size_t charsUsed = 0;
		float curY = curLine is null ? rect.y : curLine.y;
		if (curY <= (rect.y - rect.h))
		{
			done = true;
			return 0;
		}
		
		if (lines.empty)
		{
			lines ~= TextModel.LineBox();
			curLine = &lines[0];
			curLine.x = rect.x;
			curLine.y = rect.y;
			curLine.w = rect.w;
			curLine.h = 0;
			curLine.renderOffsetX = curLine.x;
		}
		
		while (!text.empty)
		{
			//curLine.rect = Rectf(rect.x, curLine.y, rect.w, curLine.h);
			charsUsed += model.add(*curLine, text, style);
			c++;
			if (curLine.isFull)
			{
				float newY = curLine.y - curLine.h;
				//std.stdio.writeln(newY, " ", rect.y, " ", rect.h);
				if (newY < (rect.y - rect.h))
				{
					done = true;
					return charsUsed;
				}
				lines ~= TextModel.LineBox();
				curLine = &lines[$-1];
				curLine.y = newY;
				curLine.h = 0;
				curLine.w = rect.w;
				curLine.x = rect.x;
				curLine.isFull = false;
				curLine.glyphCount = 0;
				curLine.textBaseLine = float.init;
				curLine.renderOffsetX = rect.x;
			}
		}
		
		return charsUsed;
	}
}
