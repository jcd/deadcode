module gui.textlayout;

import graphics.buffer;
import gui.style;
import gui.text;
import math;
import std.algorithm;
import std.range;

struct TextBoxLayout
{
	TextModel model;
	Rectf bounds;
	bool done;

	struct Line
	{
	public:
		Rectf rect;          /// Pixel space rect
		bool isFull;         /// Is this line full of glyphs ie. no space left
		float textBaseLine;  /// The pixel offset of the text base line
		float largestFontHeight; /// Largest font in line
		float renderOffsetX; /// Pixel space offset for rendering next char

	package:
		Region region; // The text region (relative to the text being layed out - not the entire buffer)
	}

	Line[] lines;
	private Line* curLine;

	@property int lineCount()
	{
            return cast(int)lines.length - (curLine !is null && curLine.region.empty ? 1 : 0);
	}

	private
	{
        private import gui.resources.font : Font;

		// One instance of this per line per style used in the line
		struct LineHeightBufferInfo {
			// Info to locate vertices for a line in the model.
			// Used to move the line vertically when glyph size changes across a line
			// being layed out.
			Buffer buffer;       // Verts buffer for the style
			size_t bufferOffset; // Offset into vertex buffer for the line data
			size_t bufferLength; // Length in the buffer to the lines vertice data
		}

		LineHeightBufferInfo[] curLineHeightBufferInfos;

		Font[] _fontsToUpdate; // fontmap that should be updated because they need additional glyphs
		bool _missingGlyphInfo;
	}

	/** Constructor
	Params:
		textModel = The TextModel that this layout will layout into
		bound = The pixelSize bounds
	*/
	this(TextModel textModel, Rectf bounds)
	{
		_missingGlyphInfo = false;
		done = false;
		model = textModel;
		this.bounds = bounds;
	}

	void updateFontMaps()
	{
		if (_fontsToUpdate.empty)
			return;
		foreach (f; _fontsToUpdate)
			f.updateFontMap();
		_fontsToUpdate.length = 0;
		assumeSafeAppend(_fontsToUpdate);
	}

	void _newLine(int startBufferIdx, float yStart)
	{
		lines ~= Line();
		curLine = &lines[$-1];
		curLine.region = Region(startBufferIdx, startBufferIdx);
		curLine.rect.x = bounds.x;
		curLine.rect.y = yStart;
		curLine.rect.w = bounds.w;
		curLine.rect.h = 0; // Init to null and grow when hitting char with larger height
		curLine.renderOffsetX = bounds.x; // offset for rendering next char
		curLine.textBaseLine = float.init;
		curLine.largestFontHeight = 0f;
		curLine.isFull = false;
		curLineHeightBufferInfos.length = 0;
		assumeSafeAppend(curLineHeightBufferInfos);
	}

	size_t add(Text)(Text text, Style style)
	{
		_missingGlyphInfo = false;

		float topOfLineBox = curLine is null ? bounds.y : curLine.rect.y;
		if (topOfLineBox >= bounds.y2)
		{
			// topOfLineBox is under the bounds box
			done = true;
			return 0;
		}

		if (lines.empty)
			_newLine(0, bounds.y); // First line

		size_t charsUsed = 0;
		while (!text.empty)
		{
			//curLine.rect = Rectf(rect.x, curLine.y, rect.w, curLine.h);
			auto charsAdded = addToLine(text, style);
			charsUsed += charsAdded;
			curLine.region.b += charsAdded;

			if (curLine.isFull)
			{
				float topOfNextLineBox = curLine.rect.y + curLine.rect.h;

				//std.stdio.writeln(nextLineTop, " ", rect.y, " ", rect.h);
				if (topOfNextLineBox >= bounds.y2)
				{
					done = true;
					return charsUsed;
				}

				_newLine(curLine.region.b, topOfNextLineBox);
			}
		}

		if (_missingGlyphInfo && !_fontsToUpdate.canFind(style.font))
				_fontsToUpdate ~= style.font;

		return charsUsed;
	}


	/** Draw on this text mesh inside the LineBox using the specified style
	*
	* Params:
	* lineBox = The LineBox specifying where to render glyphs
	* text	= The text and RegionSets for the styles.
	* style = The style to use for rendering the text
	*
	* Returns: number of chars used from the text argument
	*/
	private size_t addToLine(Range)(ref Range text, Style style)
	{
		import std.math;
		if (isNaN(curLine.textBaseLine))
			curLine.textBaseLine = style.font.fontAscent;

		//
		// Modify the line box as needed
		//
		// Make the box have the baseline of the largest font in general
		auto fontAscent = style.font.fontAscent;
		float ascentDiff = curLine.textBaseLine - fontAscent;

		if (curLine.largestFontHeight == 0)
			curLine.largestFontHeight = style.font.fontHeight;

		auto startGlyphPosLen = model.glyphPositions.length;

		if (fontAscent > curLine.textBaseLine)
		{
			// Correct the previous glyph vertices to move them to the new base line
			// TODO: do
			immutable size_t yPosIndex = 1;

			foreach (ref lhi; curLineHeightBufferInfos)
			{
				foreach (i; 0 .. (lhi.bufferLength/3))
					lhi.buffer.data[lhi.bufferOffset + yPosIndex + i*3] += ascentDiff;
			}

			auto heightDiff = style.font.fontHeight - curLine.largestFontHeight;
			foreach (ref p; model.glyphPositions[curLine.region.a..$])
			{
				p.y -= heightDiff;
				p.h += heightDiff;
			}

			// Correct baseline for next glyphs to be plottet
			curLine.textBaseLine = fontAscent;
			curLine.largestFontHeight = style.font.fontHeight;
			ascentDiff = 0;
		}

		// Always expand the linebox according the the heighest line glyph rendered
		curLine.rect.h = std.math.fmax(curLine.rect.h, style.font.fontLineSkip);
		auto relPixPos = style.font.fontLineSkip + ascentDiff;

		// Even though screen space is growing in y going downwards we
		// decrease in y going downwards because we want to map into gl coord space
		auto absPixPos = (-curLine.rect.y) - relPixPos; // style.font.fontLineSkip;

		// This is in pixels sizes and need to be scaled to world size before
		// rendering at some point.
		Vec2f pos = Vec2f(curLine.renderOffsetX, absPixPos);

		Rectf atWorldRect = Rectf(pos, Vec2f(curLine.rect.w, curLine.rect.h));

		auto res = model.addTextVertices!Range(style.background, text, atWorldRect, style.font, style.color, style.wordWrap);

		_missingGlyphInfo = _missingGlyphInfo || res.missingGlyphInfo;

		// Correct glyphPositions for glyphs that have ascendDiff < 0
		if (ascentDiff > 0)
		{
			//auto heightDiff = curLine.largestFontHeight - style.font.fontHeight;
			foreach (ref p; model.glyphPositions[startGlyphPosLen..$])
				p.y -= fontAscent;
		}

		curLine.renderOffsetX = res.maxX;
		curLine.isFull = res.lineIsFull;
		curLineHeightBufferInfos ~= LineHeightBufferInfo(res.buffer, res.bufferOffset, res.bufferLength);
		return res.charsAdded;
	}

}
