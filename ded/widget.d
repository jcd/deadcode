module widget;

import graphics;
import widgetfeature;
import math; // Rectf;
import style;

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
	static Widget[WidgetID] widgets;
	static Widgets[WidgetID] _children;
	
	static WidgetID nextId = 1;
	static WidgetID mouseWidget = NullWidgetID;
	static WidgetID mouseGrabbedBy = NullWidgetID;
	static WidgetID keyboardFocusWidget = NullWidgetID;

	WidgetID id;
	WidgetID _parentId;
	Rectf rect;  // rect for events like mouse over etc.

	bool acceptsKeyboardFocus;
			
	// Events
	alias bool delegate(Event event, ref Widget widget) OnEvent;
	OnEvent[Event.Type] events;

	// Behavior
	WidgetFeature[] features; 
	
	/*
	@property WindowID parentID() const 
	{
		return _parentId;
	}
	
	@property void parentID(WindowID _parentId)
	{
		if (this._parentID ==_parentId) return;
		(Widget[]) * _children = this._parentId in children;
		string[string] aa;
	
		this._parentID = _parentId;
	}
	*/
	
	@property Widget parent()
	{
		if (_parentId == NullWidgetID) return null;
		return widgets[_parentId];
	}
	
	@property void parent(Widget newParent)
	{
		auto p = parent;
		if (p !is null)
		{
			Widgets * w = _parentId in _children;

			if (w !is null)
			{
				auto dg = (Widget tw) { return tw.id != this.id; };  // TODO: doing this and providing as compare func creates a compiler error
				_children[_parentId] = std.array.array(std.algorithm.filter!((Widget tw) { return tw.id != this.id; })(*w));
			}
		}
		
		if (newParent is null)
		{
			_parentId = NullWidgetID;
			return;
		}

		_parentId = newParent.id;

		auto w = _parentId in _children;
		if (w is null)
		{
			_children[_parentId] = [this];
		}
		else
		{
			*w ~= this;
		}
	}
	
	@property Widgets children()
	{
		Widgets * w = id in _children;
		return w is null ? null : *w;
	}
	
	static void setKeyboardFocusWidget(WidgetID wid)
	{
		// Find widget that accepts keyboard focus from wid
		// and though parents if any. This bubbling is not handled by
		// the normal widget.send(..) mechanism because we need to
		// send unfocus event only if any widget will accept the
		// keyboard focus which is not always the case.
		auto wp = wid in Widget.widgets;
		if (wp is null)
			return; // no widget with that ID
		
		Widget w = *wp;
		
		// TODO: fix w = null does not work!?!?
		while (w !is null && !w.acceptsKeyboardFocus)
		{
			if (w._parentId == NullWidgetID)
			{
				return;
			}
			else
			{
				w = w.parent;
			}
		}
		
		if (w is null)
			return;
		
		auto ow = keyboardFocusWidget in Widget.widgets;
		if (ow !is null)
			ow.send(Event(Event.Type.KeyboardUnfocus));

		w.send(Event(Event.Type.KeyboardFocus));
		Widget.keyboardFocusWidget = w.id;
	}
	
	void grabMouse()
	{
		assert(mouseGrabbedBy == NullWidgetID || mouseGrabbedBy == id);
		mouseGrabbedBy = id;
	}

	void releaseMouse()
	{
		assert(mouseGrabbedBy == id || mouseGrabbedBy == NullWidgetID);
		mouseGrabbedBy = NullWidgetID;
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
			Widgets * w = _parentId in _children;
			if (w is null)
			{
				_children[_parentId] = [this];
			}
			else
			{
				*w ~= this;
			}
		}
	}
*/
	this(float x, float y, float width, float height, WidgetID _parentId = NullWidgetID)
	{
		//this(Rectf(x, y, x+w, y+h), _parentId);

		rect = Rectf(x, y, width, height);
		id = nextId++;
		this._parentId = _parentId;
		this.acceptsKeyboardFocus = false;
		
		widgets[id] = this;
		if (_parentId != NullWidgetID)
		{
			Widgets * w = _parentId in _children;
			if (w is null)
			{
				_children[_parentId] = [this];
			}
			else
			{
				*w ~= this;
			}
		}	
	}

	bool send(Event event)
	{
		//if (event.type != Event.Type.MouseMove)
		//	std.stdio.writeln("event ", event);		
		OnEvent * handler = event.type in events;

		bool used = false;
		
		if (handler)
		{
			used = (*handler)(event, this);
		}
		else
		{ 
			handler = Event.Type.Default in events;
			if (handler)
				used = (*handler)(event, this);
		}

		foreach (f; features)
		{
			// TODO: fix multiple usages
			used = used || f.send(event, this);
		}
		
		// Bubble up through parents
		if (!used && parent !is null)
		{
			std.stdio.writeln("parent ev");
			used = parent.send(event);
		}
		return used;
	}
	
	void draw(StyleSet styleSet)
	{
		// Draw features
		foreach (f; features)
		{
			f.draw(this, styleSet);
		}
		
		// Draw children
		foreach (ref w; children)
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
