module graphics.texture;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;
import math._;
import std.stdio : writeln;

final class Texture 
{
	private static Texture builtIn_;
	
	static @property Texture builtIn()
	{
		import system;
		if (builtIn_ is null)
			builtIn_ = create(getRunningExecutablePath() ~ "bg2.png");
		return builtIn_;
	}
	
	uint glTextureID = 0;
	float width; // Todo: readonly?
	float height;
	
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
	
	private static Texture[string] managedTextures;
	
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
	
	static Texture create(const(char)[] path)
	{
		Texture * t = path in managedTextures;
		if (t) return *t;
		
		import std.file; 
		import derelict.sdl2.image;

		assert(exists(path)); 
		SDL_Surface * s = IMG_Load(path.ptr); 
		
		assert(s); 
		auto texture = createFromSDLSurface(s);
		SDL_FreeSurface(s);
		return texture;
	}
	
	package static Texture createFromSDLSurface(SDL_Surface * s)
	{
		Texture texture = new Texture();
		glPixelStorei(GL_UNPACK_ALIGNMENT, 4); 
		glGenTextures(1, &(texture.glTextureID)); 
		assert(texture.glTextureID > 0); 
		glBindTexture(GL_TEXTURE_2D, texture.glTextureID); 
		
		int mode = GL_RGB; 
		if(s.format.BytesPerPixel == 4) mode=GL_RGBA; 
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);    
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT); 
		
		SDL_Surface * px =  flip(s);
		glTexImage2D(GL_TEXTURE_2D, 0, mode, s.w, s.h, 0, mode, GL_UNSIGNED_BYTE, px.pixels); 
		SDL_FreeSurface(px);
		texture.width = s.w;
		texture.height = s.h;
		return texture;
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
