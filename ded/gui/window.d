module gui.window;

import derelict.opengl3.gl3; 
import derelict.sdl2.sdl;
import gui.event;
import gui.keycode;
import math._;
import std.range;
import std.typecons;
import std.stdio;

struct Window
{
	alias void delegate(Event) OnEvent;
	alias void delegate() OnUpdate;
	private struct Impl 
	{
		int width;
		int height;
		bool waitForEvents;
		OnEvent onEvent;
		OnUpdate onUpdate;
		SDL_Window *win; 
		SDL_GLContext context; 
		
		~this()
		{
			if (context)
				SDL_GL_DeleteContext(context); 
			if (win)
				SDL_DestroyWindow(win); 
		}
	}
	
	RefCounted!(Impl) p;
	
	static Window active;
	
	Mat4f MVP;
	
	@property void waitForEvents(bool v)
	{
		p.waitForEvents = v;
	}
	
	@property void onEvent(OnEvent callback)
	{
		p.onEvent = callback;
	}
	
	@property void onUpdate(OnUpdate callback)
	{
		p.onUpdate = callback;
	}
	
	this(const(char)[] name, int width, int height)
	{
		p = RefCounted!(Impl,RefCountedAutoInitialize.no)(width, height);
		
		int flags = SDL_WINDOW_OPENGL | SDL_WINDOW_BORDERLESS | SDL_WINDOW_SHOWN;// |
		/*SDL_WINDOW_MAXIMIZED | SDL_WINDOW_RESIZABLE; */
		p.win = SDL_CreateWindow(name.ptr, 0, 0, width, height, flags); 
		//	   	p.win = SDL_CreateWindow(name.ptr, SDL_WINDOWPOS_CENTERED, 
		//SDL_WINDOWPOS_CENTERED, width, height, flags); 
		
		if(!p.win)
		{ 
			writefln("Error creating SDL window"); 
			SDL_Quit();
		} 
		
		p.context = SDL_GL_CreateContext(p.win); 
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
		MVP = proj * view;
		
		// If there is no active window yet then activate this
		if (!Window.active.p.refCountedStore().isInitialized)
			active = this;
		
		SDL_StartTextInput();		
		icon();
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
		
		
		
		SDL_SetWindowIcon(p.win, surface); 
		// The icon is attached to the window pointer
		
		
		// ...and the surface containing the icon pixel data is no longer required.
		SDL_FreeSurface(surface);	
	}
	
	bool update()
	{
		glDepthMask(GL_TRUE);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); 
		bool running = true;
		SDL_Event e; 
		if (p.waitForEvents)
			SDL_WaitEvent(&e);
		else
			SDL_PollEvent(&e);
		do { 
			Event ev;
			switch(e.type) { 
				case SDL_MOUSEMOTION:
					ev.type = Event.Type.MouseMove;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mousePosRel.x = e.motion.xrel;
					ev.mousePosRel.y = e.motion.yrel;
					ev.mouseButtonsActive = e.motion.state;
					break;				
				case SDL_MOUSEBUTTONDOWN:
					ev.type = Event.Type.MouseDown;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mouseButtonsActive = e.button.state;
					ev.mouseButtonsChanged = e.button.button;
					break;
				case SDL_MOUSEBUTTONUP:
					ev.type = Event.Type.MouseUp;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mouseButtonsActive = e.button.state;
					ev.mouseButtonsChanged = e.button.button;
					break;
				case SDL_MOUSEWHEEL:
					ev.type = Event.Type.MouseScroll;
					ev.scroll = Vec2f(e.wheel.x, e.wheel.y);
					break;
				case SDL_KEYDOWN:
					if (e.key.keysym.sym == SDLK_ESCAPE)
						running = false;
					ev.type = Event.Type.KeyDown;
					ev.keyCode = e.key.keysym.sym;
					ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev.mod = cast(KeyMod)SDL_GetModState();
					//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
					break;
				case SDL_KEYUP:
					if (e.key.keysym.sym == SDLK_ESCAPE)
						running = false;
					ev.type = Event.Type.KeyUp;
					ev.keyCode = e.key.keysym.sym;
					ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev.mod = cast(KeyMod)SDL_GetModState();
					//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
					break;
				case SDL_TEXTINPUT:
					//std.stdio.writeln(e.text.text);
					char[] ch = cast(char[])e.text.text;
					//size_t st = std.utf.stride(ch, 0);
					ev.type = Event.Type.Text;
					ev.ch = ch.front;
					ev.mod = cast(KeyMod)SDL_GetModState();
					break;
				case SDL_WINDOWEVENT:
					switch (e.window.event)
					{
						case SDL_WINDOWEVENT_SIZE_CHANGED:
						case SDL_WINDOWEVENT_RESIZED:
							size = Vec2f(e.window.data1, e.window.data2);
							break;
						default:
							break;
					}
					break;
				default:  
					break; 
			}
			
			if (p.onEvent)
				p.onEvent(ev);
			
		} while (SDL_PollEvent(&e));
		
		if (p.onUpdate)
			p.onUpdate();
		
		SDL_GL_SwapWindow(p.win); 
		return running;
	}
	
	void run()
	{
		Event ev;
		ev.type = Event.Type.Resize;
		ev.width = width;
		ev.height = height;
		p.onEvent(ev);
		
		while(update()) { };
	}
	
	@property 
	{
		Vec2f position() const
		{
			int x, y;
			SDL_GetWindowPosition(cast(SDL_Window*)p.win, &x, &y);
			return Vec2f(x, y);
		}
		
		void position(Vec2f pos)
		{
			int x = cast(int)pos.x;
			int y = cast(int)pos.y;
			SDL_SetWindowPosition(p.win, x, y);
		}
	}	
	
	@property 
	{
		Vec2f size() const
		{
			int x, y;
			SDL_GetWindowSize(cast(SDL_Window*)p.win, &x, &y);
			return Vec2f(x, y);
		}
		
		void size(Vec2f s)
		{			
			int x = cast(int)s.x;
			int y = cast(int)s.y;
			if (p.width != x || p.height != y)
			{				
				p.width = x;
				p.height = y;
				glViewport(0, 0, x, y);
				
				Event ev;
				ev.type = Event.Type.Resize;
				ev.width = x;
				ev.height = y;
				p.onEvent(ev);	
				
				SDL_SetWindowSize(p.win, x, y);
			}
		}
	}
	
	@property int width() const 
	{
		return p.width;
	}
	
	@property int height() const 
	{
		return p.height;
	}
	
	@property 
	{
		bool maximized() const
		{
			auto v = SDL_GetWindowFlags(cast(SDL_Window*)p.win);
			return (v & SDL_WINDOW_MAXIMIZED) != 0;
		}
		
		void maximized(bool v)
		{
			if (v)
			{
				SDL_MaximizeWindow(p.win);
			}
			//SDL_MinimizeWindow(p.win);
		}
	}
	
	/** Convert a size in pixels to a size in world coordinate at z = 0
	 */
	import math.smallvector;
	Vec2f pixelSizeToWorld(SmallVector!(2u,float) pixels)
	{
		pixels.x /= width * 0.5f;
		pixels.y /= height * 0.5f;
		return pixels;
	}
	
	/// ditto
	float pixelWidthToWorld(float x)
	{
		x /= width * 0.5f; 
		return x;
	}
	
	/// ditto
	float pixelHeightToWorld(float y)
	{
		y /= height * 0.5f;
		return y;
	}
	
	/** Window pixel coordinate to world coordinate at z = 0
	 */
	Vec3f windowToWorld(float x, float y)
	{
		// world goes from (-1,-1) to (1,1)
		return Vec3f(2f * x / width - 1f, -2f * y / height + 1f, 0f);
	}
	
	/// ditto
	Vec3f windowToWorld(Vec2f src)
	{
		return windowToWorld(src.x, src.y);
	}
	
	/** Window pixel coordinate to world coordinate at z = 0
	 */
	Rectf windowToWorld(float x1, float y1, float x2, float y2)
	{
		// world goes from (-1,-1) to (1,1)
		Vec3f pTopLeft = windowToWorld(x1, y1);
		Vec3f pLowRight = windowToWorld(x2, y2); 
		auto r = Rectf(pTopLeft.x, pTopLeft.y, 0, 0);
		r.x2 = pLowRight.x;
		r.y2 = pLowRight.y;
		return r;
	}
	
	Rectf windowToWorld(Rectf r)
	{
		return windowToWorld(r.x, r.y, r.x2, r.y2);
	}
	
	/** World coordinate (ignoring z) to window pixel coordinate
	 */ 
	Vec2f worldToWindow(Vec3f src)
	{
		// world goes from (-1,-1) to (1,1)
		return Vec2f(( 0.5f * src.x + 0.5f) * width, ( 0.5f * src.y - 0.5f) * height);
	}
}
