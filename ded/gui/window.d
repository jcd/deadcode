module gui.window;

import animation.timeline;
import core.time;
import derelict.sdl2.sdl;
import graphics._;
import gui.event;
import gui.keycode;
import gui.style;
import gui.widget;
import math._;
import std.range;
import std.typecons;
import std.stdio;

alias uint WindowID;
enum NullWindowID = 0u;

class Window : RenderWindow
{
	// Return true if event has been used
	alias bool delegate(Event) OnEvent;
	alias void delegate() OnUpdate;

	private
	{
		bool _waitForEvents;
		OnEvent _onEvent;
		OnUpdate _onUpdate;

		class QueuedEvent
		{
			Event event;
			QueuedEvent next;
		}
		QueuedEvent eventQueue;

		Widget[WidgetID] widgets;
		WidgetID nextWidgetId = 1u; // TODO: use pool
		Timeline _timeline;
	}

	Widget mainWidget;
	WindowID id;

	package Widgets[WidgetID] _widgetChildren;

	static Window active;

	@property 
	{
		void waitForEvents(bool v)
		{
			_waitForEvents = v;
		}

		void onEvent(OnEvent callback)
		{
			_onEvent = callback;
		}
	
		void onUpdate(OnUpdate callback)
		{
			_onUpdate = callback;
		}

		override Vec2i size()
		{
			return super.size;
		}

		override void size(Vec2f s)
		{			
			this.size(Vec2i(cast(int)s.x, cast(int)s.y));
		}

		override void size(Vec2i sz)
		{
			super.size = sz;
			Event ev;
			ev.type = EventType.Resize;
			ev.width = sz.x;
			ev.height = sz.y;
			queueEvent(ev);	
		}

		Timeline timeline() { return _timeline; }
	}

	void queueEvent(Event e)
	{
		QueuedEvent qe = eventQueue;
		while (qe.next !is null)
			qe = qe.next;
		qe.next = new QueuedEvent;
		qe.next.event = e;
	}

	Event dequeueEvent()
	{
		if (eventQueue.next is null)
			return Event(EventType.Invalid);
		QueuedEvent e = eventQueue.next;
		eventQueue.next = e.next;
		return e.event;
	}

	bool queueEmpty()
	{
		return eventQueue.next is null;
	}

	this(WindowID _id, const(char)[] name, Vec2i sz)
	{
		this(_id, name, sz.x, sz.y);
	}

	this(WindowID _id, const(char)[] name, int width, int height) 
	{
		super(name, width, height);
		id = _id;

		eventQueue = new QueuedEvent(); // first event in queue is never dequeued

		// If there is no active window yet then activate this
		if (Window.active is null)
			active = this;

		mainWidget = createWidget(0, 0, width, height);

		SDL_StartTextInput();		
	
		_timeline = new Timeline;
		_timeline.start();
	}

	bool update()
	{
		bool running = true;
		SDL_Event e; 
		int pollResult = 0;
		if (_waitForEvents && queueEmpty())
			pollResult = SDL_WaitEvent(&e);
		else
			pollResult = SDL_PollEvent(&e);
		
		do {

			Event queuedEvent = dequeueEvent();
			while (queuedEvent.type != EventType.Invalid)
			{
				dispatchEvent(queuedEvent);
				queuedEvent = dequeueEvent();
			}

			if (!pollResult)
				break;

			Event ev;
			switch(e.type) { 
				case SDL_MOUSEMOTION:
					ev.type = EventType.MouseMove;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mousePosRel.x = e.motion.xrel;
					ev.mousePosRel.y = e.motion.yrel;
					ev.mouseButtonsActive = e.motion.state;
					break;				
				case SDL_MOUSEBUTTONDOWN:
					ev.type = EventType.MouseDown;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mouseButtonsActive = e.button.state;
					ev.mouseButtonsChanged = e.button.button;
					break;
				case SDL_MOUSEBUTTONUP:
					ev.type = EventType.MouseUp;
					ev.mousePos.x = e.motion.x;
					ev.mousePos.y = e.motion.y;
					ev.mouseButtonsActive = e.button.state;
					ev.mouseButtonsChanged = e.button.button;
					break;
				case SDL_MOUSEWHEEL:
					ev.type = EventType.MouseScroll;
					ev.scroll = Vec2f(e.wheel.x, e.wheel.y);
					break;
				case SDL_KEYDOWN:
					if (e.key.keysym.sym == SDLK_ESCAPE)
						running = false;
					ev.type = EventType.KeyDown;
					ev.keyCode = e.key.keysym.sym;
					ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev.mod = cast(KeyMod)SDL_GetModState();
					//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
					break;
				case SDL_KEYUP:
					if (e.key.keysym.sym == SDLK_ESCAPE)
						running = false;
					ev.type = EventType.KeyUp;
					ev.keyCode = e.key.keysym.sym;
					ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev.mod = cast(KeyMod)SDL_GetModState();
					//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
					break;
				case SDL_TEXTINPUT:
					//std.stdio.writeln(e.text.text);
					char[] ch = cast(char[])e.text.text;
					//size_t st = std.utf.stride(ch, 0);
					ev.type = EventType.Text;
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

			dispatchEvent(ev);

			pollResult = SDL_PollEvent(&e);

		} while (true);

		timeline.update();

		// Let gui widgets, constraints etc. update before drawing them
		foreach (w; widgets)
			w.update();

		if (_onUpdate !is null)
			_onUpdate();

		// Base class render method that will in turn call _onRender if set
		render(false);
		renderGUI(null);
		swapBuffers();
		
		return running;
	}

	void run()
	{
		Event ev;
		ev.type = EventType.Resize;
		Vec2i sz = size;
		ev.width = sz.x;
		ev.height = sz.y;
		if (_onEvent !is null)
			_onEvent(ev);
		
		while(update()) { };
	}

	// The widget that the mouse left button has been clicked down on
	private WidgetID downButtonWidget = NullWidgetID;
	
	// The widget that has been clicked by the left mouse button
	private WidgetID clickWidget = NullWidgetID;

	private WidgetID mouseWidget = NullWidgetID;
	private WidgetID mouseGrabbedBy = NullWidgetID;
	private WidgetID keyboardFocusWidget = NullWidgetID;

	// The time of the last click on a widget in this window
	private TickDuration clickWidgetTime;

	// The max time that can pass when another click 
	// is accepted as a double click
	enum maxDoubleClickTime = 0.3f;

	Widget createWidget(Widget parent, float x = 0, float y = 0, float width = 100, float height = 100)
	{
		WidgetID wid = parent.window.id << 24 + nextWidgetId++; 
		auto w = new Widget(wid, parent, x, y, width, height);
		register(w);
		return w;
	}

	Widget createWidget(float x = 0, float y = 0, float width = 100, float height = 100)
	{
		WidgetID wid = id << 24 + nextWidgetId++;
		auto w = new Widget(wid, this, x, y, width, height);
		register(w);
		return w;
	}

	private void register(Widget w)
	{
		w.window = this;
		widgets[w.id] = w;
		Widget wparent = w.parent;
		if (wparent !is null)
		{
			Widgets * ws = wparent.id in _widgetChildren;
			if (ws is null)
			{
				_widgetChildren[wparent.id] = [w];
			}
			else
			{
				*ws ~= w;
			}
		}	
	}

	Widget getWidget(WidgetID id)
	{
		return widgets[id];
	}

	void setKeyboardFocusWidget(Widget widg)
	{
		setKeyboardFocusWidget(widg is null ? NullWidgetID : widg.id);
	}

	void setKeyboardFocusWidget(WidgetID wid)
		{
		// Find widget that accepts keyboard focus from wid
		// and though parents if any. This bubbling is not handled by
		// the normal widget.send(..) mechanism because we need to
		// send unfocus event only if any widget will accept the
		// keyboard focus which is not always the case.
	
		auto wp = wid in widgets;
		Widget w = wp is null ? null : *wp;
		
		// TODO: fix w = null does not work!?!?
		while (w !is null && !w.acceptsKeyboardFocus)
		{
			if (w.parent is null)
			{
				return;
			}
			else
			{
				w = w.parent;
			}
		}
		
		auto ow = keyboardFocusWidget in widgets;
		if (ow !is null)
			ow.send(Event(EventType.KeyboardUnfocus));
		
		if (w !is null)
		{
			w.send(Event(EventType.KeyboardFocus));
			keyboardFocusWidget = w.id;
		}
		else
		{
			keyboardFocusWidget = NullWidgetID;
		}
	}

	bool isKeyboardFocusWidget(Widget w)
	{
		return keyboardFocusWidget == w.id;
	}

	void grabMouse(Widget w)
	{
		assert(mouseGrabbedBy == NullWidgetID);
		mouseGrabbedBy = w.id;
	}

	bool isGrabbingMouse(Widget w)
	{
		return w.id == mouseGrabbedBy;
	}
	
	void releaseMouse()
	{
		assert(mouseGrabbedBy != NullWidgetID);
		mouseGrabbedBy = NullWidgetID;
	}

	private void dispatchEvent(Event ev)
	{
		if (ev.type == EventType.Invalid)
			return;

		bool handle = _onEvent !is null;
		if (handle)
			handle = _onEvent(ev);
		// Handle will be false if onEvent is not set or onEvent did not handle the event.
		// In that case fall back.
		if (!handle)
			send(ev);
	}
	
	/** Send an event to the GUI system
 	* 
	*  Returns: true if event is still valid ie. hasn't been used by an event handling function.
	*/
	bool send(Event event)
	{
		bool used = false;
		WidgetID lastMouseWidget = mouseWidget;
		mouseWidget = NullWidgetID;
		
		/*
	static bool bubbleEvent(Widget* wi, Event ev)
	{
		Widget w = *wi;
		bool valid = true;
		do 
		{
			valid = w.send(ev);
			w = w.parent;
		} 
		while (valid && w !is null); 
		return valid;
	}
*/		
		// Find widget that mouse is over
		foreach (ref w; widgets)
		{
			if (w.rect.contains(event.mousePos))
			{
				mouseWidget = w.id;
			}
		}
		if (mouseGrabbedBy)
			mouseWidget = mouseGrabbedBy;
		
		Widget * overWidget = null; 
		if (mouseWidget)
			overWidget = mouseWidget in widgets;
		
		// Send events to the found widget
		std.stdio.writeln(event.type);
		switch (event.type)
		{
			case EventType.MouseMove:
				if (lastMouseWidget != mouseWidget)
				{
					// If a click has been initiated by a mouse down and the mouse 
					// goes away from the widget the click is aborted.
					downButtonWidget = NullWidgetID;
					clickWidget = NullWidgetID;
					
					// Handle mouse out events
					if (lastMouseWidget != NullWidgetID)
					{
						Widget * outWidget = lastMouseWidget in widgets;
						
						// Bubbling to parents lets a parent handle all out events for its children 
						// which can be convenient
						if (outWidget)
						{
							event.type = EventType.MouseOut;
							outWidget.send(event);
						}
					}
					
					// Handle mouse over event and mouse move event
					if (overWidget)
					{
						event.type = EventType.MouseOver;
						overWidget.send(event);
						event.type = EventType.MouseMove;
						used = overWidget.send(event);
					}
				}
				else if (overWidget)
				{
					// Handle mouse move event
					used = overWidget.send(event);
				}
				else
				{
					// If a click has been initiated by a mouse down and the mouse 
					// goes away from the widget the click is aborted.
					downButtonWidget = NullWidgetID;
					clickWidget = NullWidgetID;				
				}
				break;
			case EventType.MouseDown:
				if (overWidget)
				{
					downButtonWidget = mouseWidget;
					used = overWidget.send(event);
				}
				else
				{
					downButtonWidget = NullWidgetID;
					clickWidget = NullWidgetID;
				}
				break;
			case EventType.MouseUp:
				if (overWidget)
				{
					used = overWidget.send(event);
					if (downButtonWidget == mouseWidget)
					{
						TickDuration tdur = TickDuration.currSystemTick;
						float doubleClickTime = tdur.to!("seconds",float)() - clickWidgetTime.to!("seconds",float)();
						if (downButtonWidget == clickWidget && doubleClickTime < maxDoubleClickTime)
						{
							event.type = EventType.MouseDoubleClick;
							used = overWidget.send(event) || used;
							clickWidget = 0;
						}
						else
						{
							event.type = EventType.MouseClick;
							used = overWidget.send(event) || used;
							clickWidget = downButtonWidget;
							clickWidgetTime = TickDuration.currSystemTick;
							setKeyboardFocusWidget(clickWidget);
						}
					}
				}
				downButtonWidget = NullWidgetID;
				break;
			case EventType.MouseScroll:
			case EventType.KeyDown:
			case EventType.KeyUp:
			case EventType.Text:
				
				std.stdio.writeln("dxx ", event.type, " ", keyboardFocusWidget);
				if (keyboardFocusWidget != NullWidgetID)
				{
					Widget * w = keyboardFocusWidget in widgets;
					
					if (w is null)
						setKeyboardFocusWidget(NullWidgetID);
					else
						used = w.send(event);
				}
				break;
			case EventType.Resize:
				bool cont = false;
				int maxIter = 5;
				// Resize events will let widget do relayouts. 
				do
				{
					cont = false;
					foreach (w; widgets)
					{
						cont |= w.send(event);
					}
				} while (cont && maxIter--);
			default:
				break;
		}
		
		// TODO: fix
		// FIX: this
		//if (Widget.keyboardFocusWidget == NullWidgetID && Widget.widgets.length != 0 ) {}
		//Widget.setKeyboardFocusWidget(Widget.widgets[Widget.widgets.keys()[0]].id); 
		return used;
	}
	
	/** Draw all widgets
 	* 
 	*/
	void renderGUI(StyleSet styleSet = null)
	{
		if (styleSet is null)
			styleSet = StyleSet.base;
		
		foreach (w; widgets)
		{
			if (w.parent is null)
				w.draw(styleSet);
		}
	}

}
