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
import std.signals;
import std.stdio;
import std.typecons;

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

class Window : Widget
{
	// Return true if event has been used
	alias EventUsed delegate(ref Event) OnEvent;
	alias void delegate() OnUpdate;

	private
	{
		OnEvent _onEvent;
		OnUpdate _onUpdate;
		RenderTarget _renderTarget;
		
		Widget[WidgetID] widgets;

		// partial mapping name to widgets because we do not want
		// to have name on all widgets and therefore the name is
		// not a member of Widget.
		Widget[string] widgetNameMap; 		
	}

	std.variant.Variant userData;
	WindowID id;
	StyleSheet styleSheet;
	Timeline timeline;

	// emit(this)
	mixin Signal!(Window) onUpdate;

	static Window active;
	
	override @property Window window() pure nothrow nothrow @safe
	{
		return this;
	}
	
	override @property const(Window) window() const pure nothrow @safe
	{
		return this;
	}

	@property 
	{
		void onEvent(OnEvent callback)
		{
			_onEvent = callback;
		}
	
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
	}

	void repaint()
	{
		foreach (wID, w; widgets)
			w.forceDirty();
	}

	Widget getWidget(string name)
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
		Event ev;
		Vec2f sz = super.size;
		ev.type = EventType.Resize;
		ev.width = cast(int)sz.x;
		ev.height = cast(int)sz.y;
		ev.windowID = this.id;
		dispatchEvent(ev);
	}

	void onStyleSheetChanged()
	{
		Event ev;
		ev.type = EventType.StyleSheetChanged;
		ev.windowID = this.id;
		dispatchEvent(ev);
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

	this(const(char)[] name, Vec2i sz)
	{
		this(name, sz.x, sz.y);
	}

	this(const(char)[] _name, int width, int height) 
	{
		auto renderWin = new RenderWindow(_name, width, height);
		this(_name, width, height, renderWin);
	}

	this(const(char)[] _name, int width, int height, RenderTarget _renderTarget) 
	{
		super(0f,0f,width,height);
		setWidgetName(this, _name.idup);
		this._renderTarget = _renderTarget;
		id = _renderTarget.id;
		register(this);
		keyboardFocusWidget = this.id;

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
		
		mouseWidgets.length = 0;
		mouseWidgets.assumeSafeAppend();

		foreach (k; widgets.keys)
		{
			Widget w = widgets[k];

			//std.stdio.writeln(w.name, " visible ", w.visible, w.rect);
			//if (w.visible && w.rectStyled.contains(p))
			if (w.visible && w.rect.contains(p))
			{
				mouseWidgets ~= w.id;

				//std.stdio.writeln("hit ", w.name);
				bool isDecentSameDepth = (cur is null || w.zOrder == cur.zOrder) && w.isDecendantOf(cur);
				if ( isDecentSameDepth || w.isInFrontOf(cur) )
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
		foreach (w; widgets)
		{
			if (w !is this)
				w.update();
		}

		onUpdate.emit(this);

		if (_sizeDirty)
		{
			_sizeDirty = false;
			emitResizeEvent();
		}

		//if (_onUpdate !is null)
		//    _onUpdate();
	}

	override void draw()
	{
		_renderTarget.render(false);
		super.draw();
		_renderTarget.swapBuffers();
	}

	// The widget that the mouse left button has been clicked down on
	private WidgetID downButtonWidget = NullWidgetID;
	
	// The widget that has been clicked by the left mouse button
	private WidgetID clickWidget = NullWidgetID;
	
	// Number of times the click widget has been clicked. To detext double/triple... clicks
	private int clickWidgetClicks = 0;

	private WidgetID mouseWidget = NullWidgetID; // top most
	private WidgetID[] mouseWidgets = null; // all stack
	private WidgetID mouseGrabbedBy = NullWidgetID;
	private WidgetID keyboardFocusWidget = NullWidgetID;

	// The time of the last click on a widget in this window
	private TickDuration clickWidgetTime;

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

	Widget getWidget(WidgetID id)
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

	void setKeyboardFocusWidget(WidgetID wid)
	{
		// Find widget that accepts keyboard focus from wid
		// and though parents if any. This bubbling is not handled by
		// the normal widget.send(..) mechanism because we need to
		// send unfocus event only if any widget will accept the
		// keyboard focus which is not always the case.
	
		if (wid == keyboardFocusWidget)
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

		if (w.id == keyboardFocusWidget)
			return; // already in focus

		auto ow = keyboardFocusWidget in widgets;

		if (w !is null && w.acceptsKeyboardFocus)
		{
			if (ow !is null)
				ow.send(Event(EventType.KeyboardUnfocus));

			w.send(Event(EventType.KeyboardFocus));
			keyboardFocusWidget = w.id;
		}
		else if (ow is null)
		{
			keyboardFocusWidget = id; // fallback to window as focus
		}
	}

	bool hasKeyboardFocus(const(Widget) w) const pure nothrow @safe
	{
		return keyboardFocusWidget == w.id;
	}

	Widget getKeyboardFocusWidget()
	{
		return getWidget(keyboardFocusWidget);
	}

	bool isMouseOverWidget(const(Widget) w) const pure nothrow @safe
	{
		foreach (hitID; mouseWidgets)
			if (hitID == w.id)
				return true;
		return false;
		//	return mouseWidget == w.id;
	}

	bool isMouseDirectlyOverWidget(const(Widget) w) const pure nothrow @safe
	{
		return mouseWidget == w.id;
	}

	bool isMouseDownWidget(const(Widget) w) const pure nothrow @safe
	{
		return downButtonWidget != NullWidgetID && isMouseOverWidget(w);
	}

	bool isMouseDirectlyDownWidget(const(Widget) w) const pure nothrow @safe
	{
		return downButtonWidget == w.id;
	}

	void grabMouse(const(Widget) w) pure nothrow @safe
	{
		assert(mouseGrabbedBy == NullWidgetID);
		mouseGrabbedBy = w.id;
	}

	bool isGrabbingMouse(const(Widget) w) const pure nothrow @safe
	{
		return w.id == mouseGrabbedBy;
	}
	
	override void releaseMouse() pure nothrow @safe
	{
		// assert(mouseGrabbedBy != NullWidgetID);
		mouseGrabbedBy = NullWidgetID;
	}

/*
	package void dispatchEvent(Event ev)
	{
		assert(ev.windowID == id);
		if (ev.type == EventType.Invalid)
			return;

		bool hasCallback = _onEvent !is null;
		bool callbackUsedEvent = false;
		if (hasCallback)
			callbackUsedEvent = _onEvent(ev) == EventUsed.yes;

		// Handle will be false if onEvent is not set or onEvent did not handle the event.
		// In that case fall back.
		if (!callbackUsedEvent)
			dispatch(ev);
	}
*/
	
	package void dispatchEvent(Event ev)
	{
		assert(ev.windowID == id);
		if (ev.type == EventType.Invalid)
			return;
		
		if (_onEvent !is null && _onEvent(ev) == EventUsed.yes)
			return;

		auto eventUsed = dispatch(ev);
		if (eventUsed == EventUsed.yes)
			return;
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
	EventUsed dispatch(Event event)
	{
		bool eventHasMousePos = event.type == EventType.MouseMove || event.type == EventType.MouseUp || event.type == EventType.MouseDown;
		EventUsed used = EventUsed.no;
		WidgetID lastMouseWidget = mouseWidget;

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
		if (event.type == EventType.MouseDown)
		{
			std.stdio.writeln("Fdsa");
		}
		if (event.type == EventType.MouseUp)
		{
			std.stdio.writeln("Fdsa");
		}

		// !not all events have a mouse pos! remember last mouse pos if needed
		if (eventHasMousePos)
		{
			auto _mouseWidget = getWidgetAtPos(event.mousePos);
		//		if (event.mousePos.x < 0.0000001)
		//			std.stdio.writeln("mousePos ", event.mousePos, " ", event.type); // Dbg only.
			mouseWidget = _mouseWidget is null ? NullWidgetID : _mouseWidget.id;
		}

		if (mouseGrabbedBy)
			mouseWidget = mouseGrabbedBy;
		
		Widget * overWidget = null; 
		if (mouseWidget)
			overWidget = mouseWidget in widgets;
		
		// Send events to the found widget
		//std.stdio.writeln(event.type);
		switch (event.type)	
		{
			case EventType.MouseMove:
				if (lastMouseWidget != mouseWidget)
				{
					// If a click has been initiated by a mouse down and the mouse 
					// goes away from the widget the click is aborted.
					downButtonWidget = NullWidgetID;
					clickWidget = NullWidgetID;
					clickWidgetClicks = 0;

					// Handle mouse out events
					if (lastMouseWidget != NullWidgetID)
					{
						Widget * outWidget = lastMouseWidget in widgets;
						
						// Bubbling to parents lets a parent handle all out events for its children 
						// which can be convenient
						if (outWidget)
						{
							event.type = EventType.MouseOut;
							event.overWidgetID = overWidget is null ? NullWidgetID : overWidget.id;
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
					clickWidgetClicks = 0;
				}
				break;
			case EventType.MouseDown:
				if (overWidget)
				{
					downButtonWidget = mouseWidget;
					used = overWidget.send(event);
					if (clickWidget != NullWidgetID)
					{
						// check for double and triple click
						TickDuration tdur = TickDuration.currSystemTick;
						float doubleClickTime = tdur.to!("seconds",float)() - clickWidgetTime.to!("seconds",float)();
						if (clickWidgetClicks != 3 && downButtonWidget == clickWidget && doubleClickTime <= maxDoubleClickTime)
						{
							clickWidgetClicks++;

							if (clickWidgetClicks == 2)
								event.type = EventType.MouseDoubleClick;
							else if (clickWidgetClicks == 3)
								event.type = EventType.MouseTripleClick;

							used = overWidget.send(event) == EventUsed.yes || used == EventUsed.yes ? EventUsed.yes : EventUsed.no;							
						}
						else
						{
							clickWidgetClicks = 0;
							clickWidget = NullWidgetID;
						}
					}
				}
				else
				{
					downButtonWidget = NullWidgetID;
					clickWidget = NullWidgetID;
					clickWidgetClicks = 0;
				}
				break;
			case EventType.MouseUp:
				if (overWidget)
				{
					used = overWidget.send(event);
					TickDuration tdur = TickDuration.currSystemTick;
					float doubleClickTime = tdur.to!("seconds",float)() - clickWidgetTime.to!("seconds",float)();
					bool allowClick = clickWidgetClicks == 0; //  || (doubleClickTime > maxDoubleClickTime;

					if (downButtonWidget == mouseWidget && allowClick)
					{
						clickWidgetClicks = 1;
						event.type = EventType.MouseClick;
						used = overWidget.send(event) == EventUsed.yes || used == EventUsed.yes ? EventUsed.yes : EventUsed.no;
						clickWidget = downButtonWidget;
						clickWidgetTime = TickDuration.currSystemTick;
						setKeyboardFocusWidget(clickWidget);
					}
				}
				downButtonWidget = NullWidgetID;
				break;
			case EventType.MouseScroll:
				if (overWidget !is null)
					overWidget.send(event);
				break;
			case EventType.KeyDown:
			case EventType.KeyUp:
			case EventType.Text:
			case EventType.Command:

				//std.stdio.writeln("dxx ", event.type, " ", keyboardFocusWidget);
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

				layout(false);

				bool cont = false;
				int maxIter = 5;
				// Resize events will let widget do relayouts. 
				do
				{
					cont = false;
					foreach (w; widgets)
					{
						cont |= w.send(event) == EventUsed.yes;
					}
				} while (cont && maxIter--);
				
				break;
			case EventType.StyleSheetChanged:
				foreach (w; widgets)
					w.send(event);
				break;
			default:
				break;
		}
		
		// TODO: fix
		// FIX: this
		//if (Widget.keyboardFocusWidget == NullWidgetID && Widget.widgets.length != 0 ) {}
		//Widget.setKeyboardFocusWidget(Widget.widgets[Widget.widgets.keys()[0]].id); 
		return used;
	}
}
