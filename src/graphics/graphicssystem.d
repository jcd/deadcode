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
		try{ 
			DerelictSDL2.load(); 
		}catch(Exception e){ 
			writeln("Error loading SDL2 lib ", e); 
			return false; 
		} 
		try{ 
			DerelictGL3.load(); 
		}catch(Exception e){ 
			writeln("Error loading GL3 lib ", e); 
			return false; 
		} 
		try{ 
			DerelictSDL2Image.load(); 
		}catch(Exception e){ 
			writeln("Error loading SDL image lib ", e); 
			return false; 
		} 
		try{  
			DerelictSDL2ttf.load(); 
		}catch(Exception e){ 
			writeln("Error loading TTF lib ", e); 
			return false; 
		} 
		
		
		if(SDL_Init(SDL_INIT_VIDEO) < 0){ 
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
		
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3); 
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2); 
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1); 
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16); 
		
		return true; 
	}
	
	void destroy()
	{
		writeln("Destroying SDL");
		SDL_Quit(); 
	}
}
