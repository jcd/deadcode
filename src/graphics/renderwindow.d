module graphics.renderwindow;

import derelict.opengl3.gl3; 
import derelict.sdl2.sdl;

import graphics.rendertarget;
import math._;
import std.typecons;

class RenderWindow : RenderTarget
{
	private
	{
		Vec2i glViewSize;
		SDL_Window *win; 
		SDL_GLContext context; 
		Mat4f _MVP;
	}

	@property Uint32 id() 
	{
		return SDL_GetWindowID(win);
	}

	this(const(char)[] name, Vec2i sz)
	{
		this(name, sz.x, sz.y);
	}
	
	this(const(char)[] name, int width, int height)
	{
		glViewSize = Vec2i(width, height);
		SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
		// SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
		
		int flags = SDL_WINDOW_OPENGL | SDL_WINDOW_BORDERLESS | SDL_WINDOW_SHOWN;// |
		/*SDL_WINDOW_MAXIMIZED | SDL_WINDOW_RESIZABLE; */
		win = SDL_CreateWindow(name.ptr, 0, 0, width, height, flags); 
		//	   	win = SDL_CreateWindow(name.ptr, SDL_WINDOWPOS_CENTERED, 
		//SDL_WINDOWPOS_CENTERED, width, height, flags); 
		
		if(!win)
		{ 
			std.stdio.writefln("Error creating SDL window"); 
			SDL_Quit();
		} 
		
		context = SDL_GL_CreateContext(win); 

		SDL_GL_SetSwapInterval(1); 
		glClearColor(0.0, 0.0, 0.0, 1.0); 
		glViewport(0, 0, width, height); 
		glEnable(GL_DEPTH_TEST);
		glDepthFunc(GL_LEQUAL);
		glClearDepth(1.0);
		auto aspect = cast(double)width / cast(double)height;
		/*
		glMatrixMode( GL_PROJECTION );
		glLoadIdentity(); 
		glFrustum(-near_height * aspect, 
		   near_height * aspect, 
		   -near_height,
		   near_height, zNear, zFar );	
*/	
		
		DerelictGL3.reload(); 

		Mat4f proj = Mat4f.orthographic(-1,1,-1,1,1,100);
		Mat4f view = Mat4f.makeTranslate(Vec3f(0.0,0.0,10.0f));
		_MVP = proj * view;
		
		icon();
	}

	~this()
	{
		if (context)
			SDL_GL_DeleteContext(context); 
		if (win)
			SDL_DestroyWindow(win);
	}

	void icon()
	{
		// TODO: read from file
		SDL_Surface *surface;     // Declare an SDL_Surface to be filled in with pixel data from an image file
		ushort pixels[16*16] = [  // ...or with raw pixel data.
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0aab, 0x0789, 0x0bcc, 0x0eee, 0x09aa, 0x099a, 0x0ddd, 
			0x0fff, 0x0eee, 0x0899, 0x0fff, 0x0fff, 0x1fff, 0x0dde, 0x0dee, 
			0x0fff, 0xabbc, 0xf779, 0x8cdd, 0x3fff, 0x9bbc, 0xaaab, 0x6fff, 
			0x0fff, 0x3fff, 0xbaab, 0x0fff, 0x0fff, 0x6689, 0x6fff, 0x0dee, 
			0xe678, 0xf134, 0x8abb, 0xf235, 0xf678, 0xf013, 0xf568, 0xf001, 
			0xd889, 0x7abc, 0xf001, 0x0fff, 0x0fff, 0x0bcc, 0x9124, 0x5fff, 
			0xf124, 0xf356, 0x3eee, 0x0fff, 0x7bbc, 0xf124, 0x0789, 0x2fff, 
			0xf002, 0xd789, 0xf024, 0x0fff, 0x0fff, 0x0002, 0x0134, 0xd79a, 
			0x1fff, 0xf023, 0xf000, 0xf124, 0xc99a, 0xf024, 0x0567, 0x0fff, 
			0xf002, 0xe678, 0xf013, 0x0fff, 0x0ddd, 0x0fff, 0x0fff, 0xb689, 
			0x8abb, 0x0fff, 0x0fff, 0xf001, 0xf235, 0xf013, 0x0fff, 0xd789, 
			0xf002, 0x9899, 0xf001, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0xe789, 
			0xf023, 0xf000, 0xf001, 0xe456, 0x8bcc, 0xf013, 0xf002, 0xf012, 
			0x1767, 0x5aaa, 0xf013, 0xf001, 0xf000, 0x0fff, 0x7fff, 0xf124, 
			0x0fff, 0x089a, 0x0578, 0x0fff, 0x089a, 0x0013, 0x0245, 0x0eff, 
			0x0223, 0x0dde, 0x0135, 0x0789, 0x0ddd, 0xbbbc, 0xf346, 0x0467, 
			0x0fff, 0x4eee, 0x3ddd, 0x0edd, 0x0dee, 0x0fff, 0x0fff, 0x0dee, 
			0x0def, 0x08ab, 0x0fff, 0x7fff, 0xfabc, 0xf356, 0x0457, 0x0467, 
			0x0fff, 0x0bcd, 0x4bde, 0x9bcc, 0x8dee, 0x8eff, 0x8fff, 0x9fff, 
			0xadee, 0xeccd, 0xf689, 0xc357, 0x2356, 0x0356, 0x0467, 0x0467, 
			0x0fff, 0x0ccd, 0x0bdd, 0x0cdd, 0x0aaa, 0x2234, 0x4135, 0x4346, 
			0x5356, 0x2246, 0x0346, 0x0356, 0x0467, 0x0356, 0x0467, 0x0467, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
			0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff 
		]; 
		surface = SDL_CreateRGBSurfaceFrom(pixels.ptr,16,16,16,16*2,0x0f00,0x00f0,0x000f,0xf000);
		SDL_SetWindowIcon(win, surface); 
		// The icon is attached to the window pointer

		// ...and the surface containing the icon pixel data is no longer required.
		SDL_FreeSurface(surface);	
	}
	
	override void render(bool _swapBuffers = true)
	{
		glDepthMask(GL_TRUE);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); 

		if (_onRender !is null)
			_onRender();
		
		if (_swapBuffers)
			swapBuffers();
	}

	override void swapBuffers()
	{
		///glFlush();
		//glFinish();
		SDL_GL_SwapWindow(win); 
	}

	@property 
	{
		override Mat4f MVP() const
		{
			return _MVP;
		}

		override Vec2f position() const
		{
			int x, y;
			SDL_GetWindowPosition(cast(SDL_Window*)win, &x, &y);
			return Vec2f(x, y);
		}
		
		override void position(Vec2f pos)
		{
			int x = cast(int)pos.x;
			int y = cast(int)pos.y;
			SDL_SetWindowPosition(win, x, y);
		}

		Vec2i systemWindowSize() const
		{
			int x, y;
			SDL_GetWindowSize(cast(SDL_Window*)win, &x, &y);
			return Vec2i(x, y);
		}

		override Vec2i size() const
		{
			return Vec2i(glViewSize.x, glViewSize.y);
		}
		
		override void size(Vec2f s)
		{			
			size = Vec2i(cast(int)s.x, cast(int)s.y);
		}
		
		override void size(Vec2i s)
		{			
			Vec2i curSize = this.size;
			if (curSize.x != s.x || curSize.y != s.y)
			{				
				glViewSize = s;
				glViewport(0, 0, s.x, s.y);
				SDL_SetWindowSize(win, s.x, s.y);
			}
		}

		bool maximized() const
		{
			auto v = SDL_GetWindowFlags(cast(SDL_Window*)win);
			return (v & SDL_WINDOW_MAXIMIZED) != 0;
		}
		
		void maximized(bool v)
		{
			if (v)
			{
				SDL_MaximizeWindow(win);
			}
			//SDL_MinimizeWindow(win);
		}
	}
	
	/** Convert a size in pixels to a size in world coordinate at z = 0
	 */
	override Vec2f pixelSizeToWorld(Vec2f pixels)
	{
		Vec2i s = size;
		pixels.x /= s.x * 0.5f;
		pixels.y /= s.y * 0.5f;
		return pixels;
	}

	/** Convert a size in pixels to a size in world coordinate at z = 0
	 */
	override Vec2f worldSizeToPixel(Vec2f worldUnits)
	{
		Vec2i s = size;
		worldUnits *= 0.5f;
		return Vec2f(s.x * worldUnits.x, s.y * -worldUnits.y);
	}
	
	/// ditto
	override float pixelWidthToWorld(float x)
	{
		x /= size.x * 0.5f; 
		return x;
	}
	
	/// ditto
	override float pixelHeightToWorld(float y)
	{
		y /= size.y * 0.5f;
		return y;
	}
	
	/** Window pixel coordinate to world coordinate at z = 0
	 */
	Vec2f windowToWorld(float x, float y)
	{
		// world goes from (-1,-1) to (1,1)
		Vec2i s = size;
		return Vec2f(2f * x / s.x - 1f, -2f * y / s.y + 1f);
	}
	
	/// ditto
	Vec2f windowToWorld(Vec2f src)
	{
		return windowToWorld(src.x, src.y);
	}
	
	/** Window pixel coordinate to world coordinate at z = 0
	 */
	Rectf windowToWorld(float x1, float y1, float x2, float y2)
	{
		// world goes from (-1,-1) to (1,1)
		Vec2f pTopLeft = windowToWorld(x1, y1);
		Vec2f pLowRight = windowToWorld(x2, y2); 
		auto r = Rectf(pTopLeft.x, pTopLeft.y, 0, 0);
		r.x2 = pLowRight.x;
		r.y2 = pLowRight.y;
		return r;
	}
	
	override Rectf windowToWorld(Rectf r)
	{
		return windowToWorld(r.x, r.y, r.x2, r.y2);
	}
	
	/** World coordinate (ignoring z) to window pixel coordinate
	 */ 
	override Vec2f worldToPixelPos(Vec2f src)
	{
		// world goes from (-1,-1) to (1,1)
		Vec2i s = size;
		return Vec2f(( 0.5f * src.x + 0.5f) * s.x, ( 0.5f * -src.y + 0.5f) * s.y);
	}

	override Rectf worldToWindow(Rectf r)
	{
		Vec2f winPos = worldToPixelPos(r.pos);
		Vec2f winSize = worldSizeToPixel(r.size);
		return Rectf(winPos, winSize);
	}

}
