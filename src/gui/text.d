module gui.text;

import graphics.buffer;
import graphics.color;
import graphics.model;
import graphics.mesh;
import gui.gui;
import gui.resources.font;
import gui.resources.material;
import gui.resources.shaderprogram;
import gui.resources.texture;
import gui.window;
import math._;

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

	Rectf getGlyphPos(uint index)
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
				break;
			}

			if (ch == '\r' || skip)
				continue;

			if (ch == '\t')
			{
				float tabWidth = font.fontWidth * 4;
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
			size_t charsAdded = 0;
			size_t vertsAdded;
			bool lineIsFull = false;
			float maxX;
			Buffer buffer;
			size_t bufferOffset;
			size_t bufferLength;
		}

		auto vertsAdded = vbase - vbaseorig;
		return Result(charsUsed, vertsAdded, isFull, pos.x, mesh.buffers[0], vbaseorig, vbase - vbaseorig);
	}
}

/*
class TextSelectionModel
{
	private
	{
		struct Line 
		{
			NineSplitModel nineSplitModel;	
		}
		NineSplitModel[] nineSplitModels;
	}

	TextModel textModel;
	
	TextSelectionModel(TextModel model)
	{
		textModel = model;
	}
	
	void Update(RegionSet regions, )
	{
		foreach (Region r; regions)
		{
			// A region may span several lines and the linebox info must be probed to find out
			// what part belongs where. Additionally the linebox knows about the layed out line height.
			

			// Begin and end glyph pos will tell us the horizontal ends of the selection box for
			Vec2f beginGlyphPos = model.getGlyphPos(r.a);
			Vec2f endGlyphPos = model.getGlyphPos(r.b-1);


		}
	}
}
*/
