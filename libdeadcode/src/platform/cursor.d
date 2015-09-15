module platform.cursor;

import math.smallvector;

version (Windows)
{
    import std.c.windows.windows;

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

    Vec2f getScreenPosition()
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

        POINT p;
        GetCursorPos(&p);
        Vec2f winPos = Vec2f(p.x, p.y);

        /** When SDL2 2.0.4 is released the GetGlobalMouseState will be supported
        import derelict.sdl2.sdl;
        int x,y;
        SDL_GetGlobalMouseState(&x, &y);
        Vec2f winPos = Vec2f(x, y);
*/
        return winPos;
    }
}

version (linux)
{
    Vec2f getScreenPosition()
    {
        pragma(msg, "Warning: getScreenPosition not implemented for linux");
        return Vec2f();
    }
}
