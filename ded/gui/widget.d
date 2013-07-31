module gui.widget;

import graphics._;
import gui.event;
import gui.style;
import gui.widgetfeature;
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
	
alias Widget[] Widgets;

final class Widget 
{	
	static WidgetID nextId = 1;

	WidgetID id;
	gui.window.Window window;

	Rectf rect;  // rect for events like mouse over etc.
	float zOrder;

	bool acceptsKeyboardFocus;
			
	// Events
	alias bool delegate(Event event, Widget widget) OnEvent;
	OnEvent[EventType] events;

	// Behavior
	WidgetFeature[] features;

	bool visible;

	private
	{
		Widget _parent;
	}

	private void eventCallbackHelper(EventType t, bool delegate(Event, Widget) del)
	{
		if (del is null)
			events.remove(t);
		else
			events[t] = del;
	}

	@property 
	{
		void onMouseClick(bool delegate(Event, Widget) del) { eventCallbackHelper(EventType.MouseClick, del); }
		void onKeyDown(bool delegate(Event, Widget) del) { eventCallbackHelper(EventType.KeyDown, del); }
		void onText(bool delegate(Event, Widget) del) { eventCallbackHelper(EventType.Text, del); }
	}

	@property Widget parent()
	{
		return _parent;
	}
	
	@property void parent(Widget newParent)
	{
		// Fixup the children map

		// Remove orig parent from children map
		if (_parent !is null)
		{
			Widgets* w = _parent.id in window._widgetChildren;

			if (w !is null)
			{
				//auto dg = (Widget tw) { return tw.id != this.id; };  // TODO: doing this and providing as compare func creates a compiler error
				window._widgetChildren[_parent.id] = std.array.array(std.algorithm.filter!((Widget tw) { return tw.id != this.id; })(*w));
			}
		}
		
		_parent = newParent;

		if (newParent is null)
			return;

		Widgets* w = _parent.id in window._widgetChildren;
		if (w is null)
		{
			window._widgetChildren[parent.id] = [this];
		}
		else
		{
			*w ~= this;
		}
	}
	
	@property Widgets children()
	{
		Widgets * w = id in window._widgetChildren;
		return w is null ? null : *w;
	}
	
	void setKeyboardFocusWidget()
	{
		window.setKeyboardFocusWidget(this);
	}

	bool isKeyboardFocusWidget()
	{
		return window.isKeyboardFocusWidget(this);
	}

	void grabMouse()
	{
		window.grabMouse(this);
	}

	bool isGrabbingMouse()
	{
		return window.isGrabbingMouse(this);
	}

	void releaseMouse()
	{
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
			Widgets * w = _parentId in window._widgetChildren;
			if (w is null)
			{
				window._widgetChildren[_parentId] = [this];
			}
			else
			{
				*w ~= this;
			}
		}
	}
*/
	package this()
	{
		this(0, 0, 100, 100);
	}

	package this(float x, float y, float width, float height, Widget _parent = null)
	{
		//this(Rectf(x, y, x+w, y+h), _parentId);
		visible = true;
		zOrder = 0f;
		rect = Rectf(x, y, width, height);
		id = nextId++;
		this._parent = _parent;
		if (_parent !is null)
			window = _parent.window;
		this.acceptsKeyboardFocus = false;
	}

	bool send(Event event)
	{
		//if (event.type != EventType.MouseMove)
		//	std.stdio.writeln("event ", event);		
		OnEvent * handler = event.type in events;

		bool used = false;
		
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
			// TODO: fix multiple usages
			used = used || f.send(event, this);
		}
		
		// Bubble up through parents
		if (!used && _parent !is null)
		{
			std.stdio.writeln("parent ev");
			used = parent.send(event);
		}
		return used;
	}
	
	void draw(StyleSet styleSet)
	{
		if (!visible)
			return;

		// Draw features
		foreach (f; features)
		{
			f.draw(this, styleSet);
		}
		
		// Draw children
		foreach (w; children)
		{
			w.draw(styleSet);
		}
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
				foreach (f; features)
				{
					f.update(this);
				}			
		}

//		OnEvent * handler = EventType.Update in events;
		
//		if (handler)
//			(*handler)(Event(EventType.Update), this);

		/*
		Rectf wrect = Window.active.windowToWorld(rect);
		float[] vert = quadVertices(wrect);
		float[] uv = quadUVs(wrect, activeStyle.model.material, Window.active);
		activeStyle.model.mesh.buffers[0].setData(vert);
		activeStyle.model.mesh.buffers[1].setData(uv);
		activeStyle.model.draw();
  */
	}
}
