module platform.display;

import math.rect;

version (Windows)
{
    import std.c.windows.windows;
    extern (Windows)
    {
        nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);
    }

    Rectf getExistingWindowRect()
    {
        auto hwnd = FindWindowA("SDL_app", "Deadcode");
        Rectf result;
        RECT r;
        if (hwnd !is null)
        {
            GetWindowRect(hwnd, &r);
            result = Rectf(r.left, r.top, r.right - r.left, r.bottom - r.top);
        }
        return result;
    }
}

version (linux)
{
    pragma(msg, "Warning: Missing getExistingWindowRect");
    Rectf getExistingWindowRect()
    {
        return Rectf(0,0, 500, 500);
    }
}
