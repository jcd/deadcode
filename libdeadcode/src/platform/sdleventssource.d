module platform.sdleventssource;

import dccore.event : MainEventSource, Event;
import gui.event;
import gui.keycode;
import math : Vec2f;
import std.range : front;

import derelict.sdl2.sdl;
import derelict.sdl2.functions;
import derelict.sdl2.types;

class SDLEventSource : MainEventSource
{
	this()
	{
		//SDL_Init(SDL_INIT_VIDEO);
		_sdlCustomEventType = SDL_RegisterEvents(1);
		void* n = null;
		version (Windows)
		{
			// Listen for non-client area event in order to enable hover there as well
			SDL_EventState(SDL_SYSWMEVENT, SDL_ENABLE);
			
			// Add an event filter so we do not get flooded with syswm messages
			SDL_SetEventFilter(&_eventFilter, n);
		}
	}

	version (Windows)
	{
		extern (C) private static int _eventFilter(void* userdata, SDL_Event* event) nothrow
		{
			import win32.winuser;
			return event.type != SDL_SYSWMEVENT || event.syswm.msg.msg.win.msg == WM_NCMOUSEMOVE ? 1 : 0;
		}
	}

	// A timeout should always put a TimeoutEvent on the queue
	override Event poll(Duration timeout_)
	{
		static import std.algorithm;

		long timeoutMiliseconds = timeout_.total!"msecs"();
		long startTicks = SDL_GetTicks();
		Event ev = null;
		long timePassed = 0;
		
		do
		{
			import dccore.log;
			SDL_Event e;
			// log.info("Timeout %s %s %s", timeoutMiliseconds, timePassed, cast(int) (timeoutMiliseconds - timePassed));
			int pollResult = SDL_WaitEventTimeout(&e, cast(int) (timeoutMiliseconds - timePassed));

			timePassed = SDL_GetTicks() - startTicks;

			switch(e.type) {
				case SDL_MOUSEMOTION:
					ev = GUIEvents.create!MouseMoveEvent(
						e.motion.windowID, e.motion.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.motion.x, e.motion.y), Vec2f(e.motion.xrel, e.motion.yrel),
						cast(MouseButtonFlag)e.motion.state);
					break;
				case SDL_MOUSEBUTTONDOWN:
					ev = GUIEvents.create!MousePressedEvent(
						e.button.windowID, e.button.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.button.x, e.button.y), e.button.button, cast(MouseButtonFlag)e.motion.state);
					break;
				case SDL_MOUSEBUTTONUP:
					ev = GUIEvents.create!MouseReleasedEvent(
						e.button.windowID, e.button.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.button.x, e.button.y), e.button.button, cast(MouseButtonFlag)e.motion.state);
					break;
				case SDL_MOUSEWHEEL:
					ev = GUIEvents.create!MouseWheelEvent(
						e.wheel.windowID, e.wheel.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.wheel.x, e.wheel.y), e.wheel.direction == SDL_MOUSEWHEEL_FLIPPED);
					break;
				case SDL_KEYDOWN:
					static import core.stdc.string;
					dchar ch = SDL_GetKeyName(e.key.keysym.sym)[0..core.stdc.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev = GUIEvents.create!KeyPressedEvent(
						e.key.windowID, cast(KeyMod)SDL_GetModState(), e.key.keysym.sym, ch);
					break;
				case SDL_KEYUP:
					static import core.stdc.string;
					dchar ch = SDL_GetKeyName(e.key.keysym.sym)[0..core.stdc.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev = GUIEvents.create!KeyReleasedEvent(
						e.key.windowID, cast(KeyMod)SDL_GetModState(), e.key.keysym.sym, ch);
					break;
				case SDL_TEXTINPUT:
					char[] ch = cast(char[])e.text.text;
					ev = GUIEvents.create!TextEvent(
						e.text.windowID, cast(KeyMod)SDL_GetModState(), ch.front);
					break;
				case SDL_TEXTEDITING:
					break; // include chars while entering a unicode char. Where TEXTINPUT will get the uncode char itself.
				case SDL_WINDOWEVENT:
					switch (e.window.event)
					{
						case SDL_WINDOWEVENT_RESIZED:
							// We will always get SDL_WINDOWEVENT_SIZE_CHANGED before this event. This
							// event is only called if the changed size is caused by an external event such
							// as user window resize or window manager
							break;
						case SDL_WINDOWEVENT_SIZE_CHANGED:
							// SHIT! the size set here was the old window.size... be careful about recursive _dirtySize when fixing this!
							ev = GUIEvents.create!WindowResizedEvent(
								e.window.windowID, Vec2f(e.window.data1, e.window.data2));
							break;
						case SDL_WINDOWEVENT_FOCUS_GAINED:
							ev = GUIEvents.create!WindowFocussedEvent(e.window.windowID);
							break;
						case SDL_WINDOWEVENT_FOCUS_LOST:
							ev = GUIEvents.create!WindowUnfocussedEvent(e.window.windowID);
							break;
						default:
							break;
					}
					break;
				case SDL_SYSWMEVENT:
					version (Windows)
					{
						import win32.winuser;
						if (e.syswm.msg.msg.win.msg == WM_NCMOUSEMOVE)
						{
							auto lp = e.syswm.msg.msg.win.lParam;
							auto lplow = lp & 0XFFFF;
							auto lphigh = (lp >> 16) & 0xFFFF;
							auto xPos = (cast(int) cast(short)lplow);
							auto yPos = (cast(int) cast(short)lphigh);
							ev = GUIEvents.create!MouseMoveEvent(0, 0, cast(KeyMod)SDL_GetModState(),
																 Vec2f(xPos, yPos), Vec2f(0,0),
																 cast(MouseButtonFlag)0);
						}
					}
					break;
				case SDL_DROPFILE:
					import std.c.string;
					auto file = e.drop.file[0..strlen(e.drop.file)].idup;
					auto keyMod = cast(KeyMod)SDL_GetModState();
					ev = GUIEvents.create!DropFile(file, keyMod);
					// TODO FIX: SDL_free(e.drop.file);
					break;
				case SDL_QUIT:
					ev = CoreEvents.create!QuitEvent();
					break;
				default:
					break;
			}
		}
		while (ev is null && timeoutMiliseconds > timePassed);

		return ev;
	}

	// Called by other threads that just called put(event) on 
	// us in order to wake us up and handle the event.
	override void signalEventQueuedByOtherThread()
	{
		SDL_Event event;
		event.type = _sdlCustomEventType;
		SDL_PushEvent(&event);
	}

private:
	uint _sdlCustomEventType; // Custom event for existing a poll()
}