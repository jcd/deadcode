module gui.widget;

import animation.mutator;
import animation.timeline;

import graphics._;
import gui.event;
import gui.style;
import gui.widgetfeature._;
import gui.window;
import math._; // Rectf;

import std.signals;

// widget
// control

// Behaviors:
//   Grab mouse       : 
//   Drag (drag area) : +windows, -controls
//   Dock             : +windows, -controls
//   Focus            : ++
//   Layout           : +windows, -controls
//   Constraints      : ++
//   Style            : +windows, +control
//   Animation        : ++
//   MouseSensitivity : ++ (considered for mouse interaction)

alias uint WidgetID;
enum NullWidgetID = 0u;

enum _traceDirty = false;

void _printDirty(lazy const(char)[] name)
{
	static if (_traceDirty)
	{
		import core.sys.windows.stacktrace;
		//std.stdio.writeln(name, " dirty ", new StackTrace());
		std.stdio.writeln(name);
	}
}

alias Widget[] Widgets;

class Widget : Stylable
{	
	private static WidgetID _nextID = 1u;

	WidgetID id;
	string _name;

	float zOrder;

	bool acceptsKeyboardFocus;
	bool manualLayout;

	// Events
	alias EventUsed delegate(Event event, Widget widget) OnEvent;
	OnEvent[EventType] events;

	//struct StyleState
	//{
	//    Style targetStyle; // Can be null in the case where style has reached the target style
	//    Style style;       // The style going towards target style using transition settings. (instant per default)
	//}
	//
	//StyleState styleState;

	Style _targetStyle;
	Timeline.Runner runner;
	Style _style;

	WidgetFeature[] features;
	NineGridRenderer _background;

	const(string[]) classes() const pure nothrow @safe { return null; }

	mixin Signal!(Event) onKeyboardFocusSignal;
	mixin Signal!(Event) onKeyboardUnfocusSignal;

	// Convenience accessors
	@property NineGridRenderer background()
	{
		Style st = style;
		if (st !is null && st.background is null)
		{
			_background = null;
			return null;
		} 
		else if (_background is null)
		{
			_background = new NineGridRenderer();
		}
		return _background;
	}

	//    foreach (f; features)
	//    {
	//        NineGridRenderer r = cast(NineGridRenderer)f;
	//        if (r)
	//            return r;
	//    }
	//    return null;
	//}

	//@property bool backgroundEnabled()
	//{
	//    return background !is null;
	//
	//    foreach (ref f; features)
	//    {
	//        NineGridRenderer r = cast(NineGridRenderer)f;
	//        if (r)
	//        {
	//            f = newBg;
	//        }
	//    }
	//
	//    WidgetFeature item = newBg;
	//    features = [item] ~ features;
	//}

	@property Style style()
	{
		// Get the style that this widget is supposed to have.
		// In case the widgets current active style is not that style
		// and the target style has transitions set we need to 
		// animate style changes.
		Style newTargetStyle = window.styleSheet.getStyle(this, classes);

		if (_style is null)
		{
			_style = newTargetStyle;
			//_style = newTargetStyle.clone();
			_targetStyle = newTargetStyle;
		}
		else if (_targetStyle !is newTargetStyle)
		{
			_targetStyle = newTargetStyle;

			if (_targetStyle.hasTransitions)
			{
				if (_style.styleSheet !is null)
				{
					// A transition animation is going to be done and the current style
					// is owned by a style sheet. Make a clone that the widget can own and
					// animate.
					_style = _style.clone();
					_style.styleSheet = null;
				}

				import animation.interpolate;
				auto clip = new Clip!Style();
				//clip.createCurves!CubicCurve(0, _style, 0.5, _targetStyle);
				snapshotInterpolatedStyle();
				clip.createCurves(_style, _targetStyle);
				// clip.createCubicCurve!"x"(0, x, 1, x+100.0);
				if (runner !is null)
					runner.abort();
				runner = window.timeline.animate(_style, clip);
			}
			else 
			{
				if (runner !is null)
					runner.abort();

				if (_style.styleSheet is null)
					destroy(_style);
				
				_style = _targetStyle;
			}
		}

		return _style;
	}
	
	// Copy current dimensions of this widget to it style in order to use the style as starting point for 
	// an animation.
	private void snapshotInterpolatedStyle()
	{
		assert(_style.styleSheet is null);
		CSSScale nullScale = CSSScale(0, CSSUnit.pixels);
		// Vec2f p = calcPosition(_style);

		_style.position = CSSPosition.fixed;
		_style.right = nullScale;
		_style.bottom = nullScale;

		_style.left = CSSScale(_rect.x, CSSUnit.pixels);
		_style.top = CSSScale(_rect.y, CSSUnit.pixels);
		_style.width = CSSScale(_rect.w, CSSUnit.pixels);
		_style.height = CSSScale(_rect.h, CSSUnit.pixels);
	}

	/*
	@property Style style()
	{
		// Get the style that this widget is supposed to have.
		// In case the widgets current active style is not that style
		// and the target style has transitions set we need to 
		// animate style changes.
		Style newTargetStyle = window.styleSheet.getStyleForWidget(this);
		
		return newTargetStyle;
		//if (_style.matchesStyle(newTargetStyle))
		//    return _style;

		// Got a new target. Schedule transitions if necessary. (and abort existing)
		
	}
	*/

	//
	//private void onStyleChanged(UsedStyle s)
	//{
	//    if (s !is _style)
	//        s.onChanged.disconnect(&onStyleChanged);
	//    else
	//        _sizeDirty = true; // force a redraw... TODO: this also forces layout which is wrong (maybe)
	//}

	//Style getStyleForClass(string className)
	//{
	//    return window.styleSheet.getStyle(this, [className]);
	//}

	//void transition(Property*


	bool visible;

	protected
	{
		@Bindable()
		Rectf _rect;  // rect for events like mouse over etc.
		bool _sizeDirty;
		Widget _parent;
		Widgets _children;
	}

	private void eventCallbackHelper(EventType t, EventUsed delegate(Event, Widget) del)
	{
		if (del is null)
			events.remove(t);
		else
			events[t] = del;
	}

	@property 
	{
		Widget closestNamed()
		{
			Widget cur = this;
			while (cur !is null && cur.name is null)
				cur = cur.parent;
			return cur;
		}

		string[] nameStack()
		{
			string[] result;
			Widget cur = this;
			while (cur !is null)
			{
				auto n = cur.name;
				if (n !is null)
					result ~= n;
			}
			return result;
		}

		string name() const pure nothrow @safe 
		{
			return _name;
		}

		void name(string n) nothrow
		{
			_name = n;
			if (window !is null)
				window.setWidgetName(this, n);
		}

		bool matchStylable(string stylableName) const pure nothrow @safe
		{
			return matchStylableImpl(this, stylableName);
		}

		/*
		ref Rectf rect() 
		{
			_printDirty("rect");
			_sizeDirty = true;
			return _rect;
		}
		*/

		void rect(Rectf r)
		{
//			import core.sys.windows.stacktrace;
			if (r != _rect)
			{
				_sizeDirty = true;
				_rect = r;
				//_printDirty("rect");
			}
		}

		const(Rectf) rect() const
		{
			return _rect;
		}

		package void forceDirty()
		{
			_sizeDirty = true;
		}

		//const(Rectf) rectStyled() 
		//{
		//    return calcRect(style);
		//    //auto st = style;
		//    //final switch (st.position)
		//    //{
		//    //    case CSSPosition.fixed:
		//    //        if (this is window)
		//    //            return calcRect(_rect, st);
		//    //        return calcRect(window.rectStyled, st);
		//    //    case CSSPosition.absolute:
		//    //        Widget p = parent; // lookFirstPositionedParent();
		//    //        if (p is null)
		//    //            return calcRect(_rect, st);
		//    //        return calcRect(p.rectStyled, st);
		//    //    case CSSPosition.relative:
		//    //        return calcRect(_rect, st);
		//    //    case CSSPosition.static_:
		//    //        break;
		//    //    case CSSPosition.invalid:
		//    //        break;
		//    //}
		//    return _rect;
		//}

/*
		private const(Rectf) calcBaseRectForPosition(CSSPosition cssPos)
		{
			Rectf res = _rect;
			final switch (cssPos)
			{
				case CSSPosition.fixed:
					if (this !is window)
						res = window.rect;
					else
						return rect;
				case CSSPosition.absolute:
					Widget p = parent; // lookFirstPositionedParent();
					if (p !is null)
						res = p.rect;
					else
						return rect();
				case CSSPosition.relative:
					break;
				case CSSPosition.static_:
					return _rect;
					break;
				case CSSPosition.invalid:
					return _rect;
					break;
			}
			
			Widget p = parent; // lookFirstPositionedParent();
			if (p is null)
				res.size = window.size;
			else
				res.size = p.size;

			return res;
		}
*/

		/*
		// Like .rect but with padding applied
		const(Rectf) contentRect()
		{
			auto st = style;
			return _rect.offset(st.padding);
		}

		// Like .rect but with padding applied
		void contentRect(Rectf r)
		{
			auto st = style;
			rect = _rect.offset(st.padding.reverse());
		}
*/
		const(Vec2f) size() const
		{
			return _rect.size;
		}

		void size(Vec2f sz)
		{
			_printDirty("size");
			_sizeDirty = true;
			_rect.size = sz;
		}

		const(Vec2f) intrinsicSize() {
			Vec2f invalid;
			return invalid;
		}

		void size(Vec2i sz)
		{
			size = Vec2f(sz.x, sz.y);
		}

		const(Vec2f) preferredSize() 
		{
			return size;
		}

		void preferredSize(Vec2f prefSize) 
		{
						
		}

		const(Vec2f) minSize() 
		{
			return preferredSize;
		}

		void minSize(Vec2f mSize) 
		{
		}

		const(Vec2f) maxSize() 
		{
			return preferredSize;
		}

		void maxSize(Vec2f mSize) 
		{
		}

		ref float x() 
		{
			return _rect.x;
		}
	
		const(float) x() const
		{
			return _rect.x;
		}

		ref float y() 
		{
			return _rect.y;
		}
		
		const(float) y() const
		{
			return _rect.y;
		}

		ref float w() 
		{
			_printDirty("w");
			_sizeDirty = true;
			return _rect.w;
		}
		
		const(float) w() const
		{
			return _rect.w;
		}

		@Bindable()
		void h(float value) 
		{
			//std.stdio.writeln("h ", name, " ", _rect.h);
			if (_rect.h != value)
			{
				_printDirty("h");
				_sizeDirty = true;
				_rect.h = value;
			}
		}
		
		@Bindable()
		const(float) h() const
		{
			return _rect.h;
		}

		Vec2f pos()
		{
			return _rect.pos;
		}
		
		void pos(Vec2f p)
		{
			_rect.pos = p;
		}

		bool sizeChanged()
		{
			return _sizeDirty;
		}

		void onMouseClickCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.MouseClick, del); }
		void onMouseOverCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.MouseOver, del); }
		void onMouseOutCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.MouseOut, del); }
		void onMouseScrollCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.MouseScroll, del); }
		void onKeyDownCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.KeyDown, del); }
		void onKeyUpCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.KeyUp, del); }
		void onTextCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.Text, del); }
		void onCommandCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.Command, del); }

			
		/// XXX: Doing cursor shapes! But these callbacks need to be signals because several listeners must be possible!.
		void onKeyboardFocusCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.KeyboardFocus, del); }
		void onKeyboardUnfocusCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.KeyboardUnfocus, del); }
	}

	void moveBy(float x, float y)
	{
		_printDirty("moveBy");
		_sizeDirty = true;
		_rect.x += x;
		_rect.y += y;
	}

	void moveTo(float x, float y)
	{
		_printDirty("moveTo");
		_sizeDirty = true;
		_rect.x = x;
		_rect.y = y;
	}
		
	void resizeBy(float x, float y)
	{
		_printDirty("resizeBy");
		_sizeDirty = true;
		_rect.x += x;
		_rect.y += y;
	}
	
	void resizeTo(float x, float y)
	{
		_printDirty("resizeTo");
		_sizeDirty = true;
		_rect.w = x;
		_rect.h = y;
	}

	@property Window window() pure nothrow nothrow @safe
	{
		return _parent is null ? null : _parent.window;
	}

	@property const(Window) window() const pure nothrow @safe
	{
		return _parent is null ? null : _parent.window;
	}

	/*
	@property Application app()
	{
		auto w = window;
		return w is null ? null : w.app;
	}
	*/

	@property Widget parent() pure nothrow @safe
	{
		return _parent;
	}
	
	@property void parent(Widget newParent) nothrow
	{
		if (newParent is _parent)
			return; // noop

		if (newParent is null)
		{
			if (window !is null)
				window.deregister(this);	
			removeFromParent();
			_parent = null;
			return;
		}

		newParent.addChild(this);		
	}

	/*
	 * Returns: true if this widget was removed from a parent ie. it had a parent
	 */
	private bool removeFromParent() nothrow
	{
		return _parent !is null && _parent.removeChild(this);
	}

	private void addChild(Widget w) nothrow
	{
		Window oldWindow = w.window;
		w.removeFromParent();
		w._parent = this;

		if (oldWindow !is null && oldWindow !is window)
			oldWindow.deregister(w);

		if (oldWindow !is window && window !is null)
			window.register(w);

		_children ~= w;
	}

	/*
	 * Returns: true is toRemove was removed from this widget ie. was a child
	 */
	protected bool removeChild(Widget toRemove) nothrow
	{
		size_t len = _children.length;
		_children = std.array.array(std.algorithm.filter!((Widget tw) { return tw.id != toRemove.id; })(_children));
		window.deregister(toRemove);
		return len != _children.length;
	}

	@property Widgets children() nothrow
	{
		return _children;
	}

	Widget getChildByName(string childName) nothrow pure @safe
	{
		if (childName.empty)
			return null;
		
		foreach (w; _children)
			if (w.name == childName)
				return w;
		return null;
	}

	void hideChildren()
	{
		foreach (child; _children)
			child.visible = false;
	}

	bool isDecendantOf(Widget w)
	{
		Widget p = parent;
		while (p !is null && w !is p)
		{
			p = p.parent;
		}

		return w is p;
	}

	bool isAncestorOf(Widget w)
	{
		return w.isDecendantOf(this);
	}

	void setKeyboardFocusWidget()
	{
		assert(window !is null);
		window.setKeyboardFocusWidget(this);
	}

	@property bool hasKeyboardFocus() const pure nothrow @safe
	{
		assert(window !is null);
		return window.hasKeyboardFocus(this);
	}

	@property bool isMouseOver() const pure nothrow @safe
	{
		assert(window !is null);
		return window.isMouseOverWidget(this);
	}

	@property bool isMouseDown() const pure nothrow @safe
	{
		assert(window !is null);
		return window.isMouseDownWidget(this);
	}

	void grabMouse()
	{
		assert(window !is null);
		window.grabMouse(this);
	}

	bool isGrabbingMouse()
	{
		assert(window !is null);
		return window.isGrabbingMouse(this);
	}

	void releaseMouse()
	{
		assert(window !is null);
		window.releaseMouse();
	}

	package this(WidgetID _id, Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		assert(_parent !is null);
		this(_id, x, y, width, height);
		this.parent = _parent;
//		if (window !is null)
//			window.register(this);
	}

	package this(WidgetID _id, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		//this(Rectf(x, y, x+w, y+h), _parentId);
		manualLayout = false;
		visible = true;
		zOrder = 0f;
		_sizeDirty = true;
		_rect = Rectf(x, y, width, height);
		id = _id == NullWidgetID ? _nextID++ : _id;
		this.acceptsKeyboardFocus = false;
	}

	this(Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		this(NullWidgetID, _parent, x, y, width, height);
	}

	this(float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		this(NullWidgetID, x, y, width, height);
	}

	final EventUsed send(Event event)
	{
		if (event.type == EventType.KeyboardFocus)		
		{
			onKeyboardFocusSignal.emit(event);
		}
		else if (event.type == EventType.KeyboardUnfocus)		
		{
			onKeyboardUnfocusSignal.emit(event);
		}

		//if (event.type == EventType.KeyDown)
		//	std.stdio.writeln("event ", event, " to ", this.id);
		OnEvent * handler = event.type in events;

		EventUsed used = EventUsed.no;
		
		if (event.type == EventType.MouseClick)
			std.stdio.writeln("fdsaf");

		if (handler)
		{
			used = (*handler)(event, this);
		}
		else
		{ 
			handler = EventType.Default in events;
			if (handler)
				used = (*handler)(event, this);
		}

		auto bg = background;
		if (!used && bg !is null)
			used = bg.send(event, this);

		foreach (f; features)
		{
			if (used)
				break;
			used = f.send(event, this);
		}

		if (used == EventUsed.no)
			used = onEvent(event);

		// Bubble up through parents
		if (used == EventUsed.no && _parent !is null)
		{
			//std.stdio.writeln("parent ev");
			used = parent.send(event);
		}

		return used;
	}

	EventUsed onEvent(Event event)
	{
		mixin(ctGenerateEventCallbackSwitch());
	}

	mixin(ctGenerateEventCallbacks());

	protected void drawFeatures()
	{
		auto bg = background;
		if (bg !is null)
			bg.draw(this);

		// Draw features
		foreach (f; features)
		{
			f.draw(this);
		}	
	}

	protected void drawChildren()
	{
		// Draw children
		foreach (w; children)
		{
			w.draw();
		}
	}

	void layoutFeatures(bool fit)
	{
		foreach (f; features)
			f.layout(this, fit);
	}

	protected void layoutChildren(bool fit)
	{
		foreach (w; children)
			w.layout(fit);
	}

	//private void recalcSize()
	//{
	//    _rect.size = calcSize(this);
	//}

	//protected void recalcPosition()
	//{
	//    //if (parent !is null && id == 8)
	//    //    std.stdio.writeln("pospre ", _rect.pos.v);
	//    _rect.pos = calcPosition(this);
	//    //if (id == 8)
	//    //    std.stdio.writeln("c ", _rect.size.y);
	//    //if (parent !is null && id == 8 && _rect.pos.x != 200)
	//    //{
	//    //    std.stdio.writeln("pospost ", _rect.pos.v);
	//    //    calcPosition(style);
	//    //    std.stdio.writeln("pospost ", _rect.pos.v);
	//    //}
	//}

	protected void calculateSize()
	{
		size = calcSize(this);
	}

	protected void calculatePosition()
	{
		pos = calcPosition(this);
	}

	void layout(bool fit)
	{
		// Get sized ready for the children so that any layouter have them
		foreach (w; children)
			if (!w.manualLayout)
				w.calculateSize();

		layoutFeatures(false);

		// Position goes last so that a base position calculated by e.g. DirectionalLayout feature
		// can be used as relative pos for the calcPosition (ie. the styled position)
		foreach (w; children)
			if (!w.manualLayout)
				w.calculatePosition();

		// Positions and sizes for children are now set and we can recurse
		layoutChildren(fit);
	}

	void draw()
	{
		if (!visible)
			return;

		drawFeatures();
		drawChildren();
	}

	void update()
	{		
		// TODO: check for convergence
		// TODO: only re-iterate features that asks for it e.g. constraints
		for (int i = 0; i < 1; i++) 
		{
			//activeStyle.model.transform = activeStyle.model.transform * Mat4f.makeTranslate(Vec3f(0.0005f,0f,0f));
			
			//onLayout();
			//for (int j = 0; j < 10000; j++) 
			auto bg = background;	
			if (bg !is null)
				bg.update(this);
			foreach (f; features)
			{
				f.update(this);
			}			
		}

		if (_sizeDirty)
		{
			// Send resize event to children
			_sizeDirty = false;

			if (window !is null)
			{
				window._sizeDirty = true;
			}
		}

		// TODO: remove from here since win.update runs on all widget ie. widget that does not
		// get update calls is because that have not registered with win.
//		foreach (w; children)
//		{
//			w.update();
//		}


//		OnEvent * handler = EventType.Update in events;
		
//		if (handler)
//			(*handler)(Event(EventType.Update), this);

		/*
	//	Rectf wrect = Window.active.windowToWorld(rect);
	//	float[] vert = quadVertices(wrect);
	//	float[] uv = quadUVs(wrect, activeStyle.model.material, Window.active);
		activeStyle.model.mesh.buffers[0].setData(vert);
		activeStyle.model.mesh.buffers[1].setData(uv);
		activeStyle.model.draw();
  */
	}

	void getScreenOffsetToWorldTransform(ref Mat4f transform)
	{
		Rectf wrect = window.windowToWorld(rect);

		// Since text are layed out using pixel coords we scale into world coords
		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
	}

	void getScreenToWorldTransform(ref Mat4f transform)
	{
		//		Rectf wrect = widget.window.windowToWorld(widget.rect);

		// Since text are layed out using pixel coords we scale into world coords
		Vec2f scale = window.pixelSizeToWorld(Vec2f(1,1));
		getScreenOffsetToWorldTransform(transform);
		//		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0)) * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
		transform = transform * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
	}

	void getStyledScreenOffsetToWorldTransform(ref Mat4f transform)
	{
//		Rectf wrect = window.windowToWorld(rectStyled);
		Rectf wrect = window.windowToWorld(rect);

		// Since text are layed out using pixel coords we scale into world coords
		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
	}

	void getStyledScreenToWorldTransform(ref Mat4f transform)
	{
		//		Rectf wrect = widget.window.windowToWorld(widget.rect);

		// Since text are layed out using pixel coords we scale into world coords
		Vec2f scale = window.pixelSizeToWorld(Vec2f(1,1));
		getStyledScreenOffsetToWorldTransform(transform);

		//		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0)) * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
		transform = transform * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
	}

}

bool isInFrontOf(Widget isThis, Widget inFrontOfThis)
{
	return isThis.window.isWidgetInFrontOfWidget(isThis, inFrontOfThis);
}
