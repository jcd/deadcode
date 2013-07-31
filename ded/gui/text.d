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
		
		//StyledText!Text styledText;
		Rectf[] glyphPositions; // TODO: This is already stored in the Model!Style ... reuse somehow? 
		
		struct LineHeightInfo
		{
			Buffer buf;
			size_t offset;
			size_t length;
		}
		
		LineHeightInfo[] _lineHeightInfo;
		
		//Vec2f renderOffset;
		//Rectf _renderArea;
		//Model textModel;
		//Model cursorModel;
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
	
	/*	
	@property Rectf renderArea()
	{
		return _renderArea;
	}

	@property void renderArea(Rectf rect)
	{
		_renderArea = rect;
		renderOffset = rect.pos;
	}
*/
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
	
	// also accept the buffer and the regions of interest to style
	//	void onDraw(ref Widget widget, TextGapBuffer (or bufferHaveSomeFeatures) buffer, RegionSetStyles, RegionSet getInfoAbout)
	
	
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
		//size_t sz = regionSet.b - regionSet.a;
		//if (sz == 0) return;
		
		//if (glyphPositions.length < sz)
		//	    glyphPositions.length = sz;
		
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
		
		/*t
		foreach (style, regionSet; styledText.styledRegionSets)
		{
			if (regionSet.empty)
			{
				// TODO: remove style from model if exists
				continue;
			}

			Model!Style.SubModel subModel = GetTextSubModelForStyle(style);
			subModel.material.texture = style.font.fontMap;
			
			// POI should be regions
			setTextMesh(subModel.mesh, styledText.text.buffer[regionToModel.a..regionToModel.b], regionSet, renderArea, style);
		}
		*/
		//		Style defaultStyle = StyleSet.base[""]; // hack. Get it some other way
		
		/*		
		import std.algorithm;
		
		// Calc the max number of lines to render based on the smallest font used for
		// rendering any of this text
		uint minFontHeightPx = reduce!min(defaultStyle.font.fontHeight, regions.map!("a.font.fontHeight")());
		float minFontHeightWorldCoord = Window.active.pixelHeightToWorld(minFontHeight);
		float maxLinesToRender = size.y / minFontHeightWorldCoord;

		// Figure out the regions of the text range the is going to be rendered by reading newlines until
		// maxLinesToRender is reached 
		
		auto range = regions.intersectRange(
		
		// Render each style as a separate model because they may use different materials 
		foreach (styleName, regionSet; regionStyleNames)
		{
			if (regionSet.contains
		}
		*/
		/*
		// Get the first region in the regions that contains a char with index greate or equal to textOffset
		// The result range is lazy
		RegionSet regionsRemaining = regions.intersect(Region(textOffset, uint.max));

		// Accumulate regions to be default styled
		RegionSet defaultStyleRegions = new RegionSet();
		bool firstIteration = true;
		uint lastIdx = textOffset; // lastIdx is the first char that is not styled (e.g. right after a styled span)
		
		RegionSet[Style] styledRegionSets;
		
		foreach (currentRegion; regionsRemaining)
		{						
			// On first iteration we run through all regions and therefore can
			// create new regions chars that is not style by any region and then put
			// them to defaultStyleRegions for later processing.
			if (firstIteration)
			{
				if (lastIdx < currentRegion.a)
				{
					auto r = Region(lastIdx, currentRegion.a);
					r.data = defaultStyle;
					defaultStyleRegions.add(r); 
				}
				lastIdx = currentRegion.b;
			}
			RegionSet * rs = currentRegion.data in styledRegionSets;
			if (rs is null)
			{
				RegionSet nrs = new RegionSet();
				rs = &nrs;
				styledRegionSets[currentRegion.data] = nrs;
			}
			rs.add(currentRegion);
		}
			
		// Add a last region with a default style
		auto r = Region(lastIdx, uint.max);
		r.data = defaultStyle;
		defaultStyleRegions.add(r);
		
		updateRegionSetModel(text, textOffset, size, defaultStyleRegions);
		
		foreach (styledRegionSet; text.styledRegionSets)
		{
			updateRegionSetModel(text, textOffset, size, styledRegionSet);
		}
		*/
	}
	/*
	
	private void updateRegionSetModel(TextRange)(TextRange text, size_t textOffset, 
						 		                 Vec2f size, RegionSet regions)
	{
		if (regions.empty)
			return;
		Style style = regions.front.data;
		Rectf worldBounds = Rectf(0, 0, size.x, size.y);
		Model model = GetTextModelForStyle(style);
		model.material.texture = style.font.fontMap;
		
		// POI should be regions
		msetTextMesh(model, text, regions, worldBounds, style.wordWrap);
	}
	*/
	
	void draw(Mat4f transform)
	{
		styleTextModel.draw(Window.active.MVP * transform);
	}
	
	// }
	//		Vec2f poi = model.setTextMesh(buffer[bufferOffset..buffer.length], toks, font, textModel.mesh, r, cursorPoint - bufferOffset, pointer, wordWrap);
	
	
	//		cursorModel.transform = widget.activeStyle.model.transform * Mat4f.makeTranslate(Vec3f(poi.x, poi.y + Window.active.pixelHeightToWorld(font.fontLineSkip), 0f));
	// cursorModel.draw();	 	
	
	
	/*
	
		
		// Create child widgets for the visible parts of the buffer
		import std.conv;
		import std.array;
		
		// rect is widget.rect
		//	Rectf wrect = Window.active.windowToWorld(rect);
		// model.transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0f));
		
		
		textModel.transform = widget.activeStyle.model.transform;

		Vec2f ppad = Vec2f(padding.pos.x, -padding.pos.y);
		Vec2f wpad = Vec2f(widget.rect.size.x - padding.pos.x - padding.size.x, padding.pos.y + padding.size.y - widget.rect.size.y); !!!RECT
		Rectf r = Rectf(Window.active.pixelSizeToWorld(ppad), Window.active.pixelSizeToWorld(wpad));
		
		auto toks = buildKeywordTokens();
					
		Vec2f pointer;
		Vec2f poi = textModel.setTextMesh(buffer[bufferOffset..buffer.length], toks, font, textModel.mesh, r, cursorPoint - bufferOffset, pointer, wordWrap);
		
		textModel.draw();

		cursorModel.transform = widget.activeStyle.model.transform * Mat4f.makeTranslate(Vec3f(poi.x, poi.y + Window.active.pixelHeightToWorld(font.fontLineSkip), 0f));
		cursorModel.draw();
	}
		*/
	
	/*
	Heap buildKeywordTokens()
	{
		Token[dstring] templates;
		// = { 
//			"alias" = Token(0, 0, Vec3f(0,1,0))
		//};
		
		// TODO: use ctRegex
		enum decls = [ "alias"d, "auto", "assert", "class", "const", "enum", "extern", "for", "if", "import", "module", "new", "nothrow"
			"private", "public", "pure", "return", "safe", "scope", "static", "struct", "template", "this", "union", "unittest", "version",
			"while" ];
		enum types = [ "byte"d, "char", "dchar", "int", "long", "short", "ubyte", "uint", "ulong", "ushort", "void", "wchar" ];
		dstring re = "(";
		dstring delim = "";
		foreach (tt; decls)
		{
			re ~= delim;
			re ~= tt;
			delim = "|";
		}
		foreach (tt; types)
		{
			re ~= delim;
			re ~= tt;
		}
		re ~= ")";
		
		import std.regex;		
		auto ctr = regex(re, "mg");
		
		foreach (d; decls)
			templates[d] = Token(0, 0, Vec3f(0.3,0.3,1));
		foreach (t; types)
			templates[t] = Token(0, 0, Vec3f(0.3,1,0.3));
		
		dstring[] names = templates.keys();
		Token[] toks;
		
		import std.array;
		auto buf = array(buffer[bufferOffset..buffer.length]);
		
		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			t.begin = m.pre.length;
			t.end = t.begin + m.hit.length;
			toks ~= t;

		}

		Heap h;
		h.acquire(toks);
		return h;
	}
	*/
	
	/* Update and create sub-widgets as necessary
	 */
	//void onUpdate(ref Widget widget)
	//{
	//}
	/*
	uint posToTextIndex(Vec2f pos)
	{
		
	}
	 */
	/*
	Vec2f textIndexToRect(uint i)
	{
		if (styledText is null) return Vec2f.init;
		
		Rectf maxLast; // In case the index is after all known regions the we just return the max rect found
		Region needle = { i, i+1 };
		foreach (style, regionSet; text.styledRegionSets)
		{
			if (regionSet.empty)
				continue;
			
			// POI should be regions
			setTextMesh(regionSet, renderArea, style);
		}	
	}
	*/
	
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
			
			//std.stdio.writeln(o);
			//o.size *= 1f;
			//o = Rectf(0,0,1,1);
			Rectf c = g.uvRect;
			
			//c = Rectf(Vec2f(c.pos.x, -c.pos.y), c.size);
			//c.pos *= 2.05f;
			//c.size *= 1.0f;
			
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
			
			//			pos.x += Window.active.pixelWidthToWorld(font.fontWidth);
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
		
		//std.stdio.writeln(uvs.length);
		//std.stdio.writeln(verts.length);
		lineBox.renderOffsetX = pos.x;
		return charsUsed;
	}
	/++

	/** Render a text range as into a text model
	 */
	Vec2f setTextMesh(R)(Mesh mesh, R str, Rectf rect, Style style)
	// Vec2f setTextMesh(R)(Model textModel, R str, Heap toks, Font font, Mesh target, Rectf box, size_t charOfInterest, Vec2f charAtCoords, bool wrap = true)
	{
		float sx = rect.x;
		Vec2f pos = Vec2f(sx, rect.y - Window.active.pixelHeightToWorld(style.font.fontLineSkip));
		// std.stdio.writeln(pos.v, " ", rect.pos.v, " ", rect.size.v);
		Font font = style.font;
		auto color = style.color;
		
		// Estimate buffer sizes
		auto verts = &mesh.buffers[0].data;
		auto uvs = &mesh.buffers[1].data;
		auto cols = &mesh.buffers[2].data;

		//verts.length = str.length * 18; // 6 vertices
		//cols.length = str.length * 18; // 6 vertices
		//uvs.length = str.length * 12;   // 6 uvs
	
		size_t idx = 0;
		size_t handled = 0;
		bool skip = false;
		size_t charOfInterest = 0; // TODO: fix
		charOfInterest++;
		Vec2f poi = Vec2f(0,0);
		
		RegionSet.Container.Range regions = regionSet[]; // slice for iteration
		
		auto nextRegion = Region.init;
		
		if (!regions.empty)
		{
			nextRegion = regionSet.front;
			regions.popFront();
		}
	
		
		foreach (ch; str)
		{			
			std.stdio.writeln("regions ", nextRegion);
			// std.stdio.writeln("dd ", ch,  " ", str.length);
			handled++;
			if (charOfInterest == handled && !skip)
				poi = pos;
	
			glyphPositions ~= pos;
			
			if (ch == '\n')
			{
				skip = false;
				pos.x = sx;
				pos.y -= Window.active.pixelHeightToWorld(font.fontLineSkip);
				continue;
			}
			
			if (ch == '\r' || skip)
				continue;
			
			if (ch == '\t')
			{
				pos.x += Window.active.pixelWidthToWorld(font.fontWidth) * 4;
				continue;
			}
			
			if (ch == ' ')
			{
				pos.x += Window.active.pixelWidthToWorld(font.fontWidth);
				continue;
			}
	
			if (pos.x >= rect.x2)
	{
				if (style.wordWrap)
				{
					pos.x = sx;
					pos.y -= Window.active.pixelHeightToWorld(font.fontLineSkip);
				} 
				else
				{
					skip = true;
					continue;
				}
			}
	
			if (pos.y > rect.y2)
			{
				skip = true; // signal that cursor might be out of visible area
				break; 
			}
						
			// Lookup glyph in font
			auto g = font.lookupGlyph(ch);
			auto offsetRect = Rectf(Window.active.pixelSizeToWorld(g.offsetRect.pos), 
									Window.active.pixelSizeToWorld(g.offsetRect.size));
			Rectf o = offsetRect + pos;
			//std.stdio.writeln(o);
			//o.size *= 1f;
			//o = Rectf(0,0,1,1);
			Rectf c = g.uvRect;
			//c = Rectf(Vec2f(c.pos.x, -c.pos.y), c.size);
			//c.pos *= 2.05f;
			//c.size *= 1.0f;
				
			size_t base = idx*18;
			
			// TODO: optimize using e.g slices
			verts[base..base+2] = o.pos.v[];
			//verts[base+0] = o.x;
			//verts[base+1] = o.y;
			verts[base+2] = 0f;
			
			verts[base+3] = o.x;
			verts[base+4] = o.y2;
			verts[base+5] = 0f;
	
			verts[base+6] = o.x2;
			verts[base+7] = o.y2;
			verts[base+8] = 0f;
	
			verts[base+9] = o.x;
			verts[base+10] = o.y;
			verts[base+11] = 0f;
	
			verts[base+12] = o.x2;
			verts[base+13] = o.y2;
			verts[base+14] = 0f;
	
			verts[base+15] = o.x2;
			verts[base+16] = o.y;
			verts[base+17] = 0f;
	
			uint h = handled - 1;
			if (nextRegion.a <= h && nextRegion.b > h)
			{
				for (int i = 0; i < 6; i++)
				{
					cols[base+i*3] = color.r;
					cols[base+i*3+1] = color.g;
					cols[base+i*3+2] = color.b;
				}
				if (nextRegion.b - 1 == h && !regions.empty)
				{
					nextRegion = regions.front;
					regions.popFront();
				}
			}
			else
			{
				for (int i = 0; i < 6; i++)
				{
					cols[base+i*3] = 1.0f;
					cols[base+i*3+1] = 1.0f;
					cols[base+i*3+2] = 1.0f;
				}
			}
			
			base = idx*12;
	
			uvs[base+0] = c.x;
			uvs[base+1] = c.y;
			
			uvs[base+2] = c.x;
			uvs[base+3] = c.y2;
	
			uvs[base+4] = c.x2;
			uvs[base+5] = c.y2;
	
			uvs[base+6] = c.x;
			uvs[base+7] = c.y;
	
			uvs[base+8] = c.x2;
			uvs[base+9] = c.y2;
	
			uvs[base+10] = c.x2;
			uvs[base+11] = c.y;
			
	//			pos.x += Window.active.pixelWidthToWorld(font.fontWidth);
			pos.x += Window.active.pixelWidthToWorld(g.advance);
			//pos += Vec2f(0.3f);
			idx++;
		}
		verts.length = idx * 18;
		uvs.length = idx * 12;
		mesh.buffers[0].setData(verts);
		mesh.buffers[1].setData(uvs);
		mesh.buffers[2].setData(cols);
	
		//std.stdio.writeln(uvs.length);
		//std.stdio.writeln(verts.length);
		
		// Special case when cursor poi is after the very last char in str 
		if (handled == str.length && charOfInterest == (handled+1) && !skip)
			poi = pos;
		
		return poi;
		
	}
	
++/	
	
}
