module gui.window;

import animation.timeline;

import core.time;
import derelict.sdl2.sdl;
import graphics;
import gui.event;
import gui.keycode;
import gui.style;
import gui.widget : Widget, WidgetID, NullWidgetID;
import math;
import std.range;
import std.stdio;
import std.typecons;
import std.variant;
import dccore.signals;

import util.profile;

enum MouseCursor
{
	arrow,
    iBeam,
    wait,
    crossHair,
    waitArrow,
    sizeNWSE,
    sizeNESW,
    sizeWE,
    sizeNS,
    sizeAll,
    no,
    hand,
}

alias uint WindowID;

private T safeDeref(T)(T* d) if (is(T == class))
{
	return d is null ? null : *d;
}

class Window : gui.widget.Widget
{
	// Return true if event has been used
	alias EventUsed delegate(ref Event) OnEvent;
	alias void delegate() OnUpdate;

	// mixin Reflect;

	private
	{
		//OnEvent _onEvent;
		// 		OnUpdate _onUpdate;
		RenderTarget _renderTarget;

		Widget[WidgetID] widgets;

		// partial mapping name to widgets because we do not want
		// to have name on all widgets and therefore the name is
		// not a member of Widget.
		Widget[string] widgetNameMap;
		WidgetID _lastMouseWidgetID;
	}

	Variant userData;
	WindowID id;
	StyleSheet styleSheet;
	Timeline timeline;

	// emit(this)
	mixin Signal!(Window) onUpdate;

    mixin Signal!(Widget,Event) onDispatchEvent;

    static Window active;

	override @property Window window() pure nothrow @safe
	{
		return this;
	}

	override @property const(Window) window() const pure nothrow @safe
	{
		return this;
	}

	@property
	{
		//void onEvent(OnEvent callback)
		//{
		//    _onEvent = callback;
		//}

		//void onUpdate(OnUpdate callback)
		//{
		//    _onUpdate = callback;
		//}

		Mat4f MVP() const
		{
			return _renderTarget.MVP;
		}

		RenderTarget renderTarget()
		{
			return _renderTarget;
		}

		override const(Vec2f) size() const
		{
			auto sz = _renderTarget.size;
			return Vec2f(sz.x, sz.y);
		}

		override void size(Vec2f s)
		{
			size(Vec2i(cast(int)s.x, cast(int)s.y));
		}

		override void size(Vec2i sz)
		{
			if (_renderTarget.size == sz && super.size == Vec2f(sz.x, sz.y))
				return;

			_renderTarget.size = sz;
			super.size = Vec2f(sz.x, sz.y);
			_sizeDirty = true;
		}

		Vec2f position() const
		{
			return _renderTarget.position;
		}

		void position(Vec2f pos)
		{
			_renderTarget.position = pos;
		}

		void mouseCursor(MouseCursor c)
		{
			SDL_Cursor* cursor = SDL_CreateSystemCursor(c);
			SDL_SetCursor(cursor);
		}

		MouseCursor mouseCursor()
		{
			return cast(MouseCursor) SDL_GetCursor();
		}

        private uint windowFlags() const nothrow @trusted
        {
            uint wid = 0;
            try
            {
                wid = _renderTarget.id;
            }
            catch (Exception e)
            {
				assert(0);
            }
            return SDL_GetWindowFlags(SDL_GetWindowFromID(wid));
        }

		override @property bool visible() const nothrow @safe
	    {
	        Uint32 flags = windowFlags();
			return (flags & SDL_WINDOW_SHOWN) != 0;
	    }

	    override @property void visible(bool v)
	    {
	        if (visible && v || !visible && !v)
	            return;
			uint wid = 0;
            try
            {
                wid = _renderTarget.id;
	            if (v)
		            SDL_ShowWindow(SDL_GetWindowFromID(wid));
				else
		            SDL_HideWindow(SDL_GetWindowFromID(wid));
            }
            catch (Exception e)
            {
				assert(0);
            }

		    super.visible = v;
        }
	}

	void repaint()
	{
		foreach (wID, w; widgets)
			w.forceDirty();
	}

	Widget getWidget(string name) nothrow
	{
		auto w = name in widgetNameMap;
		if (w is null)
			return null;
		return *w;
	}

	package string lookupWidgetName(WidgetID wid) const pure @safe
	{
		assert(widgetNameMap !is null);
		foreach (k, v; widgetNameMap)
		{
			if (v.id == wid)
				return k;
		}
		return null;
	}

	package void setWidgetName(Widget w, string n) nothrow
	{
		if (n is null)
		{
			try
			{
				foreach (k, v; widgetNameMap)
				{
					if (v.id == w.id)
					{
						widgetNameMap.remove(k);
						break;
					}
				}
			}
			catch (Exception)
			{
				assert(0);
			}
			return;
		}
		widgetNameMap[n] = w;
	}

	package bool isWidgetInFrontOfWidget(Widget isThis, Widget inFrontOfThis)
	{
		if (isThis.zOrder > inFrontOfThis.zOrder)
			return true;
		else if (isThis.zOrder < inFrontOfThis.zOrder)
			return false;

		foreach (k, v; widgets)
		{
			if (v is isThis)
				return false;
			else if (v is inFrontOfThis)
				return true;
		}
		assert(0);
		// return false;
	}

	package void emitResizeEvent()
	{
		Vec2f sz = super.size;
		Event ev = GUIEvents.create!WindowResizedEvent(this.id, sz);
		dispatch(ev);
		ev.dispose();
	}

	void onStyleSheetChanged()
	{
		Event ev = GUIEvents.create!StyleSheetChangedEvent(this.id);
		dispatch(ev);
		ev.dispose();
	}

	Rectf windowToWorld(Rectf r)
	{
		return _renderTarget.windowToWorld(r);
	}

	Rectf worldToWindow(Rectf r)
	{
		return _renderTarget.worldToWindow(r);
	}

	Vec2f worldToPixelSize(Vec2f src)
	{
		return _renderTarget.worldSizeToPixel(src);
	}

	Vec2f pixelSizeToWorld(SmallVector!(2u,float) pixels)
	{
		return _renderTarget.pixelSizeToWorld(pixels);
	}

	float pixelWidthToWorld(float x)
	{
		return _renderTarget.pixelWidthToWorld(x);
	}

	float pixelHeightToWorld(float y)
	{
		return _renderTarget.pixelHeightToWorld(y);
	}

	//this(const(char)[] name, Vec2i sz)
	//{
	//    this(name, sz.x, sz.y);
	//}
	//
	//this(const(char)[] _name, int width, int height)
	//{
	//    auto renderWin = new RenderWindow(_name, width, height);
	//    this(_name, width, height, renderWin);
	//}

	this(const(char)[] _name, int width, int height, RenderTarget _renderTarget)
	{
		this._renderTarget = _renderTarget;
		super(0f,0f,width,height);
		setWidgetName(this, _name.idup);
		id = _renderTarget.id;
		register(this);
		_keyboardFocusWidgetID = this.id;

		// If there is no active window yet then activate this
		if (Window.active is null)
			active = this;

		this.size = Vec2i(width, height);
	}

	Widget getWidgetAtPos(Vec2f p)
	{
		// Find widget that mouse is over
		Widget cur = null;
		//std.stdio.writeln("------------------------- ", p);
		import std.typecons;

		_mouseWidgetStackIDs.length = 0;
		_mouseWidgetStackIDs.assumeSafeAppend();

		foreach (k; widgets.keys)
		{
			Widget w = widgets[k];

			//std.stdio.writeln(w.name, " visible ", w.visible, w.rect);
			//if (w.visible && w.rectStyled.contains(p))
			if (w.visible && w.rect.contains(p))
			{
				_mouseWidgetStackIDs ~= w.id;

				//std.stdio.writeln("hit ", w.name);
                // TODO: make proper z-index stack order css property
				bool isInFront = cur is null ||
					w.zOrder > cur.zOrder || // Order is prioritized
					(w.zOrder == cur.zOrder && (w.isDecendantOf(cur) || (w.style.zIndex > cur.style.zIndex && !cur.isDecendantOf(w)) )); // And if order is equal then test if in same branch
				if (isInFront)
				{
					//std.stdio.writeln(w.name, " desc of ", cur is null ? "null" : cur.name, " rect ", w.rect.pos.v, w.rect.size.v, p.v);
					cur = w;
				}
			}
		}
		return cur;
	}

	override void update()
	{
		// Let gui widgets, constraints etc. update before drawing them
        {
        //auto frameZonex = Zone(profiler, "windowUpdateWidgets");

        foreach (w; widgets)
		{
			if (w !is this)
				w.update();
		}
        }

		{
            //auto frameZonex = Zone(profiler, "windowOnUpdate");
            onUpdate.emit(this);
        }

		{
           // auto frameZonex = Zone(profiler, "windowEmitResize");
            if (_sizeDirty)
		    {
			    _sizeDirty = false;
			    emitResizeEvent();
		    }
        }

		//if (_onUpdate !is null)
		//    _onUpdate();
	}

	override void draw()
	{
		import util.profile;
		{
			auto frameZonex = Zone(profiler, "Draw1");
			_renderTarget.render(false);
		}
		{
			Widget.drawCalls = 0;
			Widget.drawFeatureCalls = 0;
			auto frameZonex = Zone(profiler, "Draw2");
			super.draw();
			frameZonex.variableEvent!"drawCount"(Widget.drawCalls);
			frameZonex.variableEvent!"drawFeatureCount"(Widget.drawFeatureCalls);
		}
		{
			auto frameZonex = Zone(profiler, "SwapBuffers");
			_renderTarget.swapBuffers();
		}
	}

	// The widget that the mouse left button has been clicked down on
	private WidgetID _downButtonWidgetID = NullWidgetID;

	// The widget that has been clicked by the left mouse button
	private WidgetID _clickWidgetID = NullWidgetID;

	// Number of times the click widget has been clicked. To detext double/triple... clicks
	private int _clickWidgetClicks = 0;

	private WidgetID _mouseWidgetID = NullWidgetID; // top most
	private WidgetID[] _mouseWidgetStackIDs = null; // all stack
	private WidgetID _mouseGrabbedByWidgetID = NullWidgetID;
	private WidgetID _keyboardFocusWidgetID = NullWidgetID;

	// The time of the last click on a widget in this window
	private TickDuration _clickWidgetTime;

	// The max time that can pass when another click
	// is accepted as a double click
	enum maxDoubleClickTime = 0.3f;

	W createWidget(W = Widget)(Widget parent, float x = 0, float y = 0, float width = 100, float height = 100)
	{
		auto w = new W(parent, x, y, width, height);
		register(w);
		return w;
	}

	W createWidget(W = Widget)(float x = 0, float y = 0, float width = 100, float height = 100)
	{
		return createWidget!W(this, x, y, width, height);
	}

	// TODO: make private
	void register(Widget w) nothrow
	{
		widgets[w.id] = w;
		setWidgetName(w, w.name);
		foreach (cw; w.children)
			register(cw);
	}

	package void deregister(Widget w) nothrow
	{
		widgets.remove(w.id);
		setWidgetName(w, null);
		foreach (cw; w.children)
			deregister(cw);
	}

	Widget getWidget(WidgetID id) nothrow
	{
		if (id == NullWidgetID)
			return null;
		auto w = id in widgets;
		return w is null ? null : *w;
	}

	void setKeyboardFocusWidget(Widget widg)
	{
		setKeyboardFocusWidget(widg is null ? NullWidgetID : widg.id);
	}

	void setKeyboardFocusWidget(WidgetID wid) nothrow
	{
		// Find widget that accepts keyboard focus from wid
		// and though parents if any. This bubbling is not handled by
		// the normal widget.send(..) mechanism because we need to
		// send unfocus event only if any widget will accept the
		// keyboard focus which is not always the case.

		if (wid == _keyboardFocusWidgetID)
			return; // already in focus

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

		if ((_keyboardFocusWidgetID == NullWidgetID && w is null) || wid == _keyboardFocusWidgetID)
			return; // Nothing to focus or unfocus OR already in focus

		auto ow = _keyboardFocusWidgetID in widgets;

	    try
        {
            if (w !is null && w.acceptsKeyboardFocus)
		    {
			    _keyboardFocusWidgetID = w.id;
			    if (ow !is null)
                {
					auto ufe = GUIEvents.create!InputUnfocusEvent(this.id);
					propagateEvent(ufe, *ow);
					ufe.dispose();
				    //ow.send(ufe);
                }

				auto fe = GUIEvents.create!InputFocusEvent(this.id);
			    propagateEvent(fe, w);
				fe.dispose();
				// w.send(fe);
		    }
		    else if (ow is null)
		    {
			    _keyboardFocusWidgetID = id; // fallback to window as focus
		    }
        }
        catch (Exception e)
        {
            assert(0);
            // TODO: fix
            // app.addMessage("While trying to se keyboard widget focus %s", e);
        }
	}

    Vec2f getCursorScreenPosition()
    {
        // TODO: move this to graphics or input abstraction
        import platform.cursor;
        Vec2f result;
        if (getScreenPosition(&result))
            return result;

        return Vec2f(0,0);
    }

	bool hasKeyboardFocus(const(Widget) w) const pure nothrow @safe
	{
		return _keyboardFocusWidgetID == w.id;
	}

	WidgetID getKeyboardFocusWidgetID() nothrow
	{
		if (auto w = getWidget(_keyboardFocusWidgetID))
            return w.id;
        return NullWidgetID;
	}

	Widget getKeyboardFocusWidget()
	{
		return getWidget(_keyboardFocusWidgetID);
	}

	bool isMouseOverWidget(const(Widget) w) const pure nothrow @safe
	{
		foreach (hitID; _mouseWidgetStackIDs)
			if (hitID == w.id)
				return true;
		return false;
		//	return mouseWidget == w.id;
	}

	bool isMouseDirectlyOverWidget(const(Widget) w) const pure nothrow @safe
	{
		return _mouseWidgetID == w.id;
	}

	bool isMouseDownWidget(const(Widget) w) const pure nothrow @safe
	{
		return _downButtonWidgetID != NullWidgetID && isMouseOverWidget(w);
	}

	bool isMouseDirectlyDownWidget(const(Widget) w) const pure nothrow @safe
	{
		return _downButtonWidgetID == w.id;
	}

	void grabMouse(const(Widget) w) pure nothrow @safe
	{
		assert(_mouseGrabbedByWidgetID == NullWidgetID);
		_mouseGrabbedByWidgetID = w.id;
	}

	bool isGrabbingMouse(const(Widget) w) const pure nothrow @safe
	{
		return w.id == _mouseGrabbedByWidgetID;
	}

	override void releaseMouse() pure nothrow @safe
	{
		// assert(_mouseGrabbedByWidgetID != NullWidgetID);
		_mouseGrabbedByWidgetID = NullWidgetID;
	}

	/*
TODO - Make event chains like osx in order to special handle "delete" and not only delete char but also update completions.
TODO - per default keyboardfocus widget should receive keyboard events. THink about propagating from parent to children and the other way around.
TODO:
	* Constraints on keymappings e.g. panel visible or widgetname == foobar or
*/
	/** Send an event to the GUI system
 	*
	*  Returns: true if event is still valid ie. hasn't been used by an event handling function.
	*/	

	// Do event propagation towards the target widget w.
	// First all ancestors of w have their captureEvent(Event e) method called
	// which allow them to stop further event propagation by returning EventUsed.yes
	// Then the w itself have its event(Even ev) method called. If it return EventUsed.no
	// the event will bubble to its parent event(Event ev) method and so on.
	private final EventUsed propagateEvent(GUIEvent ev, Widget w)
	{
		static EventUsed capturePropagation(Event ev, Widget w, Widget target)
		{
			if (w is null)
			{
				return EventUsed.no;
			}
			else
			{
				if (capturePropagation(ev, w.parent, target) == EventUsed.no)
				{
					if (w is target)
						return EventUsed.no; // target itself will get the event(Event ev) called. No need to capture.
					else
						return w.capture(ev, target);
				}
				else
				{
					return EventUsed.yes;
				}
			}
		}
		
		ev.targetWidget = w;

		if (capturePropagation(ev, w, w) ==  EventUsed.yes)
			return EventUsed.yes;

		onDispatchEvent.emit(w, ev);

		// Bubble
		while (w !is null && w.onEvent(ev) == EventUsed.no)
			w = w.parent;

		return w is null ? EventUsed.no : EventUsed.yes;
	}

	override EventUsed onEvent(GUIEvent event)
	{
		return EventUsed.no;
	}

	final EventUsed dispatch(Event event)
	{
		auto ev = cast(GUIEvent)event;
		if (ev is null)
			return EventUsed.no;

		auto d = EventDispatcher(this);
		return d.dispatch(ev);
	}

	// A separate EventDispatcher instance is used for the initial dispatching
	// to onXXXEvent handlers for the window. This is because the events are initially
	// processed here (possibly creating pseudo events like MouseOutEvent) and the the event
	// is dispatched to the target widget (using capture/bubble). If the event ends up bubbling 
	// back to the window it should not performt the same initial processing but simply ignore
	// the event (or do whatever a class derived from window wants to do). Thus the need for
	// an EventDispatcher.
	private static struct EventDispatcher
	{
		private Window win;
		alias win this;

		this(Window w)
		{
			win = w;
		}

		EventUsed dispatch(GUIEvent event)
		{
			//assert(event.windowID == win.id);
			if (!event.isValid)
				return EventUsed.no;

			//if (_onEvent !is null && _onEvent(ev) == EventUsed.yes)
			//    return EventUsed.yes;

			static WidgetID getCurrentMouseWidgetID(T)(Window win, GUIEvent ev)
			{
				auto e = cast(T) ev;
				auto mouseWidget = win.getWidgetAtPos(e.position);
				e.atWidget = mouseWidget;
				return mouseWidget is null ? NullWidgetID : mouseWidget.id;
			}

			bool hasPosition = false;
			if (event.type == GUIEvents.mouseMove)
			{
				win._mouseWidgetID = getCurrentMouseWidgetID!MouseMoveEvent(win, event);
				hasPosition = true;
			}
			else if (event.type == GUIEvents.mousePressed || event.type == GUIEvents.mouseReleased)
			{
				win._mouseWidgetID = getCurrentMouseWidgetID!MouseButtonEvent(win, event);
				hasPosition = true;
			}

			if (win._mouseGrabbedByWidgetID != NullWidgetID)
				win._mouseWidgetID = win._mouseGrabbedByWidgetID;

			auto result = GUIEvents.dispatch(this, event);

			if (hasPosition)
				win._lastMouseWidgetID = win._mouseWidgetID;

			return result;
		}

		EventUsed onMouseMoveEvent(MouseMoveEvent event)
		{
			EventUsed used = EventUsed.no;
			if (win._lastMouseWidgetID != win._mouseWidgetID)
			{
				// If a click has been initiated by a mouse down and the mouse
				// goes away from the widget the click is aborted.
				win._downButtonWidgetID = NullWidgetID;
				win._clickWidgetID = NullWidgetID;
				win._clickWidgetClicks = 0;

				// Handle mouse out events
				Widget outWidget = null;
				if (win._lastMouseWidgetID != NullWidgetID)
				{
					outWidget = safeDeref(win._lastMouseWidgetID in win.widgets);

					// Bubbling to parents lets a parent handle all out events for its children
					// which can be convenient
					if (outWidget !is null)
					{
						event.lastWidget = outWidget;
						auto w = win._mouseWidgetID in win.widgets;
						auto mouseOutEvent = 
							GUIEvents.create!MouseOutEvent(event.windowID, event.mouseID, event.modifiers,
														   w is null ? null : *w, outWidget);
						win.propagateEvent(mouseOutEvent, outWidget);
						mouseOutEvent.dispose();
					}
				}

				// Handle mouse over event and mouse move event
				if (win._mouseWidgetID != NullWidgetID)
				{
					//if (win._lastMouseWidgetID == NullWidgetID)
					//    win._lastMouseWidgetID = win._lastMouseWidgetID;
					auto w = win._mouseWidgetID in win.widgets;
					auto mouseOverEvent = 
						GUIEvents.create!MouseOverEvent(event.windowID, event.mouseID, event.modifiers,
													    w is null ? null : *w, outWidget);
					used = win.propagateEvent(mouseOverEvent, *w);
					mouseOverEvent.dispose();
				}
			}
			else if (win._mouseWidgetID != NullWidgetID)
			{
				// Handle mouse move event
				if (win._lastMouseWidgetID != NullWidgetID)
				{
					auto lw = win._lastMouseWidgetID in win.widgets;
					if (lw !is null)
						event.lastWidget = *lw;
				}
				auto w = win._mouseWidgetID in win.widgets;
				used = win.propagateEvent(event, w is null ? null : *w);
			}
			else
			{
				// If a click has been initiated by a mouse down and the mouse
				// goes away from the widget the click is aborted.
				win._downButtonWidgetID = NullWidgetID;
				win._clickWidgetID = NullWidgetID;
				win._clickWidgetClicks = 0;
			}
			return used;
		}

		EventUsed onMouseOverEvent(MouseOverEvent event)
		{
			// mouse out events are created by this window itself and shouldn't be handled
			return EventUsed.no;
		}

		EventUsed onMouseOutEvent(MouseOutEvent event)
		{
			// mouse over events are created by this window itself and shouldn't be handled
			return EventUsed.no;
		}

		EventUsed onMousePressedEvent(MousePressedEvent event)
		{
			EventUsed used = EventUsed.no;
			if (win._mouseWidgetID != NullWidgetID)
			{
				win._downButtonWidgetID = win._mouseWidgetID;
				auto overWidget = safeDeref(win._downButtonWidgetID in win.widgets);
				used = win.propagateEvent(event, overWidget);
				if (win._clickWidgetID != NullWidgetID)
				{
					// check for double and triple click
					TickDuration tdur = TickDuration.currSystemTick;
					float multiClickTime = tdur.to!("seconds",float)() - win._clickWidgetTime.to!("seconds",float)();
					if (win._clickWidgetClicks == 1 && win._downButtonWidgetID == win._clickWidgetID && multiClickTime <= maxDoubleClickTime)
					{
						win._clickWidgetClicks++;
						auto mouseDoubleClickedEvent = 
							GUIEvents.create!MouseDoubleClickedEvent(event.windowID, event.mouseID, event.modifiers,
																	event.position, event.buttonChanged, event.buttons,
																	overWidget);

						used = win.propagateEvent(mouseDoubleClickedEvent, overWidget) == EventUsed.yes || used == EventUsed.yes ? EventUsed.yes : EventUsed.no;
						mouseDoubleClickedEvent.dispose();
					}
					else if (win._clickWidgetClicks == 2 && win._downButtonWidgetID == win._clickWidgetID && multiClickTime <= maxDoubleClickTime*2f)
					{
						auto mouseTripleClickedEvent = 
							GUIEvents.create!MouseTripleClickedEvent(event.windowID, event.mouseID, event.modifiers,
																	 event.position, event.buttonChanged, event.buttons,
																	 overWidget);
						used = win.propagateEvent(mouseTripleClickedEvent, overWidget) == EventUsed.yes || used == EventUsed.yes ? EventUsed.yes : EventUsed.no;
						mouseTripleClickedEvent.dispose();
						win._clickWidgetClicks = 0;
						win._clickWidgetID = NullWidgetID;
					}
					else
					{
						win._clickWidgetClicks = 0;
						win._clickWidgetID = NullWidgetID;
					}
				}

				if (win._clickWidgetClicks == 0)
					win._clickWidgetTime = TickDuration.currSystemTick;
			}
			else
			{
				win._downButtonWidgetID = NullWidgetID;
				win._clickWidgetID = NullWidgetID;
				win._clickWidgetClicks = 0;
			}
			return used;
		}

		EventUsed onMouseReleasedEvent(MouseReleasedEvent event)
		{
			EventUsed used = EventUsed.no;
			if (win._mouseWidgetID != NullWidgetID)
			{
				auto overWidget = safeDeref(win._mouseWidgetID in win.widgets);
				used = win.propagateEvent(event, overWidget);
				// TickDuration tdur = TickDuration.currSystemTick;
				// float doubleClickTime = tdur.to!("seconds",float)() - clickWidgetTime.to!("seconds",float)();
				bool allowClick = win._clickWidgetClicks == 0; //  || (doubleClickTime > maxDoubleClickTime;

				if (win._downButtonWidgetID == win._mouseWidgetID && allowClick)
				{
					win._clickWidgetClicks = 1;
					auto mouseClickedEvent = 
						GUIEvents.create!MouseClickedEvent(event.windowID, event.mouseID, event.modifiers,
														   event.position, event.buttonChanged, event.buttons,
														   overWidget);
					used = 
						win.propagateEvent(mouseClickedEvent, overWidget) == EventUsed.yes || 
						used == EventUsed.yes ? EventUsed.yes : EventUsed.no;
					mouseClickedEvent.dispose();
					win._clickWidgetID = win._downButtonWidgetID;
					win.setKeyboardFocusWidget(win._clickWidgetID);
				}
			}
			win._downButtonWidgetID = NullWidgetID;
			return used;
		}
	
		EventUsed onMouseWheelEvent(MouseWheelEvent event)
		{
			EventUsed used = EventUsed.no;
			if (win._mouseWidgetID != NullWidgetID)
			{
				auto overWidget = safeDeref(win._mouseWidgetID in win.widgets);
				used = win.propagateEvent(event, overWidget);
			}
			return used;
		}

		private EventUsed dispatchToFocussedWidget(GUIEvent event)
		{
			EventUsed used = EventUsed.no;

			//std.stdio.writeln("dxx ", event.type, " ", keyboardFocusWidget);
			if (win._keyboardFocusWidgetID != NullWidgetID)
			{
				Widget * w = win._keyboardFocusWidgetID in win.widgets;
				if (w is null)
					win.setKeyboardFocusWidget(NullWidgetID);
				else
					used = win.propagateEvent(event, *w);
			}
			return used;
		}

		EventUsed onInputFocusEvent(InputFocusEvent event)
		{
			// input focus events are created by this window itself and shouldn't be handled
			return EventUsed.no;
		}

		EventUsed onInputUnfocusEvent(InputUnfocusEvent event)
		{
			// input unfocus events are created by this window itself and shouldn't be handled
			return EventUsed.no;
		}

		EventUsed onWindowFocussedEvent(WindowFocussedEvent event)
		{
			return EventUsed.no;
		}

		EventUsed onWindowUnfocussedEvent(WindowUnfocussedEvent event)
		{
			return EventUsed.no;
		}

		EventUsed onCommandEvent(CommandEvent event)
		{
			return dispatchToFocussedWidget(event);
		}

		EventUsed onKeyPressedEvent(KeyPressedEvent event)
		{
			return dispatchToFocussedWidget(event);
		}

		EventUsed onKeyReleasedEvent(KeyReleasedEvent event)
		{
			return dispatchToFocussedWidget(event);
		}

		EventUsed onTextEvent(TextEvent event)
		{
			return dispatchToFocussedWidget(event);
		}

		EventUsed onWindowResizedEvent(WindowResizedEvent event)
		{
			EventUsed used = EventUsed.no;
			win.size = event.size;

			if (win.styleSheet is null)
				return used; // Cannot do styling without a stylesheet

			win.updateLayout(false, this);

			bool cont = false;
			int maxIter = 5;
		
			// Resize events will let widget do relayouts.
			do
			{
				cont = false;
				foreach (w; win.widgets)
				{
					cont |= win.propagateEvent(event, w) == EventUsed.yes;
				}
			} while (cont && maxIter--);
		
			return used;
		}

		EventUsed onStyleSheetChangedEvent(StyleSheetChangedEvent event)
		{
			foreach (w; win.widgets)
			{
				win.propagateEvent(event, w);
				w.recalculateStyle();
			}
			return EventUsed.yes; // we recalculated style for all widgets and thus used the event
		}
	}
}
