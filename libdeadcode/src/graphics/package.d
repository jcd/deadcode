/*
 * No unittest in the graphics module since it it is bound to statefull OpenGL
 * and image comparing tests is more appropriate
 */
module graphics;

import std.stdio;
import std.range;
import std.string;
import std.typecons;
import std.exception;
import std.conv;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.ttf;
import derelict.opengl3.gl3;

import math;

/*
pragma(lib, "DerelictUtil.lib");
pragma(lib, "DerelictSDL2.lib");
pragma(lib, "DerelictGL3.lib");
*/

Texture defaultTexture;
Shader defaultShader;
Material defaultMaterial;

public import graphics.shader;
public import graphics.shaderprogram;
public import graphics.texture;
public import graphics.buffer;
public import graphics.mesh;
public import graphics.material;
public import graphics.model;
public import graphics.font;
public import graphics.color;
public import graphics.renderwindow;
public import graphics.rendertarget;
public import graphics.graphicssystem;


version (none)
{
final class GFont
{
	private TTF_Font * font;

	this(const(char)[] path, size_t size)
	{
		SDL_ClearError();

		font = TTF_OpenFont(cast(char*)path, size);
		enforceEx!Exception(font !is null, text("Error loading font ", path));
	}

	void calcSize(const(char)[] msg, out int w, out int h)
	{
		enforceEx!Exception(TTF_SizeUTF8(font, msg.ptr, &w, &h) > 0,
						text("Error measuring text size: ", TTF_GetError()));
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

Texture createTextTexture(const(char)[] path, size_t size)
{
	SDL_ClearError();
	TTF_Font * font = TTF_OpenFont(cast(char*)path, size);
	if (font is null)
	{
		writeln("Error loading font ", path);
	}

	SDL_Color col = SDL_Color(255,255,255);
	SDL_Surface * surface = TTF_RenderUTF8_Blended(font, "hello Morld", col);
	if (surface is null)
	{
		writeln("Error creating text surface");
	}
	//SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE);

	int widthInNearestPowOf2 = nextPowerOfTwo(surface.w);
	int heightInNearestPowOf2 = nextPowerOfTwo(surface.h);

	// Create a surface with pow two size as appropriate for opengl convertion
	SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, widthInNearestPowOf2, heightInNearestPowOf2, 32,
											0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);

	// This is the only line relating to blending and alpha that seems to do anything I could notice.
	SDL_Rect area;
	area.x = 0;
	area.y = 0;
	area.w = surface.w;
	area.h = surface.h;

	SDL_BlitSurface(surface, null, pow2surface, &area);

	auto texture = Texture.createFromSDLSurface(pow2surface);
	SDL_FreeSurface(surface);
	SDL_FreeSurface(pow2surface);
	return texture;
}

void renderText(Texture target, Rectf rect, GFont font, const(char)[] msg)
{
//	SDL_Surface * surface = SDL_CreateRGBSurface(0, cast(int)rect.w, cast(int)rect.h, 32,
//													0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
	static if (true)
	{
	auto tr = Rectf(0,0,rect.w, rect.h);
	for (int i = 0; i < 50; i++)
	{
		renderText(target, tr.pos, font, "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");
//		renderText(target, tr.pos, font, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");
		tr.pos.y += 14;
	}

	//target.blitSDLSurface(rect, surface);
	//SDL_FreeSurface(surface);

	return;
	SDL_Surface * surface;
	}

	int w, h;
	Rectf targetRect = rect;
	size_t msgIdx = 1;

	immutable(char)* str = null;
	immutable(char)* strtmp = null;

	while (!msg.empty)
	{
		msgIdx = 1;
		do
		{
			str = strtmp;
			strtmp = toStringz(msg[0..msgIdx]);
			TTF_SizeUTF8(font.font, strtmp, &w, &h);
			//font.calcSize(msg[0..msgIdx], w, h);
			msgIdx++;
//			writeln("idx is ", msgIdx, " ", msg.length, " ", msg[0..msgIdx], " ");
		} while (w < targetRect.w && msg.length >= msgIdx);

		msgIdx--;

		//writeln("info ", w, " ", h, " ", rect, " ", msgIdx, " ", strtmp, " ", str);

		if (h > targetRect.h)
		{
			writeln("Rect not heigh enough to render glyphs ", w, " ", h, " ", targetRect, msgIdx);
			return;
		}

		if (msgIdx == 1 && w > targetRect.w)
		{
			writeln("Rect not wide enough to render a glyph ", w, " ", h, " ", targetRect, " ", msgIdx, " ", msg[0..msgIdx]);
			return;
		}

		//writeln("aaa ", msg[0..msgIdx], " ", strtmp[0..msgIdx], " ", msgIdx);


		surface.renderText(targetRect.pos, font, strtmp[0..msgIdx+1]);
		msg = msg[msgIdx..$];
		targetRect.pos.y += h;
		targetRect.size.y -= h;
	}
	target.blitSDLSurface(rect, surface);
	SDL_FreeSurface(surface);
}

void renderText(SDL_Surface * target, Vec2f pos, GFont font, const(char)[] msg)
{
	SDL_ClearError();

	SDL_Color col = SDL_Color(255,255,255);
	SDL_Surface * surface = TTF_RenderUTF8_Blended(font.font, msg.ptr, col);
	enforceEx!Exception(surface !is null, "Error creating text surface");

	// Create a surface with pow two size as appropriate for opengl convertion
	//int width = cast(int)fmin(surface.w, target.width);
	//int height = cast(int)fmin(surface.h, target.height);

	//SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, width, height, 32,
													//0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);

	// This is the only line relating to blending and alpha that seems to do anything I could notice.
	SDL_Rect area;
	area.x = cast(int)pos.x;
	area.y = cast(int)pos.y;
	area.w = cast(int)(target.w >= pos.x + surface.w ? surface.w : target.w - pos.x);
	area.h = cast(int)(target.h >= pos.y + surface.h ? surface.h : target.h - pos.y);
//	area.h = surface.h;

	SDL_BlitSurface(surface, null, target, &area);

	//Rectf rect = Rectf(pos.x, pos.y, width,  height);
	//target.blitSDLSurface(rect, pow2surface);
	SDL_FreeSurface(surface);
	//SDL_FreeSurface(pow2surface);
}

void renderText(Texture target, Vec2f pos, GFont font, const(char)[] msg)
{
	SDL_ClearError();

	SDL_Color col = SDL_Color(255,255,255);
	SDL_Surface * surface = TTF_RenderUTF8_Blended(font.font, msg.ptr, col);
	enforceEx!Exception(surface !is null, "Error creating text surface");

	// Create a surface with pow two size as appropriate for opengl convertion
	int width = cast(int)fmin(surface.w, target.width);
	int height = cast(int)fmin(surface.h, target.height);

	SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, width, height, 32,
													0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);

	// This is the only line relating to blending and alpha that seems to do anything I could notice.
	SDL_Rect area;
	area.x = 0;
	area.y = 0;
	area.w = width;
	area.h = height;

	SDL_BlitSurface(surface, null, pow2surface, &area);

	Rectf rect = Rectf(pos.x, pos.y, width, height);
	target.blitSDLSurface(rect, pow2surface);
	SDL_FreeSurface(surface);
	SDL_FreeSurface(pow2surface);
}

} // version none
