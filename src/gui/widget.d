module gui.widget;

import graphics._;
import gui.event;
import gui.style;
import gui.widgetfeature._;
import gui.window;
import math._; // Rectf;

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
		std.stdio.writeln(name, " dirty ", new StackTrace());
	}
}

alias Widget[] Widgets;

class Widget 
{	
	private static WidgetID _nextID = 1u;

	WidgetID id;

	float zOrder;

	bool acceptsKeyboardFocus;
			
	// Events
	alias EventUsed delegate(Event event, Widget widget) OnEvent;
	OnEvent[EventType] events;

	WidgetFeature[] features;

	bool visible;

	protected
	{
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

		string name()
		{
			return window.lookupWidgetName(this.id);
		}

		void name(string n)
		{
			return window.setWidgetName(this, n);
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
			_printDirty("rect");
			_sizeDirty = true;
			_rect = r;
		}

		const(Rectf) rect() const
		{
			return _rect;
		}

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

		void size(Vec2i sz)
		{
			size = Vec2f(sz.x, sz.y);
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

		ref float h() 
		{
			//std.stdio.writeln("h ", name, " ", _rect.h);
			_printDirty("h");
			_sizeDirty = true;
			return _rect.h;
		}
		
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
		void onMouseScrollCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.MouseScroll, del); }
		void onKeyDownCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.KeyDown, del); }
		void onTextCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(EventType.Text, del); }
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


	@property Window window()
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

	@property Widget parent()
	{
		return _parent;
	}
	
	@property void parent(Widget newParent)
	{
		Window oldWindow = window;
		removeFromParent();
		_parent = newParent;

		if (oldWindow !is window)
		{
			if (oldWindow !is null)
				oldWindow.deregister(this);
			if (window !is null)
				window.register(this);
		}

		if (_parent !is null)
			_parent.addChild(this);
	}

	/*
	 * Returns: true if this widget was removed from a parent ie. it had a parent
	 */
	private bool removeFromParent()
	{
		return _parent !is null && _parent.removeChild(this);
	}

	private void addChild(Widget w)
	{
		_children ~= w;
	}

	/*
	 * Returns: true is toRemove was removed from this widget ie. was a child
	 */
	private bool removeChild(Widget toRemove)
	{
		size_t len = _children.length;
		_children = std.array.array(std.algorithm.filter!((Widget tw) { return tw.id != toRemove.id; })(_children));
		return len != _children.length;
	}

	@property Widgets children()
	{
		return _children;
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
		foreach (c; _children)
			if (c is w || c.isAncestorOf(w))
				return true;
		return false;
	}

	void setKeyboardFocusWidget()
	{
		assert(window !is null);
		window.setKeyboardFocusWidget(this);
	}

	bool isKeyboardFocusWidget()
	{
		assert(window !is null);
		return window.isKeyboardFocusWidget(this);
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

	/*
	this(Rectf windowRect, WidgetID _parentId = NullWidgetID)
	{
		rect = windowRect;
		id = nextId++;
		this._parentId = _parentId;
		this.acceptsKeyboardFocus = false;
		
		widgets[id] = this;
		if (_parentId != NullWidgetID)
		{
	//		Widgets * w = _parentId in window._widgetChildren;
			if (w is null)
			{
		//		window._widgetChildren[_parentId] = [this];
			}
			else
			{
				*w ~= this;
			}
		}
	}
*/
	package this(WidgetID _id, Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100)
	{
		assert(_parent !is null);
		this(_id, x, y, width, height);
		this.parent = _parent;
//		if (window !is null)
//			window.register(this);
	}

	package this(WidgetID _id, float x = 0, float y = 0, float width = 100, float height = 100)
	{
		//this(Rectf(x, y, x+w, y+h), _parentId);
		visible = true;
		zOrder = 0f;
		_sizeDirty = true;
		_rect = Rectf(x, y, width, height);
		id = _id == NullWidgetID ? _nextID++ : _id;
		this.acceptsKeyboardFocus = false;
	}

	this(Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100)
	{
		this(NullWidgetID, _parent, x, y, width, height);
	}

	this(float x = 0, float y = 0, float width = 100, float height = 100)
	{
		this(NullWidgetID, x, y, width, height);
	}

	final EventUsed send(Event event)
	{

		//if (event.type == EventType.KeyDown)
		//	std.stdio.writeln("event ", event, " to ", this.id);
		OnEvent * handler = event.type in events;

		EventUsed used = EventUsed.no;
		
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

	void draw()
	{
		if (!visible)
			return;

		drawFeatures();
		drawChildren();
	}

	void update()
	{		
		if (_sizeDirty)
		{
			// Send resize event to children
			_sizeDirty = false;

			if (window !is null)
			{
				window._sizeDirty = true;
			}
		}


		// TODO: check for convergence
		// TODO: only re-iterate features that asks for it e.g. constraints
		for (int i = 0; i < 1; i++) 
		{
			//activeStyle.model.transform = activeStyle.model.transform * Mat4f.makeTranslate(Vec3f(0.0005f,0f,0f));
			
			//onLayout();
			//for (int j = 0; j < 10000; j++) 
				foreach (f; features)
				{
					f.update(this);
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
		float[] vert = quadVertices(wrect);
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

}

bool isInFrontOf(Widget isThis, Widget inFrontOfThis)
{
	return isThis.window.isWidgetInFrontOfWidget(isThis, inFrontOfThis);
}
