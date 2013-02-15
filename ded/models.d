module models;

import graphics;
import style; // : Style;
import styledtext;

import region;
import std.range;
import std.container;

Model!int createTriangle()
{
	float[] v = [   -0.75f, -0.75f, 0.0f, 
                  0.75f, 0.75f, 0.0f, 
                  -0.75f, 0.75f, 0.0f]; 
	float[] c = [   0.0f, 0.0f, 
                  1.0f, 1.0f, 
                  0.0f, 1.0f]; 
	float[] cols = new float[v.length];
	std.algorithm.fill(cols, 1.0f);
	
	Buffer vertexBuf = Buffer.create(v);
	Buffer colorBuf = Buffer.create(c);
	Buffer vertCols = Buffer.create(cols);	
	
	Mesh mesh = Mesh.create();
	mesh.setBuffer(vertexBuf, 3, 0);
	mesh.setBuffer(colorBuf, 2, 1);
	mesh.setBuffer(colorBuf, 3, 2);
 
	auto m = new Model!int();
	m.addSubModel(0);
	m.mesh = mesh;
	m.material = Material.builtIn;
	
	return m;
}


float[] quadVertices(Rectf r)
{
	float[] verts = [ 
		r.x,  r.y,  0f,
		r.x,  r.y2, 0f,
		r.x2, r.y2, 0f, 
		r.x,  r.y,  0f,
		r.x2, r.y2, 0f,
		r.x2, r.y,  0f ];			
	return verts;	
}

float[] quadUVs(Rectf rect, Material mat, Window win)
{
	float windowMaxU = win.width / mat.texture.width;
	float windowMaxV = win.height / mat.texture.height;
	float u = (0.5f * rect.w) * windowMaxU;
	float v = (0.5f * rect.h) * windowMaxV;
	float[] c = [
		0f, 1f,
		0f, v + 1f,
		u,  v + 1f,
		0f, 1f,
		u,  v + 1f,
		u,  1f];
	/*float[] c = [
		0f, v,
		0f, 0f,
		u, 0f,
		0f, v,
		u, 0f,
		u, v ];*/
	return c;
}

Model!int createWindowQuad(Rectf windowRect, Material mat)
{
	Rectf rect = Window.active.windowToWorld(windowRect);
	auto m = new Model!int();
	m.addSubModel(0);
	
	rect.pos = Vec2f(0,0);
	
	float[] vert = quadVertices(rect);
	float[] uv = quadUVs(rect, mat, Window.active);
	float[] cols = new float[vert.length];
	std.algorithm.fill(cols, 1.0f);
	Buffer vertexBuf = Buffer.create(vert);
	Buffer colorBuf = Buffer.create(uv);
	Buffer vertCols = Buffer.create(cols);
	
	Mesh mesh = Mesh.create();
	mesh.setBuffer(vertexBuf, 3, 0);	
	mesh.setBuffer(colorBuf, 2, 1);	
	mesh.setBuffer(vertCols, 3, 2);	

	m.mesh = mesh;
	m.material = mat;
	
	return m;
}



import std.container;
import graphics;
import math;
import font;

alias BinaryHeap!(Token[], "a.begin > b.begin") Heap;

// Reuse of temporary float arrays during rendering.
private
{
	// Keep verts and uv arrays for reuse in order
	// to prevent allocating new arrays all the time
	float[] verts;
	float[] cols;
	float[] uvs;
}

// Token pointing into a text buffer to specify attributes of the token
// such as color etc.
struct Token
{
	uint begin;
	uint end;
	Vec3f color;
}

/** Render a text range as into a text model
 */
void setTextMesh(R)(Model textModel, R str, RegionSet regionSets, Rectf rect, bool wrap = true)
// Vec2f setTextMesh(R)(Model textModel, R str, Heap toks, Font font, Mesh target, Rectf box, size_t charOfInterest, Vec2f charAtCoords, bool wrap = true)
{
/*
		float sx = box.x;
	Vec2f pos = Vec2f(sx, box.y - Window.active.pixelHeightToWorld(font.fontLineSkip));
	
	// Estimate buffer sizes
	verts.length = str.length * 18; // 6 vertices
	cols.length = str.length * 18; // 6 vertices
	uvs.length = str.length * 12;   // 6 uvs

	size_t idx = 0;
	size_t handled = 0;
	bool skip = false;
	charOfInterest++;
	Vec2f poi = Vec2f(0,0);
	
	auto nextToken = Token.init;
	
	if (!toks.empty)
	{
		nextToken = toks.front;
		toks.removeFront();
	}

	foreach (ch; str)
	{			
		handled++;
		if (charOfInterest == handled && !skip)
			poi = pos;

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
			pos.x += Window.active.pixelWidthToWorld(font.fontWidth * 0.5) * 4;
			continue;
		}
		
		if (ch == ' ')
		{
			pos.x += Window.active.pixelWidthToWorld(font.fontWidth * 0.5);
			continue;
		}

		if (pos.x >= box.x2)
		{
			if (wrap)
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

		if (pos.y < box.y2)
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
		if (nextToken.begin <= h && nextToken.end > h)
		{
			for (int i = 0; i < 6; i++)
			{
				cols[base+i*3] = nextToken.color.x;
				cols[base+i*3+1] = nextToken.color.y;
				cols[base+i*3+2] = nextToken.color.z;
			}
			if (nextToken.end - 1 == h && !toks.empty)
			{
				nextToken = toks.front;
				toks.removeFront();
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
	textModel.mesh.buffers[0].setData(verts);
	textModel.mesh.buffers[1].setData(uvs);
	textModel.mesh.buffers[2].setData(cols);

	//std.stdio.writeln(uvs.length);
	//std.stdio.writeln(verts.length);
	
	// Special case when cursor poi is after the very last char in str 
	if (handled == str.length && charOfInterest == (handled+1) && !skip)
		poi = pos;
	
	return poi;
	*/
}

class OldStyledText(Text)
{
	public RegionSet[Style] styledRegionSets;
	public Text text;
	
	this(Text text)
	{
		this.text = text;
	}
	
	// A Region specifying the composed style of several styles 
	static struct StyledRegion
	{
		Region _reg;
		alias _reg this;
		Style style;
		this(uint a, uint b, Style style)
		{
			this.a = a;
			this.b = b;
			this.style = style;
		}
	}

	// This slice can be used to iterate over composed style regions lazyly. 
	auto opSlice(uint from, uint to)
	{
		struct Range
		{
			// Ranges of the styled regions in styledRegionSets
			// that points to the next candidate of each set. 
			RegionSet.Range[] styledRegionSetsRanges;  
			Style[] styles;
			StyledRegion curRegion_;
			uint to_;
							
			this(RegionSet[Style] _styles, uint f, uint t)
			{
				curRegion_ = StyledRegion(f, t, new Style);
				to_ = t;
				styledRegionSetsRanges.length = _styles.length;
				int idx = 0;
				foreach (style, regset; _styles)
				{
					styles[idx] = style;
					auto ran = regset[];
					styledRegionSetsRanges[idx] = ran;
				}
				curRegion_.b = curRegion_.a - 1;
				popFront();
			}
			
			void popFront()
			{
				assert(!empty);
				// Pop all from all ranges which next region ends at the
				// same place at the current active one
				bool allEmpty = true;
				
				Region testRegion = { curRegion_.b + 1, to_ };
				assert(!testRegion.empty);
				assert(testRegion.a < testRegion.b);
				
				curRegion_.a = uint.max;
				curRegion_.b = uint.max;
				curRegion_.style.clear();
				
				uint smallestIdx = uint.max;
				
				foreach (i, ref r; styledRegionSetsRanges)
				{
					allEmpty = allEmpty && r.empty;
					while (!r.empty && r.front.b <= testRegion.a)
					{
						r.popFront();
					}
					
					if (!r.empty)
					{
						Region reg = testRegion.intersect(r.front);
						if (reg.a < curRegion_.a && curRegion_.a > testRegion.a)
						{
							// Reset to let reg start until border with curRegion be the 
							// new only style.
							curRegion_.b = curRegion_.a;
							curRegion_.a = reg.a;
							curRegion_.style.clear();
							curRegion_.style.merge(styles[i]);
							continue;
						}
						else if (reg.a == curRegion_.a)
						{
						    // Change the curRegion end to be the smallest of reg and curRegion
							// Also merge the styles
							curRegion_.b = std.algorithm.min(reg.b, curRegion_.b);
							curRegion_.style.merge(styles[i]);
						}
						assert(curRegion_.a < curRegion_.b);
					}
				}
				
				assert(!allEmpty);
			}
						
			@property 
			{
				@safe bool empty() const nothrow
				{
					return curRegion_.a == uint.max;
				}
				
				@safe StyledRegion front() const nothrow
				{
					assert(!empty);
					return StyledRegion(curRegion_);
				}
			}
		}
		
	}
	
	unittest
	{
		auto white = new Style;
		auto black = new Style;
		auto yellow = new Style;
		
		std.stdio.writeln("Styles white %x, black %x, yellow %x", &white, &black, &yellow); 
		
		auto text = new StyledText!dchar("yellow white gray black yellow"d);
		text.styledRegionSets[yellow].add(0, 6); 
		text.styledRegionSets[white].add(7, 17);
		text.styledRegionSets[black].add(13, 23);
 		text.styledRegionSets[yellow].add(24, 100); 

		auto r = text[1..text.text.length];
		
		// Print out the styles
		foreach (sr; r)
		{
			std.stdio.writeln("Range %i %i: %x", sr.a, sr.b, sr.style);
		}
				
	}
	
	void update(StyleSet styleSet)
	{
		if (styledRegionSets.length != 0) return; // TODO: fix
		
		// TODO: parse text and set styles
		auto regionSet = new RegionSet();
		auto r = Region(0, uint.max);
		regionSet.add(r);
		styledRegionSets[StyleSet.base[""]] = regionSet;
	}
}



// Move cursorpoint/prefcolumn to TextView
// Remove widget dep and just provide a rect and style
/** A TextRenderer that can draw some text that may be decorated
 * 
 * It can also be queried for render position of specific text regions or characters
 */
class TextModel(Text)
{
	private
	{
		Model!Style styleTextModel;
		StyledText!Text styledText;
		Vec2f[] glyphPositions;
				 
		//Model textModel;
		//Model cursorModel;
	}
	
	Rectf renderArea;
	Region[] _queryRegionRects;
	Rectf[][] _queryRegionRectsResult;
	
	this(StyledText!Text styledText)
	{
		this.styledText = styledText;
	}
	
	/*
	this(Font font)
	{
		//this.font = font;
		
		
		// Cursor model
		// cursorModel = createWindowQuad(Rectf(0, 0, font.fontWidth * 0.25, font.fontLineSkip), Material.builtIn);
	}
	*/
	
	private Model!Style.SubModel GetTextSubModelForStyle(Style style)
	{
		if (styleTextModel is null)
			styleTextModel = new Model!Style();

		Model!Style.SubModel * m = style in styleTextModel.subModels;
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
		auto textModel = styleTextModel.addSubModel(style);
		textModel.mesh = Mesh.create();
		textModel.mesh.setBuffer(vertexBuf, 3, 0);
		textModel.mesh.setBuffer(colorBuf, 2, 1);	
		textModel.mesh.setBuffer(vertColBuf, 3, 2);	
						
		Material mat = new Material();
		mat.shader = Material.builtIn.shader;
		textModel.material = mat;
		return textModel;
	}
	
	// also accept the buffer and the regions of interest to style
	//	void onDraw(ref Widget widget, TextGapBuffer (or bufferHaveSomeFeatures) buffer, RegionSetStyles, RegionSet getInfoAbout)

	/** Setup a query for getting Rects for a region as how it is rendered
	 * 
	 */
	void queryRegionRects(Region r)
	{
	
	}
		
	/** Draw text into a rect and style text using regions
	 * 
	 * Text Regions with no style is not modelled at all.
	 * 
	 * Params:
	 * text	= The text and RegionSets for the styles. 
	 * regionToMode = The offset into the text range where the first char of the offset will be located
	 *                to the upper left in the rect as the first char of the first line.
	 * size = The size of the rendering area in world coordinates 
	 */ 
	void update(Region regionToModel)
	{
		if (styledText is null) return;

		
				
		glyphPositions.length = regionToModel.b - regionToModel.a;
		
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
			styleTextModel.draw(transform);
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
		Vec2f wpad = Vec2f(widget.rect.size.x - padding.pos.x - padding.size.x, padding.pos.y + padding.size.y - widget.rect.size.y);
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
	 */
	Vec2f setTextMesh(R)(Mesh mesh, R str, RegionSet regionSet, Rectf rect, Style style)
	// Vec2f setTextMesh(R)(Model textModel, R str, Heap toks, Font font, Mesh target, Rectf box, size_t charOfInterest, Vec2f charAtCoords, bool wrap = true)
	{

		
		float sx = rect.x;
		Vec2f pos = Vec2f(sx, rect.y - Window.active.pixelHeightToWorld(style.font.fontLineSkip));
		// std.stdio.writeln(pos.v, " ", rect.pos.v, " ", rect.size.v);
		Font font = style.font;
		auto color = style.color;
		
		// Estimate buffer sizes
		verts.length = str.length * 18; // 6 vertices
		cols.length = str.length * 18; // 6 vertices
		uvs.length = str.length * 12;   // 6 uvs
	
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
	
	
	
}








