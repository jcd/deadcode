module graphics.renderwindow;

import dccore.event;
import dccore.log;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import graphics.rendertarget;
import math;
import std.typecons;

import derelict.sdl2.functions;
import derelict.sdl2.types;

RenderWindow[SDL_Window*] g_RenderWindows;

extern (C) SDL_HitTestResult myHitTest(SDL_Window* win, const(SDL_Point)* point, void* userData) nothrow @nogc
{
    RenderWindow w = cast(RenderWindow) userData; // g_RenderWindows[win];
    auto wz = w.systemWindowSize;
    auto pos = w.position;
    // auto area = Rectf(pos.x, pos.y, wz.x, wz.y);
    auto dragArea = Rectf(0, 0, wz.x - 100, 30);
    if (dragArea.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_DRAGGABLE;

    float resizeBorderThinkness = 10f;
    float resizeAreaHalf = 15f;
    Vec2f resizeAreaSize = Vec2f(resizeAreaHalf*2, resizeAreaHalf*2);

    auto bottomRight = Rectf(wz.x - resizeAreaHalf, wz.y - resizeAreaHalf, resizeAreaSize);
    if (bottomRight.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_BOTTOMRIGHT;

    auto topRight = Rectf(wz.x - resizeAreaHalf, -resizeAreaHalf, resizeAreaSize);
    if (topRight.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_TOPRIGHT;

    auto topLeft = Rectf(-resizeAreaHalf, -resizeAreaHalf, resizeAreaSize);
    if (topLeft.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_TOPLEFT;

    auto bottomLeft = Rectf(-resizeAreaHalf, wz.y - resizeAreaHalf, resizeAreaSize);
    if (bottomLeft.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_BOTTOMLEFT;

    auto top = Rectf(0, -resizeBorderThinkness, wz.x, resizeBorderThinkness);
    if (top.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_TOP;

    auto bottom = Rectf(0, wz.y, wz.x, resizeBorderThinkness);
    if (bottom.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_BOTTOM;

    auto left = Rectf(-resizeBorderThinkness, 0, resizeBorderThinkness, wz.y);
    if (left.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_LEFT;

    auto right = Rectf(wz.x, 0, resizeBorderThinkness, wz.y);
    if (right.contains(Vec2f(point.x, point.y)))
        return SDL_HITTEST_RESIZE_RIGHT;

    return SDL_HITTEST_NORMAL;
}

RenderWindow getRenderWindow(SDL_Window* win) nothrow
{
    void* wp = SDL_GetWindowData(win, "RenderWindow");
    RenderWindow* w = cast(RenderWindow*)wp;
    if (w is null)
        return null;
    return *w;
}

extern (C) int eventWatch( void* userData, SDL_Event* e ) nothrow
{
    if( e.type == SDL_WINDOWEVENT && e.window.event == SDL_WINDOWEVENT_RESIZED)
    {
        import gui.gui;
        try
            GUI.the.tick();
        catch (Exception e)
        {}
    }
    return 1; // return 1 so all events are added to queue
}

class RenderWindow : RenderTarget
{
	private
	{
		Vec2i glViewSize;
		SDL_Window *win;
		SDL_GLContext context;
		Mat4f _MVP;
		//EventOutputRange _eventSink;
		//
		//// TODO: make this non-static
		//static FreeList!(Mallocator, __traits(classInstanceSize, MouseMoveEvent)) _mouseMoveEventAllocator;
	}

	override @property uint id() const @nogc nothrow
	{
		return SDL_GetWindowID(cast(SDL_Window*)win);
	}

	this(const(char)[] name, Vec2i sz, EventOutputRange es)
	{
		this(name, sz.x, sz.y, es);
	}

	this(const(char)[] name, int width, int height, EventOutputRange es)
	{
		// _eventSink = es;
		
		glViewSize = Vec2i(width, height);
		SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
		// SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);

		int flags = SDL_WINDOW_OPENGL |SDL_WINDOW_RESIZABLE | SDL_WINDOW_BORDERLESS | SDL_WINDOW_HIDDEN;// |
		/*SDL_WINDOW_MAXIMIZED | SDL_WINDOW_RESIZABLE; */
		win = SDL_CreateWindow(name.ptr, 0, 0, width, height, flags);

        SDL_AddEventWatch( &eventWatch, cast(void*)0);

        version (Windows)
        {
            import derelict.sdl2.sdl;
            import derelict.sdl2.functions;
            //import core.sys.windows.windows;
            import win32.winuser;
            import win32.windef;

            SDL_SysWMinfo info;

            SDL_GetVersion(&info.version_); // this is important!
            if (SDL_GetWindowWMInfo(win, &info))
            {
               DWORD style = GetWindowLongA(info.info.win.window, GWL_STYLE);
               style = style | WS_BORDER | WS_GROUP;
               //style = style & ~WS_THICKFRAME;
	           style = style & ~WS_POPUP;
               SetWindowLongA(info.info.win.window, GWL_STYLE, style);
            }
        }

        //	   	win = SDL_CreateWindow(name.ptr, SDL_WINDOWPOS_CENTERED,
		//SDL_WINDOWPOS_CENTERED, width, height, flags);

		if(!win)
		{
			import std.stdio;
            log.e("Error creating SDL window");
			SDL_Quit();
		}

		context = SDL_GL_CreateContext(win);
		if (context is null)
		{
			import std.stdio;
            log.e("Error creating SDL GL context");
			SDL_Quit();
		}

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
		import std.stdio;
		log.v("GL Context %s", context);
		log.v("Using OpenGL version %s", DerelictGL3.reload());

		Mat4f proj = Mat4f.orthographic(-1,1,-1,1,1,100);
		Mat4f view = Mat4f.makeTranslate(Vec3f(0.0,0.0,10.0f));
		_MVP = proj * view;

		icon();

        //g_RenderWindows[win] = this;
        SDL_SetWindowHitTest(win, &myHitTest, cast(void*)this);
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
		ushort[16*16] pixels = [  // ...or with raw pixel data.
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
		//surface = SDL_CreateRGBSurfaceFrom(pixels.ptr,16,16,16,16*2,0x0f00,0x00f0,0x000f,0xf000);

        import platform.config;
        import derelict.sdl2.image;
        import std.string;

        surface = IMG_Load(resourceURI("icon.png", PathBase.resourceDir).toString().toStringz());

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

		override Vec2f position() const nothrow @nogc
		{
			int x, y;
			SDL_GetWindowPosition(cast(SDL_Window*)win, &x, &y);
			return Vec2f(x, y);
		}

		override void position(Vec2f pos) nothrow
		{
			int x = cast(int)pos.x;
			int y = cast(int)pos.y;
			SDL_SetWindowPosition(win, x, y);
		}

		Vec2i systemWindowSize() const nothrow @nogc
		{
			int x, y;
			SDL_GetWindowSize(cast(SDL_Window*)win, &x, &y);
			return Vec2i(x, y);
		}

		override Vec2i size() const nothrow
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
}
