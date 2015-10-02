module graphics.renderwindow;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import graphics.rendertarget;
import math;
import std.typecons;

version (Windows)
{
    bool isGrabbing = false;
    import win32.winuser;
    import std.c.windows.windows;
    LONG_PTR g_OrigWinProc;

    extern (Windows) int myWinProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        //if (isGrabbing)
        //{
        //    switch (uMsg)
        //    {
        //    case win32.winuser.WM_NCHITTEST:f
        //        return HTCAPTION;
        //    case win32.winuser.WM_LBUTTONUP:
        //       // isGrabbing = false;
        //        break;
        //    case win32.winuser.WM_NCLBUTTONUP:
        //        //isGrabbing = false;
        //        break;
        //    default:
        //        break;
        //    }
        //}
            static int k = 0;
            switch (uMsg)
            {
            case win32.winuser.WM_SIZE:
              import gui.gui;
                //if (GUI.the !is null)
                //    GUI.the.tick();
                break;
            default:
                break;
            }

        return CallWindowProc(cast(win32.winuser.WNDPROC)g_OrigWinProc, hWnd, uMsg, wParam, lParam);
    }
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

import derelict.sdl2.functions;
import derelict.sdl2.types;

RenderWindow[SDL_Window*] g_RenderWindows;

extern (C) SDL_HitTestResult myHitTest(SDL_Window* win, const(SDL_Point)* point, void*) nothrow
{
    RenderWindow w = g_RenderWindows[win];
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

class RenderWindow : RenderTarget
{
	private
	{
		Vec2i glViewSize;
		SDL_Window *win;
		SDL_GLContext context;
		Mat4f _MVP;
	}

	override @property uint id() const
	{
		return SDL_GetWindowID(cast(SDL_Window*)win);
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

		int flags = SDL_WINDOW_OPENGL |SDL_WINDOW_RESIZABLE | SDL_WINDOW_BORDERLESS | SDL_WINDOW_HIDDEN;// |
		/*SDL_WINDOW_MAXIMIZED | SDL_WINDOW_RESIZABLE; */
		win = SDL_CreateWindow(name.ptr, 0, 0, width, height, flags);
		//	   	win = SDL_CreateWindow(name.ptr, SDL_WINDOWPOS_CENTERED,
		//SDL_WINDOWPOS_CENTERED, width, height, flags);

        SDL_AddEventWatch( &eventWatch, cast(void*)0);

        if(!win)
		{
			import std.stdio;
            writeln("Error creating SDL window");
			SDL_Quit();
		}

        version (none)
        {
            //import std.c.windows.windows;
            import win32.winuser;
            import derelict.sdl2.types;
            SDL_SysWMinfo wminfo;
            SDL_VERSION(&wminfo.version_);
            SDL_GetWindowWMInfo(win, &wminfo);
            g_OrigWinProc = GetWindowLongPtr(wminfo.info.win.window, GWLP_WNDPROC);
            SetWindowLongPtr(wminfo.info.win.window, GWLP_WNDPROC, cast(LONG_PTR) &myWinProc);
        }

		context = SDL_GL_CreateContext(win);
		if (context is null)
		{
			import std.stdio;
            writeln("Error creating SDL GL context");
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
		writeln("GL Context ", context);
		writeln("Using OpenGL version ", DerelictGL3.reload());

		Mat4f proj = Mat4f.orthographic(-1,1,-1,1,1,100);
		Mat4f view = Mat4f.makeTranslate(Vec3f(0.0,0.0,10.0f));
		_MVP = proj * view;

		icon();

        g_RenderWindows[win] = this;
        SDL_SetWindowHitTest(win, &myHitTest, cast(void*)null);
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
        import platform.config;
        import derelict.sdl2.image;
        import std.string;

        SDL_Surface* surface = IMG_Load(resourceURI("icon.png", ResourceBaseLocation.resourceDir).toString().toStringz());
        SDL_SetWindowIcon(win, surface);
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

		override Vec2f position() const nothrow
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

		Vec2i systemWindowSize() const nothrow
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
