module gui.text;

import graphics._;
import gui.style;
import gui.window;
import math._;

// Move cursorpoint/prefcolumn to TextView
// Remove widget dep and just provide a rect and style
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
	struct LineBox
	{
	public:
		Rectf rect;           /// World space rect
		alias rect this;
		bool allowWrap;      /// Flag that wrapping is a allowed and text is not clipped
		bool allowWordBreak; /// Flag that breaking words are allowed
		bool isFull;         /// 
		float textBaseLine;  /// The world offset of the text base line  
		size_t glyphCount;   /// The number of glyphs currently rendered by this box
	package:
		float renderOffsetX; /// World space offset for rendering
	}
	
	private
	{
		Model styleTextModel;
		SubModel[Style] styleSubModelMap;
		
		Rectf[] glyphPositions; // TODO: This is already stored in the Model!Style ... reuse somehow? 
		
		struct LineHeightInfo
		{
			Buffer buf;
			size_t offset;
			size_t length;
		}
		
		LineHeightInfo[] _lineHeightInfo;
	}
	
	Rectf getGlyphWorldPos(uint index)
	{
		if (index >= glyphPositions.length)
		{
			std.stdio.writeln("Out of bounds ", index , " max is ", glyphPositions.length);
			return Rectf(0,0,0,0);
		}
		return glyphPositions[index];
	}
	
	void resetGlyphPositions()
	{
		glyphPositions.length = 0;
		assumeSafeAppend(glyphPositions);
	}

	this()
	{
		styleTextModel = new Model();	
	}
	
	void clear()
	{
		foreach (subModel; styleTextModel.subModels)
		{
			subModel.mesh.clear();
		}
	}
	
	private SubModel GetTextSubModelForStyle(Style style)
	{
		SubModel * m = style in styleSubModelMap;
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
		styleSubModelMap[style] = textModel;
		textModel.mesh = Mesh.create();
		textModel.mesh.setBuffer(vertexBuf, 3, 0);
		textModel.mesh.setBuffer(colorBuf, 2, 1);	
		textModel.mesh.setBuffer(vertColBuf, 3, 2);	
		textModel.blend = true;
		
		Material mat = new Material();
		mat.shader = Material.builtIn.shader;
		textModel.material = mat;
		return textModel;
	}

	/** Draw text into a rect and style text using regions
	 * 
	 * Text Regions with no style is not modelled at all.
	 * 
	 * Params:
	 * text	= The text and RegionSets for the styles. 
	 * regionToModel = The offset into the text range where the first char of the offset will be located
	 *                 to the upper left in the rect as the first char of the first line.
	 * size = The size of the rendering area in world coordinates 
	 * 
	 * Returns: number of chars used from the text argument
	 */ 
	size_t add(Text)(ref LineBox lineBox, ref Text text, Style style)
	{
		SubModel subModel = GetTextSubModelForStyle(style);
		subModel.material.texture = style.font.fontMap;
		
		//
		// Modify the line box as needed
		//
		// Make the box have the baseline of the largest font in general
		auto fontAscent = Window.active.pixelHeightToWorld(style.font.fontAscent);
		if (std.math.isNaN(lineBox.textBaseLine))
		{
			lineBox.textBaseLine = fontAscent;
			if (std.math.isNaN(lineBox.renderOffsetX))
				lineBox.renderOffsetX = 0f;
			lineBox.glyphCount = 0;
			_lineHeightInfo.length = 0;
			assumeSafeAppend(_lineHeightInfo);
		}
		else if (fontAscent > lineBox.textBaseLine)
		{
			// Correct the previous glyph vertices to move them to the new base line
			// TODO: do
			float diff = lineBox.textBaseLine - fontAscent;
			foreach (ref lhi; _lineHeightInfo)
			{
				foreach (i; 0 .. (lhi.length/3))
					lhi.buf.data[lhi.offset+1+i*3] += diff;
			}
			
			lineBox.textBaseLine = fontAscent;
		}
		
		lineBox.h = std.math.fmax(lineBox.h, Window.active.pixelHeightToWorld(style.font.fontLineSkip)); 
		
		return addStringToMesh(subModel.mesh, text, lineBox, style);
	}

	void draw(Mat4f transform)
	{
		styleTextModel.draw(Window.active.MVP * transform);
	}

	/** Render a text range as into a text model
		Returns: The new offset where to append astring after the just added string
	 */
	size_t addStringToMesh(R)(Mesh mesh, ref R str, ref LineBox lineBox, Style style)
		// Vec2f setTextMesh(R)(Model textModel, R str, Heap toks, Font font, Mesh target, Rectf box, size_t charOfInterest, Vec2f charAtCoords, bool wrap = true)
	{
		// TODO: do handling of base line in order to do changing font sizes etc.
		//       also: the line below will offset line height on each call this method! not correct!
		Font font = style.font;
		
		float worldAscent = Window.active.pixelHeightToWorld(font.fontAscent);
		auto posY = Window.active.pixelHeightToWorld(font.fontLineSkip) + (lineBox.textBaseLine - worldAscent);
		
		Vec2f pos = Vec2f(lineBox.renderOffsetX, lineBox.y - posY);
		
		// Vec2f offset, Rectf rect, 
		
		assert(!std.math.isNaN(pos.x));
		assert(!std.math.isNaN(pos.y));
		
		// std.stdio.writeln(pos.v, " ", rect.pos.v, " ", rect.size.v);
		auto color = style.color;
		
		auto lhi = LineHeightInfo(mesh.buffers[0], mesh.buffers[0].data.length);
		
		auto verts = &(mesh.buffers[0].data);
		auto uvs = &mesh.buffers[1].data;
		auto cols = &mesh.buffers[2].data;
		
		size_t vbase = verts.length;
		size_t uvbase = uvs.length;
		
		// Make room for new data
		verts.length = vbase + str.length * 18; // 6 verts of 3 floats each = 18
		cols.length = verts.length;
		uvs.length = uvbase + str.length * 12; // 6 verts of 2 floats each = 12
		
		
		//verts.length = str.length * 18; // 6 vertices
		//cols.length = str.length * 18; // 6 vertices
		//uvs.length = str.length * 12;   // 6 uvs
		
		bool skip = false;
		size_t charsUsed = 0;
		for ( ; !str.empty; str.popFront())
		{
			auto ch = str.front;
			//foreach (ch; str)
			//{			
			float worldHeight = Window.active.pixelHeightToWorld(font.fontLineSkip);
			glyphPositions ~= Rectf(pos, Vec2f(0, worldHeight));
			charsUsed++;
			
			if (ch == '\n')
			{
				lineBox.isFull = true;
				str.popFront();
				break;
				//				skip = false;
				//				pos.x = rect.x;
				//				pos.y -= Window.active.pixelHeightToWorld(font.fontLineSkip);
				//				continue;
			}
			
			if (ch == '\r' || skip)
				continue;
			
			if (ch == '\t')
			{
				float tabWidth = Window.active.pixelWidthToWorld(font.fontWidth) * 4;
				pos.x += tabWidth;
				glyphPositions[$-1].w = tabWidth; 
				continue;
			}
			
			if (ch == ' ')
			{
				float spaceWidth = Window.active.pixelWidthToWorld(font.fontWidth); 
				pos.x += spaceWidth;
				glyphPositions[$-1].w = spaceWidth;
				continue;
			}
			
			if (pos.x >= lineBox.x2)
			{
				if (style.wordWrap)
				{
					//pos.x = rect.x;
					//pos.y -= Window.active.pixelHeightToWorld(font.fontLineSkip);
					lineBox.isFull = true;
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
			
			assert(!std.math.isNaN(g.offsetRect.x));
			assert(!std.math.isNaN(g.offsetRect.y));
			assert(!std.math.isNaN(g.offsetRect.x2));
			assert(!std.math.isNaN(g.offsetRect.y2));
			
			//			auto offsetRect = Rectf(Window.active.pixelSizeToWorld(g.offsetRect.pos), 
			//Window.active.pixelSizeToWorld(g.offsetRect.size));
			auto offsetRect = Rectf(Window.active.pixelSizeToWorld(Vec2f(0,0)), 
			                        Window.active.pixelSizeToWorld(g.offsetRect.size));
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
			
			float advance = Window.active.pixelWidthToWorld(g.advance);
			pos.x += advance;
			glyphPositions[$-1].w = advance;
			lineBox.glyphCount++;
			
			//pos += Vec2f(0.3f);
		}
		
		verts.length = vbase;
		cols.length = vbase;
		uvs.length = uvbase;
		
		lhi.length = vbase - lhi.offset;
		
		_lineHeightInfo ~= lhi;

		lineBox.renderOffsetX = pos.x;
		return charsUsed;
	}
	
}
