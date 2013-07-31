module gui.widgetfeature;


import behavior.behavior;
import graphics._; 
import gui._;
import math._;
import std.c.windows.windows;
import std.range;
import std.variant;
import std.conv;

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

class WidgetFeature
{
	bool send(Event event, Widget widget) { return false; }
	void update(Widget widget) {}
	void draw(Widget widget, StyleSet styleSet) {}
}

/** Layouting of child widgets
 * 
 * When this feature is set on a widget all child widgets will
 * be layed by this class.
 */
class DirectionalLayout(bool isHorz) : WidgetFeature
{
	override bool send(Event event, Widget widget)
	{
 		if (event.type != EventType.Resize)
			return false;
		
		auto c = widget.children;
		if (c is null || c.length == 0) return false; // nothing to layout
		
		const rect = widget.rect;
		
		static if (isHorz)
		{
			// Divide the current width into even horizontal pieces
			float d = rect.w / c.length;
			auto r = Rectf(rect.x, rect.y, d, rect.w);
			foreach (ref w; c)
			{
				w.rect = r;
				r.pos.x += d;
			}
		}
		else
		{
			// Divide the current width into even horizontal pieces
			float d = rect.h / c.length;
			auto r = Rectf(rect.x, rect.y, rect.w, d);
			foreach (ref w; c)
			{
				w.rect = r;
				r.pos.y += d;
			}
		}
		return false;
	}

	override void update(Widget widget) 
	{
		
	}
}

alias DirectionalLayout!true HorizontalLayout;
alias DirectionalLayout!false VerticalLayout;

/*
class GridLayout : WidgetFeature
{

}
*/

class Dragger : WidgetFeature
{
	Rectf handleRect;
	Vec2f startDragPos;
	enum dragTriggerDistance = 30f; // pixels to drag before drag is started
		
	this(Rectf handleRect)
	{
		this.handleRect = handleRect;
		this.startDragPos = Vec2f(-1000000, -1000000);
	}
	
	override bool send(Event event, Widget widget)
	{
		// Dragging support
		Rectf handleRectAbs = handleRect;
		handleRectAbs.pos.x += widget.rect.pos.x;
		handleRectAbs.pos.y += widget.rect.pos.y;
		
		if (event.type == EventType.MouseDown && handleRectAbs.contains(event.mousePos))
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
		
		if (widget.isGrabbingMouse() &&
			event.type == EventType.MouseMove && 
		    event.mouseButtonsActive == Event.MouseButton.Left)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.parent = null;
			widget.rect.x = widget.rect.x + event.mousePosRel.x;
			widget.rect.y = widget.rect.y + event.mousePosRel.y;
			return true;
		} 
		
		if (event.type == EventType.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			return true;
		}
		return false;
	}

	override void update(Widget widget) 
	{
	}
}

/** Makes a widget able to drag the containing window
 */
class WindowDragger : WidgetFeature
{
	Vec2f startDragPos;
		
	this()
	{
		this.startDragPos = Vec2f(-1000000, -1000000);
	}
	
	override bool send(Event event, Widget widget)
	{
		// Dragging support
		if (event.type == EventType.MouseDown && widget.rect.contains(event.mousePos))
		{
			widget.grabMouse();
			startDragPos = event.mousePos;
			Window.active.waitForEvents = false;
			return true;
		} 
		if (event.type == EventType.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			Window.active.waitForEvents = true;			
			return true;
		}
		return false;
	}

	override void update(Widget widget) 
	{
		if (widget.isGrabbingMouse())
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
class WindowResizer : WidgetFeature
{
	Vec2f startDragPos;
	Vec2f startSize;
	enum dragTriggerDistance = 10f; // pixels to drag before drag is started
		
	this()
	{

		this.startDragPos = Vec2f(-1000000, -1000000);
	}
	
	override bool send(Event event, Widget widget)
	{
		// Dragging support
		if (event.type == EventType.MouseDown && widget.rect.contains(event.mousePos))
		{
			startSize = Window.active.size;
			widget.grabMouse();
			startDragPos = getCursorScreenPos();
			Window.active.waitForEvents = false;
			return true;
		} 
		if (event.type == EventType.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			Window.active.waitForEvents = true;			
			return true;
		}
		return false;
	}

	override void update(Widget widget) 
	{
		if (widget.isGrabbingMouse() && startDragPos.x > -1000)
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

// TODO: Think this is too complex. Maybe do several simpler ones that can be combined
//       Maybe build constraints from a string...?
class Constraint : WidgetFeature
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
	
	override void update(Widget widget) 
	{
	}
			
	override bool send(Event event, Widget widget)
	{
 		if (event.type != EventType.Resize)
			return false;
		
		float k = 0.999f;
		
		Rectf startRect = widget.rect;

		Vec2i winSize = Window.active.size;
		Rectf windowRect = Rectf(0,0,winSize.x,winSize.y);

		Rectf relRect = relation == NullWidgetID ? windowRect : gui.window.Window.active.getWidget(relation).rect;
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

class BoxRenderer : WidgetFeature 
{
	Style _style;
	Model model;

	@property {
		Style style() 
		{ 
			return _style; 
		}
		void style(Style s)
		{
			_style = s;
			if (model !is null)
				model.material = style.background;
		}
	}
	
	this(Style style = null)
	{
		if (style is null)
			style = StyleSet.base[0];
		this._style = style;
		assert(_style.background !is null);
		model = createWindowQuad(Rectf(0,0,1,1), _style.background);
	}
	
	override void draw(Widget widget, StyleSet styleSet)
	{
		Rectf rect = widget.rect;
		Rectf wrect = Window.active.windowToWorld(rect);
		auto transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, widget.zOrder));

		if (model is null)
		{
			model = createWindowQuad(rect, _style.background);
		}
		else
		{
			wrect.x = 0;
			wrect.y = 0;
			float[] uv = quadUVs(wrect, model.material, Window.active);
			float[] vert = quadVertices(wrect);
			model.mesh.buffers[0].data = vert;
			model.mesh.buffers[1].data = uv;
		}
		model.draw(Window.active.MVP * transform);
	}
}

import bufferview;

/*
class Text : WidgetFeature
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
	
	bool send(Event event, ref Widget widget)
	{
		return false;
	}

	void update(ref Widget widget) 
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
 */


/** The Text feature of a widget can be used to displays the contents of a TextView
 *  on the widget
 */
class TextRenderer : WidgetFeature
{
	//import render;
	import buffer;
	import gui.command;
	
	private
	{
		TextModel _model;
		StyledText!BufferView _styledText;
		Model _cursorModel = null;
		TextBoxLayout _layout;
	}

	this(BufferView _bufferView)
	{
		auto rs = new RegionSet();
		rs.add(0, uint.max);
		this._styledText = new StyledText!BufferView(new DSourceStyler!BufferView(), _bufferView, rs);
		this._model = new TextModel(); // TODO: maybe model should be owner of styledText_
		//assert(StyleSet.builtin.length != 0);
		//assert(StyleSet.builtin[0].font !is null);
		//Font f = StyleSet.builtin[0].font;
		import system;
		this._cursorModel = createQuad(Rectf(0, 0, 1, 1), Material.create(getRunningExecutablePath() ~ "white.png"));
		//this._cursorModel.material.texture = font.fontMap;
	}

	/*
	this(TextGapBuffer buf = null, string name = null)
	{
		if (buf is null)
			buf = new TextGapBuffer("", 10);
		import application;
		auto view = Application.bufferViewManager.create(buf, name);
		this(view);
	}

	this(string text, string name = null)
	{
		dstring dl = to!dstring(text);
		this(new TextGapBuffer(dl, 20), name);
	}
*/
	@property 
	{
		//void bufferView(BufferView v)
		//{
		//	_view = v;
	//	}
	
		BufferView bufferView()
		{
			return _styledText.text;
		}
	}
	
	void runCommand(string commandName, Variant data)
	{
		auto c = CommandManager.singleton.lookup(commandName);
		if (c is null) return; // no such command
		runCommand(c.name, data); // todo: just use command as param
	}

	void runCommand(EditorCommand c, Variant data)
	{
		if (c.canExecute(data))
			c.execute(data);
	}
	
	override bool send(Event event, Widget widget)
	{
		if (widget.isKeyboardFocusWidget())
			return false;

		// TODO: isn't behavior just a event -> edit mapping e.g. command
		// TODO: have several kinds of behaviours for app, window, textview. 
		//       App and window should have the chance to grab events before textview
		//EditorBehavior.current.onEvent(event, bufferView);
		return false;
	}
	
	override void update(Widget widget)
	{
		widget.acceptsKeyboardFocus = true;		
	}
	
	override void draw(Widget widget, StyleSet styleSet)
	{
		// Issues: 
		//   1, Cannot calc x offset correct when not using monotype because of the simple rendering we are doing.
		//      This can be fixed by rendering the line of interest only and getting the x coord - but this 
		//      enforces using the same font for all markups on the line since spacing etc. is not the same
		//      for different fonts. This could be solved by altering the layout of the regions so that it
		//      is easy to iterate text with mixed styled regions.
		//   2, Cannot calc y offset correct when not using fonts of same height because of simple layouting we
		//      are doing. In order to get correct y offset you will have to layout all lines before the point
		//      of interest. This can be expensive to do - it is doable and is probably using some cacheing of results
		//      etc.
		//
		//  Because of this only monofonts are currently supported since they lent themselves to easy x,y coord
		//  calculations. The next step should be non-monospace font support but only one type of font for a view.
		//  Next step multiple font types with same height. Next step multiple font types with arbitraty heights.
	
		// Now calc the column and row of the cursor in order to find out the x and y coord:
		// TODO: do

		Font font = styleSet[0].font;
		if (widget.rect.h == 0f)
			return;
		Rectf wrect = Window.active.windowToWorld(widget.rect);
		auto transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, widget.zOrder));
		//auto transform = Mat4f.makeTranslate(Vec3f(-1,1,0));

		BufferView view = bufferView;

		if (true || view.dirty)
		{
			// Update style region set.
			// TODO: only on changes
			_styledText.update(styleSet);

			view.visibleLineCount = cast(uint) (widget.rect.size.y / font.fontLineSkip);
			
			// TODO: get transform
			Vec2f worldSize = Window.active.pixelSizeToWorld(widget.rect.size);
			//_model.renderArea = Rectf(0, 0, worldSize.x, worldSize.y); // Only update on resize

			//auto rset = new RegionSet();
			//rset.add(view.bufferOffset,_view.length);
			//_model.add(view.buffer[rset.a .. rset.b], styleSet[0]);

			_model.resetGlyphPositions();

			//auto offset = view.buffer.startOfLine(view.bufferOffset);

//			_layout = TextBoxLayout(_model, Rectf(0.0f * worldSize.x, -0.0f * worldSize.y, worldSize.x, worldSize.y));
//			std.stdio.writeln(wrect.h, " ", view.visibleLineCount, " ", worldSize.v);

			_layout = TextBoxLayout(_model, Rectf(0, 0, worldSize.x, worldSize.y));
			foreach (r; _styledText.regionSet)
			{
				if (r.b <= view.bufferOffset) continue;
				if (r.contains(view.bufferOffset))
				{
					r.a = view.bufferOffset;
				}

				//				_layout.add(view.buffer[0.. 3000], styleSet[r.id]);
				_layout.add(view.buffer[r.a .. r.b], styleSet[r.id]);
				if (_layout.done)
					break;
			}

			if (_layout.lines.empty)
			{
				// Clear model buffers
				_model.clear();
			}

			//_model.add(worldSize.x, view.buffer[0 .. 3], styleSet[0]);
			//_model.add(worldSize.x, view.buffer[3 .. 8], styleSet[1]);
			//_model.add(worldSize.x, view.buffer[8 .. 200], styleSet[2]);

			//_model.add(worldSize.x, view.buffer[0 .. 51], styleSet[0]);
			//_model.add(worldSize.x, view.buffer[51 .. 54], styleSet[1]);
			//_model.add(worldSize.x, view.buffer[54 .. 200], styleSet[2]);


			view.dirty = false;
				
			//_rectLines = cast(uint)(widget.rect.h / styleSet[""].font.fontLineSkip);
		}

		_model.draw(Window.active.MVP * transform);

		//uint glyphLineIndex = view.cursorPoint - view.buffer.startOfLine(view.cursorPoint);
		// float cursorLineOffset = _layout.lines[row].glyphWorldPos(glyphLineIndex).x;
		//float cursorLineOffset = _model.getGlyphWorldPos(view.cursorPoint - view.bufferOffset).x;
		
		Rectf rect = void;
		//std.stdio.writeln("of ", view.cursorPoint, " ", view.buffer.length, " ", view.bufferOffset);

		// Cull cursor
		auto cursorLine = view.buffer.lineNumber(view.cursorPoint);
		//7std.stdio.writeln("FOOOO ", cursorLine, " ", view.cursorPoint, " ", view.bufferOffset, " ", view.lineOffset, " ", _layout.lines.length, " ", view.buffer.length);
		if (cursorLine < view.lineOffset || cursorLine > (view.lineOffset + _layout.lines.length) || _layout.lines.empty)
			return;

		if (view.cursorPoint == view.buffer.length)
		{
			// Special handling for end of doc because no glyph info is present for that index obviously
			auto idx = cast(int)view.cursorPoint - cast(int)view.bufferOffset;
			if (idx < 1)
				return; // no text for cursor
			rect = _model.getGlyphWorldPos(idx-1);
			rect.x = rect.x + rect.w;
		}
		else
		{
			rect = _model.getGlyphWorldPos(view.cursorPoint - view.bufferOffset);
			if (rect.h == 0)
				return;
		}

		//uint column = view.cursorPoint - view.buffer.startOfLine(view.cursorPoint);
//		Vec2f cursorOffset = Window.active.pixelSizeToWorld(Vec2f(0, -cast(float)(row * font.fontLineSkip)));
//		cursorOffset.x = cursorLineOffset;
		//std.stdio.writeln(row);
		uint row = cursorLine - view.lineOffset;
		//std.stdio.writeln("row ", row, " ", view.buffer.lineNumber(view.cursorPoint), " " , view.lineOffset);
		auto lineRect = _layout.lines[row].rect;
		transform = transform * Mat4f.makeTranslate(Vec3f(rect.x, lineRect.y - (lineRect.h ), 0f)) * Mat4f.makeScale(Vec3f(Window.active.pixelWidthToWorld(1), lineRect.h, 0));
//		transform = transform * Mat4f.makeTranslate(Vec3f(rect.x, lineRect.y - (lineRect.h - _layout.lines[row].textBaseLine), 0f)) * Mat4f.makeScale(Vec3f(rect.w, lineRect.h, 0));
		_cursorModel.draw(Window.active.MVP * transform);
	}
}

//import application;
/*
@property BufferView content(Widget widget, string text)
{
	auto bv = Application.bufferViewManager.create(text);
	return content(widget, bv);
}
*/

@property BufferView content(Widget widget, BufferView view)
{
	auto tr = new TextRenderer(view);
	//foreach (ref 
	widget.features ~= tr;
	return tr.bufferView;
}

BufferView bufferView(Widget widget)
{
	foreach (f; widget.features)
	{
		auto tr = cast(TextRenderer) f;
		if (tr !is null)
			return tr.bufferView;
	}
	return null;
}

Widget bufferWidget(BufferView view)
{
	// TODO: fix
	return null;
	/*
	foreach (k, v; Widget.widgets)
	{
		if (v.bufferView() is view)
			return v;
	}
	return null;
*/
}
