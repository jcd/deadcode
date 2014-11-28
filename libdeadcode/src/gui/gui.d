module gui.gui;

import animation.timeline;
import core.command;
import core.time;
import gui._;
import gui.locations;
import gui.resources;
import io.iomanager;
import math._; // Vec2f
import derelict.sdl2.sdl; 
import std.range;
import std.signals;

class GUI
{
	private
	{
		bool running;
		Window[WindowID] _windows;
		graphics.graphicssystem.GraphicsSystem _graphicsSystem;
		EventQueue _eventQueue;
		Uint32 _lastTick;
		Uint32 _lastScrollTick;

		class Timeout 
		{
			bool done;
			int msLeft;
			abstract bool onTimeout();
		}

		class FnTimeout(Fn, Args...) : Timeout
		{
			Fn fn;
			Args args;
			int msInit;

			this(int ms, Fn f, Args a)
			{
				done = false;
				msLeft = ms;
				msInit = ms;
				fn = f;
				args = a;
			}

			override bool onTimeout()
			{
				if (fn(args))
				{
					msLeft = msInit;
					return true;
				}
				done = true;
				return false;
			}
		}
		Timeout[] _timeouts;

		// not singleton as in global variable, but just here to prevent 
		// two instances of application because opengl init doesn't
		// like that.
		// static GUI _the; // assert only singleton
	}

	bool waitForEvents;
	Timeline timeline;
	Window activeWindow;

	IOManager ioManager;
	LocationsManager locationsManager;

	TextureManager textureManager;
	ShaderProgramManager shaderProgramManager;
	MaterialManager materialManager;
	FontManager fontManager;
	StyleSheetManager styleSheetManager;
	GenericResourceManager genericResourceManager;

	KeyMod keyMod;

	mixin Signal!string onFileDropped;

	/*
	static @property GUI the()
	{
		assert(_the !is null);
		return _the;
	}
*/

	static GUI create(graphics.graphicssystem.GraphicsSystem gs = null)
	{
		import util.system;
		import gui.resources;
		auto g = new GUI(gs is null ? new graphics.graphicssystem.OpenGLSystem() : gs);

		g.ioManager = new io.iomanager.IOManager;
		// g.ioManager.add(new io.iomanager.ScanProtocol);
		g.ioManager.add(new io.file.FileProtocol);
		//io.add(new io.Http);

		g.locationsManager = LocationsManager.create(g.ioManager);
		g.fontManager = FontManager.create(g.ioManager);
		g.shaderProgramManager = ShaderProgramManager.create(g.ioManager);
		g.textureManager = TextureManager.create(g.ioManager);
		g.materialManager = MaterialManager.create(g.ioManager, g.shaderProgramManager, g.textureManager);
		
		g.styleSheetManager = StyleSheetManager.create(g.ioManager, g.materialManager, g.fontManager);
		g.genericResourceManager = GenericResourceManager.create(g.ioManager);

		g.locationsManager.addListener(g.fontManager);
		g.locationsManager.addListener(g.shaderProgramManager);
		g.locationsManager.addListener(g.textureManager);
		g.locationsManager.addListener(g.materialManager);
		g.locationsManager.addListener(g.styleSheetManager); 

		return g;

		//locs.declare("file://foobar/lars/*");


		// Setup builtin stuff

		// TODO: Scan resoures folder to a file list. Then go through all files with each manager
		//       and let them decide what to manage.
		// TODO: Make a resource config file. Contains folders to scan and urls to look into for resources.

	}

	this(graphics.graphicssystem.GraphicsSystem gs)
	{
		// _the = this;
		_graphicsSystem = gs;
		_eventQueue = new EventQueue();
		timeline = new Timeline;
	}
	
	~this()
	{
		running = false;
		_graphicsSystem.destroy();
	}
	
	void init()
	{
		assert(!running);
		timeline.start();
		std.exception.enforceEx!Exception(_graphicsSystem.init(), "Error initializing graphics");
		_lastTick = SDL_GetTicks();
		SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
		SDL_StartTextInput();
		running = true;
	}
	
	void run()
	{
		import std.datetime;

		if (!running)
			init();

		int ticks = 0;
		SysTime t = Clock.currTime();
		while (running)
		{
			tick();
			if (ticks-- <= 0)
			{
				ticks = 100;
				SysTime t2 = Clock.currTime();
				Duration d = t2 - t;
				t = t2;
				double secs = cast(double)d.total!"hnsecs" * 0.0000001;
				std.stdio.writeln(std.conv.text("FPS ", 100.0 / secs));
			}
		}
	}

	void stop()
	{
		running = false;
	}

	void timeout(Fn, Args...)(Duration d, Fn fn, Args args)
	{
		_timeouts ~= new FnTimeout!(Fn,Args)(cast(int)d.total!"msecs", fn, args);
	}

	void tick()
	{
	
		assert(running);
		
		// TODO: handle multiple windows
		auto waitForEvents = !timeline.hasPendingAnimation;
		handleEvents(waitForEvents);
		timeline.update();

		foreach (k, v; _windows)
		{
			v.update();
		}

		foreach (k, v; _windows)
		{
			// TODO: cull hidden windows
			// TODO: fix double drawing of widgets because the are all drawn here and some of them
			// as children of window as well
			// if (v.parent is v.window)
				v.draw();
		}
	}
		
	private void handleEvents(bool waitForEvents)
	{
		Uint32 curTick = SDL_GetTicks();
		int msPassed = cast(int) curTick - _lastTick;
		_lastTick = curTick;

		// Make sure we make progress no matter what
		if (msPassed == 0)
			msPassed = 1;

		int smallestTimeout = std.algorithm.max(_timeouts.empty ? int.max : _timeouts[0].msLeft - msPassed, 0);
		int numTimedOut = 0;
		bool timedOutThisTick = false;

		foreach (ref t; _timeouts)
		{
			t.msLeft -= msPassed;
			if (t.msLeft <= 0)
			{
				bool tTimedOutThisTick = !t.done;
				if (tTimedOutThisTick)
				{
					timedOutThisTick = true;
					if (t.onTimeout())
					{
						if (smallestTimeout > t.msLeft)
							smallestTimeout = t.msLeft;
					}
				}
				numTimedOut++;
			}
			else if (smallestTimeout > t.msLeft)
			{
					smallestTimeout = t.msLeft;
			}
		}
		
		// Rebuild timeout list when there are too many dead entries
		if (numTimedOut > 10)
		{
			Timeout[] to;
			foreach (ref t; _timeouts)
				if (!t.done)
					to ~= t;
		}

		SDL_Event e; 
		int pollResult = 0;
		if (waitForEvents && _eventQueue.empty && !timedOutThisTick)
		{
			if (smallestTimeout != int.max)
				pollResult = SDL_WaitEventTimeout(&e, smallestTimeout);
			else
				pollResult = SDL_WaitEvent(&e);
		}
		else
		{
			pollResult = SDL_PollEvent(&e);
		}
		
		int count = 10;


		do {
			Event queuedEvent = _eventQueue.dequeue();
			while (queuedEvent.type != EventType.Invalid)
			{
				dispatchEvent(queuedEvent);
				queuedEvent = _eventQueue.dequeue();
			}
			
			if (!pollResult)
				break;
			
			Event ev;
			ev.timestamp = e.common.timestamp;
			switch(e.type) { 
				case SDL_MOUSEMOTION:
					ev.type = EventType.MouseMove;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mousePosRel.x = e.motion.xrel;
					ev.mousePosRel.y = e.motion.yrel;
					ev.mouseButtonsActive = e.motion.state;
					ev.windowID = e.motion.windowID;
					break;				
				case SDL_MOUSEBUTTONDOWN:
					ev.type = EventType.MouseDown;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mouseButtonsActive = e.button.state;
					ev.mouseButtonsChanged = e.button.button;
					ev.windowID = e.button.windowID;
					keyMod = cast(KeyMod)SDL_GetModState();
					ev.mouseMod = keyMod;
					break;
				case SDL_MOUSEBUTTONUP:
					ev.type = EventType.MouseUp;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mouseButtonsActive = e.button.state;
					ev.mouseButtonsChanged = e.button.button;
					ev.windowID = e.button.windowID;
					keyMod = cast(KeyMod)SDL_GetModState();
					ev.mouseMod = keyMod;
					break;
				case SDL_MOUSEWHEEL:
					ev.type = EventType.MouseScroll;
					ev.scroll = Vec2f(e.wheel.x, e.wheel.y);
					keyMod = cast(KeyMod)SDL_GetModState();
					ev.scrollMod = keyMod;
					if (_lastScrollTick == 0)
						ev.msSinceLastScroll = Uint32.max;
					else
						ev.msSinceLastScroll = ev.timestamp - _lastScrollTick;
					_lastScrollTick = ev.timestamp;
					ev.windowID = e.wheel.windowID;
					break;
				case SDL_KEYDOWN:
					//if (e.key.keysym.sym == SDLK_ESCAPE)
					//    running = false;
					ev.type = EventType.KeyDown;
					ev.keyCode = e.key.keysym.sym;
					ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					keyMod = cast(KeyMod)SDL_GetModState();
					ev.mod = keyMod;
					ev.windowID = e.key.windowID;
					//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
					break;
				case SDL_KEYUP:
					//if (e.key.keysym.sym == SDLK_ESCAPE)
					//    running = false;
					ev.type = EventType.KeyUp;
					ev.keyCode = e.key.keysym.sym;
					ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					keyMod = cast(KeyMod)SDL_GetModState();
					ev.mod = keyMod;
					ev.windowID = e.key.windowID;
					//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
					break;
				case SDL_TEXTINPUT:
					//std.stdio.writeln(e.text.text);
					char[] ch = cast(char[])e.text.text;
					//size_t st = std.utf.stride(ch, 0);
					ev.type = EventType.Text;
					ev.ch = ch.front;
					keyMod = cast(KeyMod)SDL_GetModState();
					ev.mod = keyMod;
					ev.windowID = e.text.windowID;
					break;
				case SDL_TEXTEDITING:
					break; // include chars while entering a unicode char. Where TEXTINPUT will get the uncode char itself.
				case SDL_WINDOWEVENT:
					ev.windowID = e.window.windowID;
					switch (e.window.event)
					{
						case SDL_WINDOWEVENT_SIZE_CHANGED:
						case SDL_WINDOWEVENT_RESIZED:
							ev.type = EventType.Resize;
							// SHIT! the size set here was the old window.size... be careful about recursive _dirtySize when fixing this!
							auto w = ev.windowID in _windows;
							if (w !is null)
								w.size = Vec2f(e.window.data1, e.window.data2);
							break;
						case SDL_WINDOWEVENT_FOCUS_GAINED:
							ev.type = EventType.Focus;
							break;
						default:
							break;
					}
					break;
				case SDL_DROPFILE:
					import std.c.string;
					auto file = e.drop.file[0..strlen(e.drop.file)].idup;
					keyMod = cast(KeyMod)SDL_GetModState();
					onFileDropped.emit(file);
					// TODO FIX: SDL_free(e.drop.file);
					break;
				case SDL_QUIT:
					stop();
					break;
				default: 
					std.stdio.writeln("unhandled event ", e.type);
					break; 
			}

			if (ev.type != EventType.Invalid)
			{
				dispatchEvent(ev);
			}
			
			pollResult = SDL_PollEvent(&e);
			
		} while (count-- > 0);
	}

	private void dispatchEvent(Event e)
	{
		auto w = e.windowID in _windows;
		if (w !is null)
			w.dispatchEvent(e);
		else
			std.stdio.writeln("Event with no window target received ", e);
	}

	void repaintAllWindows()
	{
		foreach(winID, win; _windows)
		{
			win.repaint();
		}
	}

	Window createWindow(string name = "MainWindow", int width = 1280, int height = 720)
	{
		Window win = new Window(name, width, height);
		win.timeline = timeline;
		if (activeWindow is null)
			activeWindow = win;
		_windows[win.id] = win;

		Event ev;
		ev.type = EventType.Resize;
		Vec2f sz = win.size;
		ev.width = cast(int)sz.x;
		ev.height = cast(int)sz.y;
		ev.windowID = win.id;
		_eventQueue.enqueue(ev);

		return win;
	}
}
