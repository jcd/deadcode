module font;


import graphics;
import math;

import std.exception;
import std.conv;

import derelict.sdl2.sdl; 
import derelict.sdl2.ttf;

class Font
{
	private
	{
		TTF_Font * ttfFont;
		
		GlyphInfo[] glyphInfoASCII; // special case ascii from unicode because it is the most common one
		GlyphInfo[dchar] glyphInfoUnicode;
	}

	struct GlyphInfo
	{
		dchar ch; // unicode char
		int minX;
		int maxX;
		int minY;
		int maxY;
		int advance;
		
		// Fontmap info
		Rectf uvRect;
		
		// rect in world coords that can be used for rendering the font pixel perfect
		// at the correct centering in the advance width. z offset should be 0.
		// Use this and the u,v to create two triangles for rendering the glyph
		Rectf offsetRect;
	}
	
	uint fontHeight;
	uint fontWidth; // max width (estimated from max advance)
	int fontAscent;
	int fontDescent;
	uint fontLineSkip;
	
	Texture fontMap;
	size_t size;
	
	this(const(char)[] path, size_t size)
	{
		this.size = size;
		
		SDL_ClearError();
		ttfFont = TTF_OpenFont(cast(char*)path, size);
		enforceEx!Exception(ttfFont !is null, text("Error loading font ", path));
		
		uint begin = cast(uint) '!';
		uint end = cast(uint) '~';
		glyphInfoASCII.length = end - begin + 1;		
		updateFontMap();
	}
	
	GlyphInfo lookupGlyph(dchar ch)
	{
		assert(cast(uint)ch - cast(uint)'!' <= glyphInfoASCII.length, text("ASCII Glyph out of bounds ", ch) );
		return glyphInfoASCII[cast(uint)ch - cast(uint)'!']; // TODO: fix
	}
	
	private void updateFontMap()
	{
		recalculateGlyphInfo();
		recalculateFontMapSize();
		populateFontMap();	
	}
	
	private void recalculateGlyphInfo()
	{
		fontHeight = TTF_FontHeight(ttfFont);
		fontAscent = TTF_FontAscent(ttfFont);
		fontDescent = TTF_FontDescent(ttfFont);
		fontLineSkip = TTF_FontLineSkip(ttfFont);
		fontWidth = 0;
		
		// Ascii map
		ushort begin = cast(ushort) '!';
		ushort end = cast(ushort) '~';
		for (ushort i = begin; i <= end; i++)
		{
			GlyphInfo gi;
			gi.ch = cast(wchar)i;
			if (TTF_GlyphMetrics(ttfFont, i, &gi.minX, &gi.maxX, &gi.minY, &gi.maxY, &gi.advance) != 0)
			{
				std.stdio.writeln("Error creating glyph ", TTF_GetError(), " ", i);
				continue;
			}
			glyphInfoASCII[i-begin] = gi;
			
			// Estimate max glyph width
			fontWidth = fontWidth < gi.advance ? gi.advance : fontWidth;
		}
	}
	
	private void recalculateFontMapSize()
	{
		// Calculate min size of texture.
		size_t totalGlyphs = glyphInfoASCII.length + glyphInfoUnicode.length;
		size_t px = fontWidth * fontHeight;
		uint texWidth = 64;
		uint texHeight = 128;
		
		done: while (texHeight <= 4096)
		{
			uint glyphsPerHeight = texHeight / fontHeight;
			while (texWidth <= 4096)
			{
				uint glyphsPerWidth = texWidth / fontWidth;
				if (glyphsPerWidth * glyphsPerHeight > totalGlyphs)
					break done;
				texWidth <<= 1;
			}
			texWidth = 64;	
			texHeight <<= 1;
		}
		
		
		
		enforceEx!Exception(texWidth <= 4096, "Font map texture width > 4096");
		enforceEx!Exception(texHeight <= 4096, "Font map texture height > 4096");
	
		if (fontMap !is null && (fontMap.width != texWidth || fontMap.height != texHeight))
		{
			fontMap.release();
			fontMap = null;
		}
		
		if (fontMap is null)
		{
			fontMap = Texture.create(texWidth, texHeight);
		}
	}
	
private int nextPowerOfTwo(int i) nothrow
{
    int v = i - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    //assert(isPowerOf2(v));
    return v;
}
	
	private void populateFontMap()
	{
		SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, cast(int)fontMap.width, cast(int)fontMap.height, 32,
													     0, 0, 0, 0);
													//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);

		SDL_Color col = SDL_Color(255,255,255);

		float lastU = 0f;
		float lastV = 1f; 		
		float uPerPixel = 1f / fontMap.width;
		float vPerPixel = 1f / fontMap.height;
		float vHeight = fontHeight * vPerPixel;
	
		uint lastX = 0;
		uint lastY = 0;
						
		foreach (ref gi; glyphInfoASCII)
		{
			SDL_Surface * s = TTF_RenderGlyph_Blended(ttfFont, cast(wchar)gi.ch, col);
			//SDL_Surface * s = TTF_RenderUTF8_Blended(ttfFont, "hello".ptr, col);
			if (s is null)
			{
				
				std.stdio.writeln("Could not rasterize glyph ", gi.ch);
				break;
			}
			
			
			float uWidth = gi.advance * uPerPixel;
			if (lastU + uWidth > 1f)
			{
				lastU = 0f;
				lastV -= vHeight;
				lastX = 0;
				lastY += fontHeight;
			}

			float v = lastV - (s.h * vPerPixel);
			gi.uvRect = Rectf(lastU, v, lastU + (s.w * uPerPixel), lastV);
			
			auto glyphPos = Vec2f(gi.minX, gi.minY - fontDescent);
			//auto gp = Vec2f(glyphPos.x / fontMap.width, glyphPos.y / fontMap.height);
			auto glyphSize = Vec2f(s.w, s.h);
			//auto gs = Vec2f(glyphSize.x / fontMap.width, glyphSize.y / fontMap.height);
			
			//gi.offsetRect = Rectf(Window.active.pixelSizeToWorld(glyphPos), Window.active.pixelSizeToWorld(glyphSize));
			
			// Save px pos offset and size for positioning the character correct on rendering
			gi.offsetRect = Rectf(glyphPos, glyphSize);
			
			SDL_Rect area;
			area.x = lastX;
			area.y = lastY;
			area.w = gi.advance;
			area.h = fontHeight;
		
			//std.stdio.writeln("ras ", gi.ch, " ", s.w, " ", s.h, " ", gi.advance, " ", fontHeight, " ", fontMap.width, " ", fontMap.height,
//				" ", lastX, " ", lastY, " ", gi.minX, " ", gi.minY, " ", gi.maxY);

			SDL_BlitSurface(s, null, pow2surface, &area);
			SDL_FreeSurface(s);

			// Get ready for next char. Offset by 2px to avoid bleeding
			lastU += uWidth + uPerPixel * 2;
			lastX += gi.advance + 1 * 2;
		}

		Rectf rect = Rectf(0, 0, fontMap.width, fontMap.height);
		fontMap.blitSDLSurface(rect, pow2surface, true);
		SDL_FreeSurface(pow2surface);
	}
	
	void calcSize(const(char)[] msg, out int w, out int h)
	{
		enforceEx!Exception(TTF_SizeUTF8(ttfFont, msg.ptr, &w, &h) > 0,
						text("Error measuring text size: ", TTF_GetError()));
	}	
}

/*
Model createWindowFontMapTestQuad(Rectf windowRect)
{
	Rectf rect = Window.active.windowToWorld(windowRect);

	float[] vert = quadVertices(rect);
	float[] uv = quadUVs(rect, mat, Window.active);

	Buffer vertexBuf = Buffer.create(vert);
	Buffer colorBuf = Buffer.create(uv);
	
	Mesh mesh = Mesh.create();
	mesh.setBuffer(vertexBuf, 3, 0);	
	mesh.setBuffer(colorBuf, 2, 1);	

	Model m = new Model();
	m.mesh = mesh;
	m.material = mat;
	
	return m;
}
*/