module platform.display;

import math.rect;

version (Windows)
{
    import core.sys.windows.windows;

    extern (Windows)
    {
        nothrow export HWND FindWindowA(LPCTSTR className, LPCTSTR windowName);
    }

    bool getExistingWindowRect(Rectf* result)
    {
        auto hwnd = FindWindowA("SDL_app", "Deadcode");
        RECT r;
        if (hwnd !is null)
        {
            GetWindowRect(hwnd, &r);
            *result = Rectf(r.left, r.top, r.right - r.left, r.bottom - r.top);
            return true;
        }
        return false;
    }
}

version (linux)
{
    import derelict.sdl2.sdl;  
    bool getExistingWindowRect(Rectf* result)
    {
		import std.algorithm;
        import x11.Xatom;
        import x11.Xlib;
        import x11.X;
        
        Display *display = XOpenDisplay(null);
        scope (exit) XCloseDisplay(display);
        assert(display);
        Atom prop = XInternAtom(display,"WM_NAME",True);
   
        bool _get(Window w)
        { 
            // Get the PID for the current Window.
        	ulong           type;
        	int            format;
        	ulong  nItems;
        	ulong  bytesAfter;
        	ubyte *propValue = null;
        	if(XErrorCode.Success == XGetWindowProperty(display, w, prop, 0L, 1024L, False, XA_STRING,
        	                                 &type, &format, &nItems, &bytesAfter, &propValue))
        	{
        		if(propValue !is null) 
        		{
        		    static import core.stdc.string;
        		    auto l = core.stdc.string.strlen(cast(char*)propValue);
        		    string name = (cast(char*)propValue)[0..l].idup;
        		    import std.stdio;
        		    writeln("Name : ", name);
        			XFree(propValue);
                    if (name.endsWith("deadcode"))
                    {
            		    XWindowAttributes xwa;
                        XGetWindowAttributes(display, w, &xwa);
                        result.x = xwa.x;
                        result.y = xwa.y;
                        result.w = xwa.width;
                        result.h = xwa.height;
	                    writeln("Found deadcode at", *result); 
                        return true;
                    }
        		}
        	}
        	
            // Recurse into child windows.
        	Window    wRoot;
        	Window    wParent;
        	Window   *wChild;
        	uint  nChildren;
        	if(0 != XQueryTree(display, w, &wRoot, &wParent, &wChild, &nChildren))
        	{
        		for(uint i = 0; i < nChildren; i++)
        			if (_get(wChild[i]))
        			    return true;
        	}
        
            return false;
        }
        return _get(XDefaultRootWindow(display));
    }
}
