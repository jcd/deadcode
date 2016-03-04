module platform.cursor;

import math.smallvector;

version (Windows)
{
    import core.sys.windows.windows;

    struct CURSORINFO {
        DWORD   cbSize;
        DWORD   flags;
        HCURSOR hCursor;
        POINT   ptScreenPos;
    };
    alias CURSORINFO* PCURSORINFO, NPCURSORINFO, LPCURSORINFO;

    extern (Windows) nothrow
    {
        export BOOL GetCursorInfo(LPCURSORINFO lpPoint);
        export BOOL GetCursorPos(
                                 LPPOINT lpPoint
                                 );
    }

    bool getScreenPosition(Vec2f* result)
    {
/*
        CURSORINFO desktopPos;
        desktopPos.cbSize = CURSORINFO.sizeof;
        if (! GetCursorInfo(&desktopPos))
        {
            std.stdio.writeln("errocode ", GetLastError());
        }
        Vec2f winPos = Vec2f(desktopPos.ptScreenPos.x, desktopPos.ptScreenPos.y);
*/

//        POINT p;
//        GetCursorPos(&p);
//        *result = Vec2f(p.x, p.y);
//        return true;
        /** When SDL2 2.0.4 is released the GetGlobalMouseState will be supported */
        import derelict.sdl2.sdl;
        int x,y;
        SDL_GetGlobalMouseState(&x, &y);
        *result = Vec2f(x, y);
		return true;
    }
}

version (linux)
{
    import derelict.sdl2.sdl;   
    bool getScreenPosition(Vec2f* result)
    {
        import x11.Xlib;
        import x11.X;
        
        Window root;
        Window child;
        int root_x, root_y;
        int win_x, win_y;
        uint mask_return; 

        Display *display = XOpenDisplay(null);
        scope (exit) XCloseDisplay(display);

//        Display *display = cast(Display*)info.info.x11.display;
        assert(display);
        // XSetErrorHandler(_XlibErrorHandler);
        int number_of_screens = XScreenCount(display);
        // fprintf(stderr, "There are %d screens available in this X session\n", number_of_screens);
        for (int i = 0; i < number_of_screens; i++) {
            Window win = XRootWindow(display, i);
            Bool res = XQueryPointer(display, win, &root,
                    &child, &root_x, &root_y, &win_x, &win_y,
                    &mask_return);
            if (res == True) {
                XWindowAttributes root_attrs;
                XGetWindowAttributes(display, root, &root_attrs);
                result.x = root_attrs.x + root_x;
                result.y = root_attrs.y + root_y;
                return true;
            }
        }
        return false;
    }
}
