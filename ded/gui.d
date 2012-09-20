module gui;

import std.range;

import graphics;
import math;
import core.time;
import text;

import std.c.windows.windows;

struct CURSORINFO {
  DWORD   cbSize;
  DWORD   flags;
  HCURSOR hCursor;
  POINT   ptScreenPos;
};
alias CURSORINFO* PCURSORINFO, NPCURSORINFO, LPCURSORINFO;

extern (Windows) nothrow
{
		export BOOL GetCursorInfo(LPCURSORINFO lpPoint);
}

struct Color
{
	alias Vec3!float Color;
	
	//static Color black = Color(0.0, 0.0, 0.0);
	//static Color white = Color(1.0, 1.0, 1.0);
}

struct Style 
{
	Model model; // model rendered for visuals
}

class IWidgetFeature
{
	abstract bool onEvent(Event event, ref Widget widget);
	abstract void onUpdate(ref Widget widget);
	void onDraw(ref Widget widget) {}
}

/*
class Layout : IWidgetFeature
{
	
	this(Layout layout)
	{
		this.layout = layout;
	}
	
	void onEvent(Event ev, ref Widget widget)
	{
	
	}

	void onUpdate(ref Widget widget) 
	{
		
	}
}
*/

class Text : IWidgetFeature
{
	enum Overflow
	{
		Clip,
		Wrap
	}
	
	Overflow overflowX;
	Overflow overflowY;
	
	private text.GapBuffer!dchar buffer;
	private graphics.Material material;
	
	this(dstring txt)
	{
		buffer = new text.GapBuffer!dchar(txt, 40);
		material = Material.builtIn;
	}
	
	bool onEvent(Event event, ref Widget widget)
	{
		return false;
	}

	void onUpdate(ref Widget widget) 
	{
		// Create a bitmap that will span the widget and 
		if (!material.texture.valid)
			material.texture = Texture.create(cast(int)widget.rect.w, cast(int)widget.rect.h);

		Rectf wrect = Window.active.windowToWorld(widget.rect);
		float[] uv = quadUVs(wrect, material, Window.active);
		widget.activeStyle.model.material = material;
		widget.activeStyle.model.mesh.buffers[1].setData(uv);
		widget.activeStyle.model.draw();
	}
}
 
class Dragger : IWidgetFeature
{
	Rectf handleRect;
	Vec2f startDragPos;
	enum dragTriggerDistance = 30f; // pixels to drag before drag is started
		
	this(Rectf handleRect)
	{
		this.handleRect = handleRect;
		this.startDragPos = Vec2f(-1000000, -1000000);
	}
	
	bool onEvent(Event event, ref Widget widget)
	{
		// Dragging support
		Rectf handleRectAbs = handleRect;
		handleRectAbs.pos.x += widget.rect.pos.x;
		handleRectAbs.pos.y += widget.rect.pos.y;
		
		if (event.type == Event.Type.MouseDown && handleRectAbs.contains(event.mousePos))
		{
			widget.grabMouse();
			startDragPos = event.mousePos;
			return true;
		} 
		
		if ( (startDragPos - event.mousePos).squaredLength() < (dragTriggerDistance*dragTriggerDistance) )
		{
			// Wait for drag trigger distance
			return false;
		}
		
		if (widget.mouseGrabbedBy == widget.id &&
			event.type == Event.Type.MouseMove && 
		    event.mouseButtonsActive == Event.MouseButton.Left)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.parent = null;
			widget.rect.x = widget.rect.x + event.mousePosRel.x;
			widget.rect.y = widget.rect.y + event.mousePosRel.y;
			return true;
		} 
		
		if (event.type == Event.Type.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			return true;
		}
		return false;
	}

	void onUpdate(ref Widget widget) 
	{
	}
}

/** Makes a widget able to drag the containing window
 */
class WindowDragger : IWidgetFeature
{
	Vec2f startDragPos;
		
	this()
	{
		this.startDragPos = Vec2f(-1000000, -1000000);
	}
	
	bool onEvent(Event event, ref Widget widget)
	{
		// Dragging support
		if (event.type == Event.Type.MouseDown && widget.rect.contains(event.mousePos))
		{
			widget.grabMouse();
			startDragPos = event.mousePos;
			Window.active.waitForEvents = false;
			return true;
		} 
		if (event.type == Event.Type.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			Window.active.waitForEvents = true;			
			return true;
		}
		return false;
	}

	void onUpdate(ref Widget widget) 
	{
		if (widget.mouseGrabbedBy == widget.id)
		{
			CURSORINFO desktopPos;
			desktopPos.cbSize = CURSORINFO.sizeof;
			if (! GetCursorInfo(&desktopPos))
			{
				std.stdio.writeln("errocode ", GetLastError());	
			}
			
			Vec2f winPos = Vec2f(desktopPos.ptScreenPos.x, desktopPos.ptScreenPos.y);
			Window.active.position = winPos - startDragPos;
		}
	}
}

/** Makes a widget able to drag the containing window
 */
class WindowResizer : IWidgetFeature
{
	Vec2f startDragPos;
	Vec2f startSize;
	enum dragTriggerDistance = 10f; // pixels to drag before drag is started
		
	this()
	{

		this.startDragPos = Vec2f(-1000000, -1000000);
	}
	
	bool onEvent(Event event, ref Widget widget)
	{
		// Dragging support
		if (event.type == Event.Type.MouseDown && widget.rect.contains(event.mousePos))
		{
			startSize = Window.active.size;
			widget.grabMouse();
			startDragPos = getCursorScreenPos();
			Window.active.waitForEvents = false;
			return true;
		} 
		if (event.type == Event.Type.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			Window.active.waitForEvents = true;			
			return true;
		}
		return false;
	}

	void onUpdate(ref Widget widget) 
	{
		if (widget.mouseGrabbedBy == widget.id && startDragPos.x > -1000)
		{
			Vec2f screenPos = getCursorScreenPos();
			Window.active.size = startSize + (screenPos - startDragPos);
		}
	}
	
	static Vec2f getCursorScreenPos()
	{
		CURSORINFO desktopPos;
		desktopPos.cbSize = CURSORINFO.sizeof;
		if (! GetCursorInfo(&desktopPos))
		{
			std.stdio.writeln("errocode ", GetLastError());	
		}
		Vec2f pos = Vec2f(desktopPos.ptScreenPos.x, desktopPos.ptScreenPos.y);
		return pos;
	}
}

class Constraint : IWidgetFeature
{
	enum VerticalAnchor
	{
		Top,
		Middle,
		Bottom
	}
	
	enum HorizontalAnchor
	{
		Left,
		Middle,
		Right
	}

	// Widget that this constraint relates to. If it is the window
	// the relation is NullWidgetID
	WidgetID relation;

	HorizontalAnchor hRelAnchor;
	VerticalAnchor vRelAnchor;

	HorizontalAnchor hWidgetAnchor;
	VerticalAnchor vWidgetAnchor;

	Vec2f lockedSize;
	Vec2f offset;
	
	this(WidgetID relation, 
		 HorizontalAnchor hRelAnchor, VerticalAnchor vRelAnchor,
		 HorizontalAnchor hWidgetAnchor, VerticalAnchor vWidgetAnchor,
		 Vec2f lockedSize = Vec2f(-1, -1),
		 Vec2f offset = Vec2f(0,0))
	{
		this.relation = relation;
		this.hRelAnchor = hRelAnchor;
		this.vRelAnchor = vRelAnchor;
		this.hWidgetAnchor = hWidgetAnchor;
		this.vWidgetAnchor = vWidgetAnchor;
		this.lockedSize = lockedSize;
		this.offset = offset;
	}
	
	void onUpdate(ref Widget widget) 
	{
	}
			
	bool onEvent(Event event, ref Widget widget)
	{
 		if (event.type != Event.Type.Resize)
			return false;
		
		float k = 0.999f;
		
		Rectf startRect = widget.rect;
		
		Rectf windowRect = Rectf(0,0,Window.active.width,Window.active.height);

		Rectf relRect = relation == NullWidgetID ? windowRect : Widget.widgets[relation].rect;
		Vec2f relAnchor;
		
		// The vertical axis
		final switch (vRelAnchor)
		{
		case VerticalAnchor.Top:
			relAnchor.y = relRect.y;
			break;
		case VerticalAnchor.Middle:
			relAnchor.y = (relRect.y + relRect.y2) * 0.5f;
			break;
		case VerticalAnchor.Bottom:
			relAnchor.y = relRect.y2;
			break;
		}

		relAnchor.y += offset.y;
		
		// No matter the event we try to satisfy the constraint
		Rectf wrect = widget.rect;
		float dy;
		final switch (vWidgetAnchor)
		{
		case VerticalAnchor.Top:
			dy = (relAnchor.y - widget.rect.y) * k;
			widget.rect.y = wrect.y + dy;
			// If needed try to satify a vertical size constraint
			if (lockedSize.y > 0)
				widget.rect.size.y = widget.rect.h + (lockedSize.y - widget.rect.h) * k;
			break;
		case VerticalAnchor.Middle:
			float wy = (wrect.y + wrect.y2) * 0.5f;
			dy = (relAnchor.y - wy) * k;
			widget.rect.y = wrect.y + dy;
			break;
		case VerticalAnchor.Bottom:
			dy = (relAnchor.y - widget.rect.y2) * k;
			widget.rect.size.y = wrect.h + dy;
			// If needed try to satify a vertical size constraint
			if (lockedSize.y > 0)
				widget.rect.pos.y = widget.rect.pos.y - (lockedSize.y - widget.rect.h) * k;
			break;
		}

		
		// The horizontal axis
		final switch (hRelAnchor)
		{
		case HorizontalAnchor.Left:
			relAnchor.x = relRect.x;
			break;
		case HorizontalAnchor.Middle:
			relAnchor.x = (relRect.x + relRect.x2) * 0.5f;
			break;
		case HorizontalAnchor.Right:
			relAnchor.x = relRect.x2;
			break;
		}

		relAnchor.x += offset.x;

		// No matter the event we try to satisfy the constraint
		float dx;
		final switch (hWidgetAnchor)
		{
		case HorizontalAnchor.Left:
			dx = (relAnchor.x - widget.rect.x) * k;
			widget.rect.x = wrect.x + dx;
			// If needed try to satify a horizontal size constraint
			if (lockedSize.x > 0)
				widget.rect.size.x = widget.rect.w + (lockedSize.x - widget.rect.w) * k;
			break;
		case HorizontalAnchor.Middle:
			float wx = (wrect.x + wrect.x2) * 0.5f;
			dx = (relAnchor.x - wx) * k;
			widget.rect.x = wrect.x + dx;
			break;
		case HorizontalAnchor.Right:
			dx = (relAnchor.x - widget.rect.x2) * k;
			widget.rect.size.x = wrect.w + dx;
			// If needed try to satify a horizontal size constraint
			if (lockedSize.x > 0)
				widget.rect.pos.x = widget.rect.pos.x - (lockedSize.x - widget.rect.w) * k;
			break;
		}		
		
		float limit = 0.20;
		bool done = startRect.pos.squaredDistanceTo(widget.rect.pos) > limit || startRect.size.squaredDistanceTo(widget.rect.size) > limit;
		
		// TODO: Make sure that widget.rect is integer size when done is true.
		return done;
	}
	
}

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
		
	// Styling
	Style[Event.Type] styles;
	Style activeStyle;

	enum Layout
	{
		None,
		Horizontal,
		Vertical
	}
	Layout layout;
	
	// Events
	alias bool delegate(Event event, ref Widget widget) OnEvent;
	OnEvent[Event.Type] events;

	// Behavior
	IWidgetFeature[] features; 
	
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
				auto dg = (Widget tw) { return tw.id != this.id; };
				_children[_parentId] = std.array.array(std.algorithm.filter!dg(*w));
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
		Widget * w = keyboardFocusWidget in Widget.widgets;
		if (w !is null)
			w.onEvent(Event(Event.Type.KeyboardUnfocus));

		w = wid in Widget.widgets;
		if (w !is null)
		{
			w.onEvent(Event(Event.Type.KeyboardFocus));
		}
		Widget.keyboardFocusWidget = wid;
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
		
	this(float x, float y, float w, float h, WidgetID _parentId = NullWidgetID)
	{
		this(Rectf(x, y, x+w, y+h), _parentId);
	}
	
	this(Rectf windowRect = Rectf.zero, WidgetID _parentId = NullWidgetID)
	{
		rect = windowRect;
		//auto m = Material.builtIn;
		// m.texture = createTextTexture("arial.ttf", 24);
		auto m = new Material();
		m.texture = Texture.builtIn; //Texture.create(windowRect.w, windowRect.h);
		m.shader = ShaderProgram.builtIn;
		
		Style st = { model : createWindowQuad(windowRect, m) };
		styles[Event.Type.Default] = st;
		activeStyle = st; 
		//auto font = new Font("arial.ttf", 40);
		//activeStyle.model.material.texture.renderText(Vec2f(1,1), font, "Hello ");
		//activeStyle.model.material.texture = createTextTexture("arial.ttf", 40);
		id = nextId++;
		layout = Layout.Horizontal;  
		this._parentId = _parentId;
		
		//features ~= new Docker();
		//WindowManager.the.widgets[id] = this;
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

	bool onEvent(Event event)
	{
		//if (event.type != Event.Type.MouseMove)
		//	std.stdio.writeln("event ", event);		
		OnEvent * handler = event.type in events;
		
		bool used = false;
		
		if (handler)
		{
			used |= (*handler)(event, this);
		}
		else
		{ 
			handler = Event.Type.Default in events;
			if (handler)
				used |= (*handler)(event, this);
		}
		Style * style = event.type in styles;

		if (style)
			activeStyle = *style;

		foreach (f; features)
		{
			used |= f.onEvent(event, this);
		}
		return used;
	}
	
	void onDraw()
	{
		/*
		foreach (f; features)
		{
			f.onUpdate(this);
		}
		*/
		Rectf wrect = Window.active.windowToWorld(rect);
		activeStyle.model.transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0f));
		float[] uv = quadUVs(wrect, activeStyle.model.material, Window.active);
		wrect.x = 0;
		wrect.y = 0;
		float[] vert = quadVertices(wrect);
		activeStyle.model.mesh.buffers[0].setData(vert);
		activeStyle.model.mesh.buffers[1].setData(uv);
		activeStyle.model.draw();

		// Draw features
		foreach (f; features)
		{
			f.onDraw(this);
		}
		
		// Draw children
		foreach (ref w; children)
		{
			w.onDraw();
		}
	}

	void onLayout()
	{
		auto c = children;
		if (c is null || c.length == 0) return; // nothing to layout
		
		final switch (layout)
		{
		case Layout.None:
			break;
		case Layout.Horizontal:
			// Divide the current width into even horizontal pieces
			float d = rect.w / c.length;
			auto r = Rectf(rect.x, rect.y - 100, rect.x + d, rect.y2);
			foreach (ref w; c)
			{
				w.rect = r;
				r.pos.x += d;
			}
			break;
		case Layout.Vertical:
			// Divide the current width into even horizontal pieces
			float d = rect.h / c.length;
			auto r = Rectf(rect.x, rect.y, rect.x2, rect.y + d);
			foreach (ref w; c)
			{
				w.rect = r;
				r.pos.y += d;
			}
			break;
		}
	}
	
	void onUpdate()
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
					f.onUpdate(this);
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

void draw()
{
	foreach (ref w; Widget.widgets)
	{
		if (w._parentId == NullWidgetID)
			w.onDraw();
	}
}

void update()
{
	foreach (ref w; Widget.widgets)
	{
		w.onUpdate();
	}
}
	
private static uint downButtonWidget = NullWidgetID;
private static uint clickWidget = NullWidgetID;
private static TickDuration clickWidgetTime;

void update(Event event)
{
	WidgetID lastMouseWidget = Widget.mouseWidget;
	Widget.mouseWidget = NullWidgetID;
	
	// Find widget that mouse is over
	foreach (ref w; Widget.widgets)
	{
		if (w.rect.contains(event.mousePos))
		{
			Widget.mouseWidget = w.id;
		}
	}
	if (Widget.mouseGrabbedBy)
		Widget.mouseWidget = Widget.mouseGrabbedBy;
	
	Widget * overWidget = null; 
	if (Widget.mouseWidget)
		overWidget = Widget.mouseWidget in Widget.widgets;
	
	// Send events to the found widget
	switch (event.type)
	{
	case Event.Type.MouseMove:
		if (lastMouseWidget != Widget.mouseWidget)
		{
			// If a click has been initiated by a mouse down and the mouse 
			// goes away from the widget the click is aborted.
			downButtonWidget = NullWidgetID;
			clickWidget = NullWidgetID;

			// Handle mouse out events
			if (lastMouseWidget != NullWidgetID)
			{
				Widget * outWidget = lastMouseWidget in Widget.widgets;
				if (outWidget)
				{
					event.type = Event.Type.MouseOut;
					outWidget.onEvent(event);
				}
			}
			 
			// Handle mouse over event and mouse move event
			if (overWidget)
			{
				event.type = Event.Type.MouseOver;
				overWidget.onEvent(event);
				event.type = Event.Type.MouseMove;
				overWidget.onEvent(event);
			}
		} 
		else if (overWidget)
		{
			// Handle mouse move event
			event.type = Event.Type.MouseMove;
			overWidget.onEvent(event);
		}
		else
		{
			// If a click has been initiated by a mouse down and the mouse 
			// goes away from the widget the click is aborted.
			downButtonWidget = NullWidgetID;
			clickWidget = NullWidgetID;				
		}
		break;
	case Event.Type.MouseDown:
		if (overWidget)
		{
			downButtonWidget = Widget.mouseWidget;
			overWidget.onEvent(event);
		}
		else
		{
			downButtonWidget = NullWidgetID;
			clickWidget = NullWidgetID;
		}
		break;
	case Event.Type.MouseUp:
		if (overWidget)
		{
			overWidget.onEvent(event);
			if (downButtonWidget == Widget.mouseWidget)
			{
				TickDuration tdur = TickDuration.currSystemTick;
				float doubleClickTime = tdur.to!("seconds",float)() - clickWidgetTime.to!("seconds",float)();
				const float maxDoubleClickTime = 0.3;
				if (downButtonWidget == clickWidget && doubleClickTime < maxDoubleClickTime)
				{
					event.type = Event.Type.MouseDoubleClick;
					overWidget.onEvent(event);
					clickWidget = 0;
				}
				else
				{
					event.type = Event.Type.MouseClick;
					overWidget.onEvent(event);
					clickWidget = downButtonWidget;
					clickWidgetTime = TickDuration.currSystemTick;
					Widget.setKeyboardFocusWidget(clickWidget);
				}
			}
		}
		downButtonWidget = NullWidgetID;
		break;
	case Event.Type.MouseScroll:
	case Event.Type.KeyDown:
	case Event.Type.KeyUp:
	case Event.Type.Text:
		if (Widget.keyboardFocusWidget != NullWidgetID)
		{
			Widget * w = Widget.keyboardFocusWidget in Widget.widgets;
			if (w is null)
				Widget.setKeyboardFocusWidget(NullWidgetID);
			else
				w.onEvent(event);
		}
		break;
	case Event.Type.Resize:
		bool cont = false;
		int maxIter = 5;
		do
		{
			cont = false;
			foreach (w; Widget.widgets)
			{
				cont |= w.onEvent(event);
			}
		} while (cont && maxIter--);
	default:
		break;
	}
	
	if (Widget.keyboardFocusWidget == NullWidgetID && Widget.widgets.length != 0 )
		Widget.setKeyboardFocusWidget(Widget.widgets[Widget.widgets.keys[0]].id);
}

/*
class WidgetManager
{
	WindowManager singleton;
	static @property WindowManager the()
	{
		if (singleton is null)
			singleton = new WidgetManager();
		return singleton;
	}
	
	Widget[uint] widgets;

	uint mouseFocusWidget = 0;
	
	void update()
	{
		
	}
		
}
*/