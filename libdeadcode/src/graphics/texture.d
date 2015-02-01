module graphics.texture;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import graphics.color;

import math;
import std.stdio : writeln;

// Costs:
// Program binding
// FBO binding
// Texture binding
// Vertex array specification
// Buffer binding
// glUniform*
// Update current vertex state (glColor, glVertexAttrib, etc).

class Texture
{
	private static Texture builtIn_;

	static @property Texture builtIn()
	{
		import util.system;
		if (builtIn_ is null)
			builtIn_ = create(getRunningExecutablePath() ~ "bg2.png");
		return builtIn_;
	}

	uint glTextureID = 0;
	float width; // Todo: readonly?
	float height;

	@property vec2f size()
	{
		return Vec2f(width, height);
	}

	Rectf pixelRectToUVRect(Rectf r)
	{
		return pixelRectToUVRect(size, r);
	}

	static Rectf pixelRectToUVRect(Vec2f texSize, Rectf r)
	{
		auto sz = texSize;
		r.pos /= sz;
		r.size /= sz;
		return r;
	}

	enum Wrap
	{
		Repeat,
		RepeatMirrored,
		Clamp
	}
	@property void wrap(Wrap r)
	{
		glBindTexture(GL_TEXTURE_2D, glTextureID);
		int wrap;
		final switch (r)
		{
			case Wrap.Repeat:
				wrap = GL_REPEAT;
				break;
			case Wrap.RepeatMirrored:
				wrap = GL_MIRRORED_REPEAT;
				break;
			case Wrap.Clamp:
				wrap = GL_CLAMP_TO_BORDER;
				break;
		}

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap);
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	void release()
	{
		glDeleteTextures(1, &glTextureID);
	}

	@property bool valid() const
	{
		return glTextureID != 0;
	}

	static Texture create(float width, float height)
	{
		return create(cast(size_t)width, cast(size_t)height);
	}

	static Texture create(size_t width, size_t height)
	{
		SDL_Surface * s = SDL_CreateRGBSurface(0, width, height, 32,0,0,0,0);
		assert(s);
		auto texture = createFromSDLSurface(s);
		SDL_FreeSurface(s);
		return texture;
	}

	static Texture create(size_t width, size_t height, Color col, Texture intoThis)
	{
		assert(intoThis.glTextureID == 0);

		glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
		glGenTextures(1, &(intoThis.glTextureID));
		assert(intoThis.glTextureID > 0);
		glBindTexture(GL_TEXTURE_2D, intoThis.glTextureID);


		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

		int mode = GL_RGBA;
		scope ubyte[] pixels = new ubyte[width*height*4];
		ubyte r = col.rByte;
		ubyte g = col.gByte;
		ubyte b = col.bByte;
		foreach (i; 0..width*height)
		{
			pixels[i*4+0] = r;
			pixels[i*4+1] = g;
			pixels[i*4+2] = b;
			pixels[i*4+3] = cast(ubyte)0xff;
		}

		glTexImage2D(GL_TEXTURE_2D, 0, mode, width, height, 0, mode, GL_UNSIGNED_BYTE, pixels.ptr);
		intoThis.width = width;
		intoThis.height = height;
		return intoThis;

/*
		SDL_Surface * s = SDL_CreateRGBSurface(0, width, height, 32,0,0,0,0);
		assert(s);

		SDL_FillRect(s, null, 0xFFFFFFFF);

		//byte alpha = cast(byte)0xff;
		//SDL_FillRect(s, null,
					 // SDL_MapRGBA(s.format, 0xff, g, b, alpha));

		auto texture = createFromSDLSurface(s, intoThis);
		SDL_FreeSurface(s);
		return texture;
		*/
	}

	// if intoThis is null a new texture is allocated
	static Texture create(const(char)[] path, Texture intoThis = null)
	{
		import std.file;
		import derelict.sdl2.image;
		import std.string;

		assert(exists(path), path);
		SDL_Surface * s = IMG_Load(toStringz(path));

		assert(s);
		auto texture = createFromSDLSurface(s, intoThis);
		SDL_FreeSurface(s);
		return texture;
	}

	// if intoThis is null a new texture is allocated
	package static Texture createFromSDLSurface(SDL_Surface * s, Texture intoThis = null)
	{
		// assert(texture.glTextureID == 0);

		GLuint texID;
		glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
		glGenTextures(1, &texID);
		// assert(texture.glTextureID > 0);
		glBindTexture(GL_TEXTURE_2D, texID);

		int mode = GL_RGB;
		if(s.format.BytesPerPixel == 4) mode=GL_RGBA;

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

		SDL_Surface * px =  flip(s);
		glTexImage2D(GL_TEXTURE_2D, 0, mode, s.w, s.h, 0, mode, GL_UNSIGNED_BYTE, px.pixels);
		SDL_FreeSurface(px);

		if (intoThis is null)
		{
			intoThis = new Texture();
		}
		else
		{
			if (intoThis.glTextureID != 0)
			glDeleteTextures(1, &(intoThis.glTextureID));
		}

		intoThis.glTextureID = texID;
		intoThis.width = s.w;
		intoThis.height = s.h;
		return intoThis;
	}

	void blitSDLSurface(Rectf rect, SDL_Surface * s, bool flipY = true)
	{
		glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
		glBindTexture(GL_TEXTURE_2D, glTextureID);

		int mode = GL_RGB;
		if(s.format.BytesPerPixel == 4) mode=GL_RGBA;

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

		//		glTexSubImage2D(GL_TEXTURE_2D, 0, cast(int)rect.x, cast(int)rect.y, cast(int)rect.w, cast(int)rect.h, mode, GL_UNSIGNED_BYTE, flip(s).pixels);
		rect = Rectf(0, 0, width, height).clip(rect);
		SDL_Surface * px =  flip(s);
		if (flipY)
			glTexSubImage2D(GL_TEXTURE_2D, 0, cast(int)(rect.x), cast(int)(height - rect.y2), cast(int)rect.w, cast(int)rect.h, mode, GL_UNSIGNED_BYTE, px.pixels);
		else
			glTexSubImage2D(GL_TEXTURE_2D, 0, cast(int)(rect.x), cast(int)(rect.y), cast(int)rect.w, cast(int)rect.h, mode, GL_UNSIGNED_BYTE, px.pixels);
		SDL_FreeSurface(px);
	}

	private static SDL_Surface * clearSurface = null;
	void clear()
	{
		if (clearSurface !is null && (clearSurface.w < width || clearSurface.h < height))
		{
			SDL_FreeSurface(clearSurface);
			clearSurface = null;
		}

		if (clearSurface is null)
		{
			clearSurface = SDL_CreateRGBSurface(0, cast(int)width, cast(int)height, 32,0,0,0,0);
			writeln("new clear");
		}
		assert(clearSurface);
		blitSDLSurface(Rectf(0, 750, width, height), clearSurface);
	}

	//thanks to tito http://stackoverflow.com/questions/5862097/sdl-opengl-screenshot-is-black
	private static SDL_Surface* flip(SDL_Surface* sfc)
	{
		SDL_Surface* result = SDL_CreateRGBSurface(sfc.flags, sfc.w, sfc.h,
		                                           sfc.format.BytesPerPixel * 8, sfc.format.Rmask, sfc.format.Gmask,
		                                           sfc.format.Bmask, sfc.format.Amask);
		ubyte* pixels = cast(ubyte*) sfc.pixels;
		ubyte* rpixels = cast(ubyte*) result.pixels;
		uint pitch = sfc.pitch;
		uint pxlength = pitch*sfc.h;
		assert(result != null);

		for(uint line = 0; line < sfc.h; ++line) {
			uint pos = line * pitch;
			rpixels[pos..pos+pitch] =
				pixels[(pxlength-pos)-pitch..pxlength-pos];
		}

		return result;
	}

	void bind(int asIndex)
	{
		if (asIndex == 0)
			glActiveTexture(GL_TEXTURE0);
		else if (asIndex == 1)
			glActiveTexture(GL_TEXTURE1);
		else if (asIndex == 2)
			glActiveTexture(GL_TEXTURE2);

		glBindTexture(GL_TEXTURE_2D, glTextureID);
	}

}
