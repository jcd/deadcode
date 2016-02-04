module graphics.graphicssystem;

import derelict.opengl3.gl3;
import derelict.sdl2.image;
import derelict.sdl2.sdl;
import derelict.sdl2.ttf;

import std.stdio;

interface GraphicsSystem
{
	bool init();
	void destroy();
}

class NullGraphicsSystem : GraphicsSystem
{
	override bool init() { return true; }
	override void destroy() { }
}

class OpenGLSystem : GraphicsSystem
{
	override bool init()
	{
        import dccore.moduleloader;
        import std.exception;

        enforce(ModuleLoader!(DerelictSDL2, "SDL2.dll")().load());
        if (auto e = collectException(DerelictGL3.load()))
        {
			writeln("Error loading GL3 lib ", e);
            return false;
        }

        enforce(ModuleLoaderRaw!("zlib1.dll")().load());
        enforce(ModuleLoaderRaw!("libpng16-16.dll")().load());
        enforce(ModuleLoader!(DerelictSDL2Image, "SDL2_image.dll")().load());
        enforce(ModuleLoaderRaw!("libfreetype-6.dll")().load());
        enforce(ModuleLoader!(DerelictSDL2ttf, "SDL2_ttf.dll")().load());

		if(SDL_Init(SDL_INIT_VIDEO) < 0)
        {
			writefln("Error initializing SDL");
			return false;
		}

		if (TTF_WasInit())
		{
			writeln("TTF was initialized");
		}
		else if (TTF_Init() == -1)
		{
			writeln("Error initializing TTF ", TTF_GetError());
			return false;
		}

		version (none)
		{
			SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
			SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
		}
		version (all)
		{
			SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
			SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
		}
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);

		return true;
	}

	void destroy()
	{
		version (linux)
            writeln("Destroying SDL");
		SDL_Quit();
	}
}
