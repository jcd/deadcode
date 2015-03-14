module gui.text;

import graphics.buffer;
import graphics.color;
import graphics.model;
import graphics.mesh;
import gui.gui;
import gui.models;
import gui.resources.font;
import gui.resources.material;
import gui.resources.shaderprogram;
import gui.resources.texture;
import gui.style;
import gui.textlayout;
import gui.window;
import math;

import std.array;
import std.typecons;

/** A TextRenderer that can draw some text that may be decorated
 *
 * It can also be queried for render position of specific text regions or characters
 */
class TextModel
{
	/** LineBox constrains layout of a line of text
	 *
	 * It is can be provided when adding text to the model in order to specify
	 * space available until a new line must enforced ie. because of wrapping or newline chars.
	 */

	Model styleTextModel;
	package Rectf[] glyphPositions; // TODO: This is already stored in the Model!Style ... reuse somehow?

	private
	{
		MaterialManager materialManager;
		SubModel[uint] styleSubModelMap;
	}

	this()
	{
		styleTextModel = new Model();
	}

	// Get the world glyph pos. Glyphs are rendered from 0,0 and downwards ie.
	// y-coord of the first glyph is -lineHeight and height is lineHeight for that line.
	Rectf getGlyphPos(int index)
	{
		if (index >= glyphPositions.length)
		{
			return Rectf(float.nan,float.nan,float.nan,float.nan);
		}
		return glyphPositions[index];
	}

	void resetGlyphPositions()
	{
		glyphPositions.length = 0;
		assumeSafeAppend(glyphPositions);
	}

	void clear()
	{
		foreach (subModel; styleTextModel.subModels)
		{
			subModel.mesh.clear();
		}
	}

	private SubModel GetTextSubModel(Material mat, graphics.texture.Texture fontMap)
	{
		auto key = mat.shader.glProgramID * 1024 + fontMap.glTextureID;
		SubModel * m = key in styleSubModelMap;
		if (m)
			return *m;

		// Create a new text model for this style

		// Text model ie. a mesh with a quad for each letter.
		// A text model is created for each different styles where the material differs
		// because a model can only be drawn with a single material.
		// TODO: do
		// TODO: Clean up unused models
		Buffer vertexBuf = Buffer.create();
		Buffer colorBuf = Buffer.create();
		Buffer vertColBuf = Buffer.create();
		auto textModel = styleTextModel.createSubModel();
		styleSubModelMap[key] = textModel;
		textModel.mesh = Mesh.create();
		textModel.mesh.setBuffer(vertexBuf, 3, 0);
		textModel.mesh.setBuffer(colorBuf, 2, 1);
		textModel.mesh.setBuffer(vertColBuf, 3, 2);
		textModel.blend = true;
		textModel.blendMode = 0;

		textModel.material = mat.manager.declare();
		textModel.material.shader = mat.shader;
		textModel.material.texture = fontMap;
		return textModel;
	}

	void draw(Mat4f transform)
	{
		styleTextModel.draw(Window.active.MVP * transform);
	}

	/** Render a text range into mesh within the bounds of the lineBox using a specific style
	Params:
		mesh = The mesh to put text vertices into
		str = The text to put into the mesh
		inWorldRect = The bounds of where the text should be put in world coordinates
		font = The font to use
		color = The foreground color of the font
		wordWrap = If true the method will return when the inWorldRect overflows horizontally.

		Returns:
			A struct of (usedChars, lineIsFull, maxX)
	*/
	auto addTextVertices(R)(Material material, ref R str, Rectf inWorldRect, Font font, Color color, bool wordWrap)
	{

		SubModel subModel = GetTextSubModel(material, font.fontMap);
		Mesh mesh = subModel.mesh;

		Vec2f pos = inWorldRect.pos;

		assert(!std.math.isNaN(pos.x));
		assert(!std.math.isNaN(pos.y));

		assumeSafeAppend(mesh.buffers[0].data);
		assumeSafeAppend(mesh.buffers[1].data);
		assumeSafeAppend(mesh.buffers[2].data);

        auto verts = &(mesh.buffers[0].data);
		auto uvs = &mesh.buffers[1].data;
		auto cols = &mesh.buffers[2].data;

		size_t vbase = verts.length;
		size_t vbaseorig = vbase;
		size_t uvbase = uvs.length;

		// Make room for new data
		verts.length = vbase + str.length * 18; // 6 verts of 3 floats each = 18
		cols.length = verts.length;
		uvs.length = uvbase + str.length * 12; // 6 verts of 2 floats each = 12

		bool missingGlyphInfo = false;
		bool skip = false;
		bool isFull = false;
		size_t charsUsed = 0;
		for ( ; !str.empty; str.popFront())
		{
			auto ch = str.front;

			// glyphPositions ~= Rectf(pos, Vec2f(0, font.fontLineSkip));
			glyphPositions ~= Rectf(pos, Vec2f(0, inWorldRect.h));
			charsUsed++;

			if (ch == '\n')
			{
				isFull = true;
				str.popFront();
				auto g = font.lookupGlyph(' ');
				float eolWidth = g.advance;
				glyphPositions[$-1].w = eolWidth;
				break;
			}

			if (ch == '\r' || skip)
				continue;

			if (ch == '\t')
			{
				auto g = font.lookupGlyph(' ');
				float tabWidth = g.advance * 4;
				pos.x += tabWidth;
				glyphPositions[$-1].w = tabWidth;
				continue;
			}

			if (ch == ' ')
			{
				float spaceWidth = font.fontWidth;
				auto g = font.lookupGlyph(ch);
				float advance = g.advance;
				pos.x += advance;
				glyphPositions[$-1].w = advance;
				continue;
			}

			if (pos.x >= inWorldRect.x2)
			{
				if (wordWrap)
				{
					isFull = true;
					break;
				}
				else
				{
					skip = true;
					continue;
				}
			}

			//if (pos.y > rect.y2)
			//	{
			//		skip = true; // signal that cursor might be out of visible area
			//		break;
			//	}

			// Lookup glyph in font
			auto g = font.lookupGlyph(ch);
			if (g.empty)
			{
				// Glyph currently not in fontmap and we need to regenerate
				// the fontmap at some point to get it. It not done automatically
				// because we want to bundle fontmap regenerations for many chars at once.
				missingGlyphInfo = true;
				continue;
			}

			assert(!std.math.isNaN(g.offsetRect.x));
			assert(!std.math.isNaN(g.offsetRect.y));
			assert(!std.math.isNaN(g.offsetRect.x2));
			assert(!std.math.isNaN(g.offsetRect.y2));

			auto offsetRect = Rectf(Vec2f(0,0),
			                        g.offsetRect.size);
			Rectf o = offsetRect + pos;

			Rectf c = g.uvRect;

			// TODO: optimize using e.g slices
			(*verts)[vbase..vbase+2] = o.pos.v[];
			//verts[base+0] = o.x;
			//verts[base+1] = o.y;
			(*verts)[vbase+2] = 0f;

			(*verts)[vbase+3] = o.x;
			(*verts)[vbase+4] = o.y2;
			(*verts)[vbase+5] = 0f;

			(*verts)[vbase+6] = o.x2;
			(*verts)[vbase+7] = o.y2;
			(*verts)[vbase+8] = 0f;

			(*verts)[vbase+9] = o.x;
			(*verts)[vbase+10] = o.y;
			(*verts)[vbase+11] = 0f;

			(*verts)[vbase+12] = o.x2;
			(*verts)[vbase+13] = o.y2;
			(*verts)[vbase+14] = 0f;

			(*verts)[vbase+15] = o.x2;
			(*verts)[vbase+16] = o.y;
			(*verts)[vbase+17] = 0f;

			assert(!std.math.isNaN(o.x));
			assert(!std.math.isNaN(o.y));
			assert(!std.math.isNaN(o.x2));
			assert(!std.math.isNaN(o.y2));

			assert(!std.math.isNaN(color.r));
			assert(!std.math.isNaN(color.g));
			assert(!std.math.isNaN(color.b));

			for (int i = 0; i < 6; i++)
			{
				(*cols)[vbase+i*3] = color.r;
				(*cols)[vbase+i*3+1] = color.g;
				(*cols)[vbase+i*3+2] = color.b;
			}


			assert(!std.math.isNaN(c.x));
			assert(!std.math.isNaN(c.y));
			assert(!std.math.isNaN(c.x2));
			assert(!std.math.isNaN(c.y2));

			(*uvs)[uvbase+0] = c.x;
			(*uvs)[uvbase+1] = c.y;

			(*uvs)[uvbase+2] = c.x;
			(*uvs)[uvbase+3] = c.y2;

			(*uvs)[uvbase+4] = c.x2;
			(*uvs)[uvbase+5] = c.y2;

			(*uvs)[uvbase+6] = c.x;
			(*uvs)[uvbase+7] = c.y;

			(*uvs)[uvbase+8] = c.x2;
			(*uvs)[uvbase+9] = c.y2;

			(*uvs)[uvbase+10] = c.x2;
			(*uvs)[uvbase+11] = c.y;

			vbase += 18; // 6 verts * 3 floats = 18
			uvbase += 12;

			float advance = g.advance;
			pos.x += advance;
			glyphPositions[$-1].w = advance;

		}

		verts.length = vbase;
		cols.length = vbase;
		uvs.length = uvbase;

		struct Result
		{
			bool missingGlyphInfo;
			size_t charsAdded = 0;
			size_t vertsAdded;
			bool lineIsFull = false;
			float maxX;
			Buffer buffer;
			size_t bufferOffset;
			size_t bufferLength;
		}

		auto vertsAdded = vbase - vbaseorig;
		return Result(missingGlyphInfo, charsUsed, vertsAdded, isFull, pos.x, mesh.buffers[0], vbaseorig, vbase - vbaseorig);
	}
}

version (TextSelectionModelLives)
{
class TextSelectionModel : Stylable
{
	BoxModel[] models; // Model representing the selected area
	TextBoxLayout textLayout;
	Region selection;
	StyleSheet styleSheet;
    Style style;

	// Stylable interface
	@property
	{
		string name() const pure @safe { return null; }
		ubyte matchStylable(string stylableName) const pure nothrow @safe
		{
			return matchStylableImpl(this, stylableName);
		}

		const(string[]) classes() const pure nothrow @safe { return [ "selection"]; }
		bool hasKeyboardFocus() const pure nothrow @safe { return false; }
		bool isMouseOver() const pure nothrow @safe { return false; }
		bool isMouseDown() const pure nothrow @safe { return false; }
		Stylable parent() pure nothrow @safe  { return null; }
	}

	this(StyleSheet stylesheet, TextBoxLayout layout, Region sel)
	{
		styleSheet = stylesheet;
		textLayout = layout;
		selection = sel;
	}

	void update(int textOffset)
	{
		style = styleSheet.getStyle(this);
        if (style is null)
			return;

		RectfOffset padding = style.padding;
		bool hasVertPadding = padding.vertical != 0f;

		// TODO: support width as well
		CSSScale height = style.height;

		// A region for each selected parts of the lines. Not that only the beginning and ending lines
		// can have regions that are a partial line.
		// TODO: use appender
		struct Line
		{
			Region region;
			float lineHeight;
		}
		Line[] lines;

		// A region may span several lines and the linebox info must be probed to find out
		// what part belongs where. Additionally the linebox knows about the layed out line height.
		Region selRegion = selection;
		selRegion.entriesRemoved(0, textOffset);
		foreach (i, ref line; textLayout.lines)
		{
			if (selRegion.b <= line.region.a)
				break; // line is after selection. No more to model.

			auto chunks = line.region.intersect3(selRegion);

			if (chunks.at.empty)
				continue; // Nothing at this line is selected.

			// Get the begin and end rects for the selection on this line
			lines ~= Line(chunks.at, line.largestFontHeight);

			if (!chunks.after.empty)
				break; // If something is after the intersections it must mean we have reached the selection end
		}

		// Construct the mesh that represents the background of the selection.
		assumeSafeAppend(models);
		models.length = lines.length;

		// TODO: move this into the loop above
		Rectf prevRect;

		RectfOffset borderSize = style.backgroundSpriteBorder;
		Sprite sprite = Sprite(style.backgroundSprite);

		auto solid = Sprite(borderSize.left, borderSize.top, sprite.rect.w - borderSize.horizontal, sprite.rect.h - borderSize.vertical);

		//const float borderSize = 3;

		foreach (i, ref line; lines)
		{
			// Begin and end glyph pos will tell us the horizontal ends of the selection box for
			// The
			Rectf beginGlyphPos = textLayout.model.getGlyphPos(line.region.a);
			Rectf endGlyphPos =  textLayout.model.getGlyphPos(line.region.b-1);

			// Swap y-coords to match coor system
			beginGlyphPos.y = (-beginGlyphPos.y) - beginGlyphPos.h;
			endGlyphPos.y = (-endGlyphPos.y) - endGlyphPos.h;

			BoxModel box = models[i];
			if (box is null)
			{
				box = new BoxModel(0, sprite, RectfOffset(borderSize.left,borderSize.top,borderSize.right,borderSize.bottom));
				//box = new BoxModel(Sprite(Rectf(6,6,4,4)));
				box.color = style.color; //Vec3f(0.25, 0.25, 0.25);
				models[i] = box;
			}
			else
			{
				box.setupDefaultNinePatch(sprite);
				box.color = style.color;
			}

			Vec2f size = Vec2f((endGlyphPos.pos.x + endGlyphPos.size.x) - beginGlyphPos.pos.x, line.lineHeight);

			auto curRect = Rectf(beginGlyphPos.pos, size);

			bool firstLine = i == 0;
			if (!firstLine && !hasVertPadding)
			{
				// Check the previous line rect to figure out how this line top corners should look and
				// prev lines bottom corners should look
				if (curRect.x <= prevRect.x && curRect.x2 >= prevRect.x)
				{
					// The last should have an open bottom left corner

					models[i-1].bottomLeft = solid;
					if (curRect.x2 > prevRect.x2)
					{

					}
					else
					{
						models[i].topRight = solid; // Sprite(6, 6, 4, 4);
					}
				}
				if (curRect.x2 >= prevRect.x2 && curRect.x <= prevRect.x2)
				{
					// The last should have an open bottom left corner
					models[i-1].bottomRight = solid; // Sprite(borderSize, borderSize, 4, 4);
				}
				if (curRect.x == prevRect.x)
				{
					models[i].topLeft = solid; // Sprite(borderSize, borderSize, 4, 4);
				}
			}

			prevRect = curRect;

			// adjust for padding and size
			if (padding.top != 0f)
			{
				curRect.y += padding.top;
				if (curRect.y >= prevRect.y2)
					curRect.y = prevRect.y2;

				if (padding.bottom != 0f)
					curRect.h -= padding.vertical;
				else
					curRect.h -= padding.top;

				if (curRect.y2 < curRect.y)
					curRect.y2 = curRect.y;
			}
			else if (padding.bottom != 0f)
			{
				curRect.h -= padding.bottom;
				if (curRect.y2 < curRect.y)
					curRect.y2 = curRect.y;
			}

			if (padding.left != 0f)
			{
				curRect.x += padding.left;
				if (curRect.x >= prevRect.x2)
					curRect.x = prevRect.x2;

				if (padding.right != 0f)
					curRect.w -= padding.horizontal;
				else
					curRect.w -= padding.left;
				if (curRect.x2 < curRect.x)
					curRect.x2 = curRect.x;
			}
			else if (padding.right != 0f)
			{
				curRect.w -= padding.right;
				if (curRect.x2 < curRect.x)
					curRect.x2 = curRect.x;
			}

			if (height.isValid)
			{
				assert(height.unit == CSSUnit.pixels); // TODO: support other heights as well
				curRect.h = height.value;
			}

			box.rect = curRect;
		}
	}

	void draw(Mat4f transform)
	{
		if (style is null)
			return;

		auto mat = style.background;
		foreach (m; models)
		{
			m.material = mat;
			m.draw(transform);
		}
	}
}
}


class TextHighlighter : Stylable
{
	string[] classNames;
    BoxModel[] models; // Model representing the selected area
	TextBoxLayout textLayout;
	RegionSet regions;
	StyleSheet styleSheet;
    Style style;
	bool mergeBorders;

	// Stylable interface
	@property
	{
		string name() const pure @safe { return null; }
		ubyte matchStylable(string stylableName) const pure nothrow @safe
		{
			return matchStylableImpl(this, stylableName);
		}

		const(string[]) classes() const pure nothrow @safe { return classNames; }
		bool hasKeyboardFocus() const pure nothrow @safe { return false; }
		bool isMouseOver() const pure nothrow @safe { return false; }
		bool isMouseDown() const pure nothrow @safe { return false; }
        bool isVisible() const pure nothrow @safe { return true; }
		Stylable parent() pure nothrow @safe  { return null; }
	}

	this(string className)
	{
		mergeBorders = false;
		regions = new RegionSet();
        classNames ~= className;
	}

	void update(int textOffset, Vec2f containingBoxSize)
	{
		// Construct the mesh that represents the background of the selection.
		assumeSafeAppend(models);
		models.length = 0;

		if (styleSheet is null)
            return;

        style = styleSheet.getStyle(this);
        if (style is null)
			return;

        if (textLayout.lines.empty)
            return;

		RectfOffset padding = style.padding;
		bool hasVertPadding = padding.vertical != 0f;
        float width = style.width.isValid && style.width.unit == CSSUnit.pct ? style.width.value * containingBoxSize.x : -1;

		// TODO: support width as well
		CSSScale height = style.height;

		// A region for each selected parts of the lines. Not that only the beginning and ending lines
		// can have regions that are a partial line.
		// TODO: use appender
		struct Line
		{
			Region region;
			float lineHeight;
		}
		Line[] lines;

		// A region may span several lines and the linebox info must be probed to find out
		// what part belongs where. Additionally the linebox knows about the layed out line height.

        auto regionSetRange = regions[];
        // skip over all initial regions not even in view
        while (!regionSetRange.empty)
        {
            if (regionSetRange.front.b > textOffset)
                break;
            regionSetRange.popFront();
        }

        if (regionSetRange.empty)
            return; // no regions in view

		foreach (i, ref line; textLayout.lines)
		{
            auto lineRegion = line.region;
            lineRegion.entriesInserted(0, textOffset);
			if (regions.lastIndex <= lineRegion.a)
				break; // line is after selection. No more to model.

            auto intersectRange = regionSetRange.intersect(lineRegion);
			foreach (irRegion; intersectRange)
            {
                irRegion.entriesRemoved(0, textOffset);
                lines ~= Line(irRegion, line.largestFontHeight);
            }
		}

		models.length = lines.length;

		// TODO: move this into the loop above
		Rectf prevRect;

		RectfOffset borderSize = style.backgroundSpriteBorder;
		Sprite sprite = Sprite(style.backgroundSprite);

		auto solid = Sprite(borderSize.left, borderSize.top, sprite.rect.w - borderSize.horizontal, sprite.rect.h - borderSize.vertical);

		//const float borderSize = 3;

		foreach (i, ref line; lines)
		{
			// Begin and end glyph pos will tell us the horizontal ends of the selection box for
			// The
			Rectf beginGlyphPos = textLayout.model.getGlyphPos(line.region.a);
			Rectf endGlyphPos =  textLayout.model.getGlyphPos(line.region.b-1);

			// Swap y-coords to match coor system
			beginGlyphPos.y = (-beginGlyphPos.y) - beginGlyphPos.h;
			endGlyphPos.y = (-endGlyphPos.y) - endGlyphPos.h;

			BoxModel box = models[i];
			if (box is null)
			{
				box = new BoxModel(0, sprite, RectfOffset(borderSize.left,borderSize.top,borderSize.right,borderSize.bottom));
				//box = new BoxModel(Sprite(Rectf(6,6,4,4)));
				box.color = style.color; //Vec3f(0.25, 0.25, 0.25);
				models[i] = box;
			}
			else
			{
				box.setupDefaultNinePatch(sprite);
				box.color = style.color;
			}

			Vec2f size = Vec2f((endGlyphPos.pos.x + endGlyphPos.size.x) - beginGlyphPos.pos.x, line.lineHeight);

            auto curRect = Rectf(beginGlyphPos.pos, size);

            if (width > 0)
            {
                curRect.w = width;
                curRect.x = 0f;
            }

			bool firstLine = i == 0;
			if (!firstLine && !hasVertPadding && mergeBorders)
			{
				// Check the previous line rect to figure out how this line top corners should look and
				// prev lines bottom corners should look
				if (curRect.x <= prevRect.x && curRect.x2 >= prevRect.x)
				{
					// The last should have an open bottom left corner

					models[i-1].bottomLeft = solid;
					if (curRect.x2 > prevRect.x2)
					{

					}
					else
					{
						models[i].topRight = solid; // Sprite(6, 6, 4, 4);
					}
				}
				if (curRect.x2 >= prevRect.x2 && curRect.x <= prevRect.x2)
				{
					// The last should have an open bottom left corner
					models[i-1].bottomRight = solid; // Sprite(borderSize, borderSize, 4, 4);
				}
				if (curRect.x == prevRect.x)
				{
					models[i].topLeft = solid; // Sprite(borderSize, borderSize, 4, 4);
				}
			}

			prevRect = curRect;

			// adjust for padding and size
			if (padding.top != 0f)
			{
				curRect.y += padding.top;
				if (curRect.y >= prevRect.y2)
					curRect.y = prevRect.y2;

				if (padding.bottom != 0f)
					curRect.h -= padding.vertical;
				else
					curRect.h -= padding.top;

				if (curRect.y2 < curRect.y)
					curRect.y2 = curRect.y;
			}
			else if (padding.bottom != 0f)
			{
				curRect.h -= padding.bottom;
				if (curRect.y2 < curRect.y)
					curRect.y2 = curRect.y;
			}

			if (padding.left != 0f)
			{
				curRect.x += padding.left;
				if (curRect.x >= prevRect.x2)
					curRect.x = prevRect.x2;

				if (padding.right != 0f)
					curRect.w -= padding.horizontal;
				else
					curRect.w -= padding.left;
				if (curRect.x2 < curRect.x)
					curRect.x2 = curRect.x;
			}
			else if (padding.right != 0f)
			{
				curRect.w -= padding.right;
				if (curRect.x2 < curRect.x)
					curRect.x2 = curRect.x;
			}

			if (height.isValid)
			{
				assert(height.unit == CSSUnit.pixels); // TODO: support other heights as well
				curRect.h = height.value;
			}

			box.rect = curRect;
		}
	}

	void draw(Mat4f transform)
	{
		if (style is null)
			return;

		auto mat = style.background;
		foreach (m; models)
		{
			m.material = mat;
			m.draw(transform);
		}
	}
}
