module gui.widgetfeature.textrenderer;

import graphics.model; 
import gui.resources.material : Material;
import gui._;
import math._;
import core.time;
import std.range;
import std.variant;
import std.conv;
import std.math;
import std.traits;
import std.typecons;

struct GlyphHit
{
	bool endOfLine; /// The hit was after the last char on the line and index points to the last char
	int index;     /// Index of the char that was hit. In case endOfLine is true, index of the last char on line
	Rectf rect;     /// The rect that the glyph occupies.

	@property isValid() { return index != int.max; }
}

/** The Text feature of a widget can be used to displays the contents of a TextView
 *  on the widget
 */
class TextRenderer(Text) : WidgetFeature, Stylable
{
	import core.buffer;
	import core.command;

	// Stylable interface
	@property 
	{		
		string name() const pure @safe { return "Text"; }
		bool matchStylable(string stylableName) const pure nothrow @safe
		{
			return matchStylableImpl(this, stylableName);
		}
		const(string[]) classes() const pure nothrow @safe { return _curClasses; }
		bool hasKeyboardFocus() const pure nothrow @safe { return false; }
		bool isMouseOver() const pure nothrow @safe { return false; }
		bool isMouseDown() const pure nothrow @safe { return false; }
		Stylable parent() pure nothrow @safe { return null; } // TODO: return widget
	}

	private
	{
		TextModel _model;
		TextSelectionModel _selectionModel;
		//Style _selectionStyle;

		//TextSelectionModel _selectionModel;
		TextStyler!Text _textStyler;
		Model _cursorModel = null;

		TextBoxLayout _layout;
		bool _multiLine = true;
		bool _textDirty = true;
		enum _isBasicText = ! hasMember!(Text, "dirty");
		bool _cursorVisible;

		Rectf[] _glyphWindowRectCache;
		int _bufferOffsetForCurrentCache;
	
		string[] _curClasses;
	
		@property int textBufferStartOffset()
		{
			static if (_isBasicText)
				return 0;
			else
				return text.bufferStartOffset;
		}
	}

	bool cursorSupported = true;

	@property bool cursorVisible() const pure nothrow @safe
	{
		return _cursorVisible;
	}
	@property void cursorVisible(bool v) pure nothrow @safe
	{
		if (_cursorVisible == v)
			return;
		_cursorVisible = v;
		_textDirty = true;
	}

	// Tmp solution until proper stylesset and selectors are supported
	Region selection;

	alias void delegate(TextRenderer!Text) Callback;
	
	Callback onLayoutChanged;
	private void layoutChanged()
	{
		if (onLayoutChanged !is null)
			onLayoutChanged(this);
	}

	this(TextStyler!Text _textStyler)
	{
		_curClasses = [ "" ];
		this._textStyler = _textStyler;
		
		 // TODO: maybe model should be owner of styledText_
		import util.system;
		_cursorModel = createQuad(Rectf(0,0,1, 1), gui.resources.material.Material.create(getRunningExecutablePath() ~ "white.png"));
		cursorVisible = true;
		// std.stdio.writeln(getRunningExecutablePath() ~ "white.png");
		// this._cursorModel.material.texture = font.fontMap;
		//_textStyler.text.onInsert.connect(&onTextDirty);
		//_textStyler.text.onRemove.connect(&onTextDirty);
		static if (!_isBasicText)
		{
			_textStyler.text.onDirty.connect(&onTextDirty);
		}
		else
		{
			_textStyler.scheduleAll();
		}
		_textStyler.onChanged.connect(&onTextDirty);
		_bufferOffsetForCurrentCache = int.max;
	}

	override EventUsed send(Event event, Widget widget) 
	{ 
		// onTextDirty();
		if (event.type == EventType.StyleSheetChanged)
			_textDirty = true;

		return EventUsed.no; 
	}

	private void onTextDirty(Text)
	{
		onTextDirty();
	}

	void onTextDirty()
	{
		cursorVisible = true;
		_textDirty = true;
	}

	void toggleCursorVisibility()
	{
		cursorVisible = !cursorVisible;
	}

	@property 
	{
		Text text()
		{
			return _textStyler.text;
		}

		void text(Text t)
		{
			_textDirty = true;
			_textStyler.text = text;
		}

		TextStyler!Text textStyler()
		{
			return _textStyler;
		}

		void textStyler(TextStyler!Text styler)
		{
			if (_textStyler !is null)
				_textStyler.onChanged.disconnect(&onTextDirty);
			_textStyler = styler;
			styler.onChanged.connect(&onTextDirty);
			styler.scheduleAll();
			_textDirty = true;
		}

		//string selectionStyle()
		//{
		//    return _selectionModel.styleName;
		//}
		//
		//void selectionStyle(string name)
		//{
		//    if (_selectionModel !is null)
		//        _selectionModel.styleName = name;
		//}

		ref bool multiLine()
		{
			return _multiLine;
		}

		Vec2f layoutSize() 
		{
			if (_layout.lines.empty)
				return Vec2f(0,0);
			Vec2f topLeft = _layout.lines[0].rect.pos;
			Vec2f bottomRight = _layout.lines[$-1].rect.posMax;
			bottomRight.x = _layout.lines[$-1].renderOffsetX;
			return bottomRight - topLeft;
		}

		bool textDirty() const
		{
			return _textDirty;
		}

		void textDirty(bool d)
		{
			_textDirty = d;
		}
	}
	

	/*
	void runCommand(string commandName, Variant data)
	{
		//auto c = CommandManager.singleton.lookup(commandName);
		if (c is null) return; // no such command
		runCommand(c.name, data); // todo: just use command as param
	}

	void runCommand(EditorCommand c, Variant data)
	{
		if (c.canExecute(data))
			c.execute(data);
	}
	*/
	
	override void update(Widget widget)
	{
		widget.acceptsKeyboardFocus = true;		
	}

	//BoxModel _box;

	void ensureLayedOut(Widget widget)
	{
		import std.math;
		float szX = isNaN(_layout.bounds.w) ? 100000 : _layout.bounds.w;
		float szY = isNaN(_layout.bounds.h) ? 100000 : _layout.bounds.h;
		updateLayout(widget, Vec2f(szX, szY));
	}

	private void updateLayout(Widget widget, Vec2f layoutSize)
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
		if (layoutSize.y == 0f || (!_textDirty && _layout.bounds.size == layoutSize))
			return;

		//if (layoutSize.y == 0f)
			//return;
		
		//auto transform = Mat4f.makeTranslate(Vec3f(-1,1,0));

		static if (_isBasicText)
		{
			if (_textDirty) 
			{
				updateTextModel(layoutSize, widget);	
			}
		}
		else
		{
			if (true || _textDirty || text.dirty)
			{
				Style style = widget.style;
				if (style is null)
					return;
				Font font = style.font;
				text.visibleLineCount = _multiLine ? cast(int) (layoutSize.y / font.fontLineSkip) : 1;
				updateTextModel(layoutSize, widget);
				text.dirty = false;
			}
		}

		if (_selectionModel is null)
		{
			static if (_isBasicText)
				Region selection = Region(0,0);
			else
				Region selection = _textStyler.text.selection.normalized();
			_selectionModel = new TextSelectionModel(widget.window.styleSheet, _layout, selection);
		}
		else
		{
			//if (_selectionModel.style is null)
			
			_selectionModel.textLayout = _layout;
//			if (_selectionModel.selection != _textStyler.text.selection)
			//{

			static if (_isBasicText)
			{
				// no-op
			}
			else
			{
				_selectionModel.selection = _textStyler.text.selection.normalized();
				_selectionModel.update(_textStyler.text.bufferStartOffset);
			}
			//}
		}
		
		//Mat4f ofstransform;
		//getOffsetTransform(widget, ofstransform);
	}

	override void draw(Widget widget)
	{
//		Vec2f layoutSize = widget.rectStyled.size;
		Vec2f layoutSize = widget.rect.size;
		RectfOffset padding = widget.style.padding;
		updateLayout(widget, Vec2f(layoutSize.x - padding.horizontal, layoutSize.y - padding.vertical));

		// Rectf wrect = widget.window.windowToWorld(widget.rect);
		Mat4f transform;
		widget.getStyledScreenToWorldTransform(transform);
		Mat4f trx = widget.window.MVP * transform;		
		if (_selectionModel !is null)
			_selectionModel.draw(trx);
		if (_model !is null)
			_model.draw(trx);
		

		//int glyphLineIndex = view.cursorPoint - view.buffer.startOfLine(view.cursorPoint);
		// float cursorLineOffset = _layout.lines[row].glyphWorldPos(glyphLineIndex).x;
		//float cursorLineOffset = _model.getGlyphdPos(view.cursorPoint - view.bufferOffset).x;
	
		static if (!_isBasicText)
		{
			if (cursorVisible)
			{
				Style style = widget.style;
				drawCursor(widget, transform, style.font.fontLineSkip);
			}
		}
	}
	
	private void updateTextModelForWidth(float width, Widget widget)
	{
		updateTextModel(Vec2f(width, 1000000000), widget);
	}

	private void updateTextModel(Vec2f layoutSize, Widget widget)
	{

		
		if (_model is null)
		{
			_model = new TextModel; 
			//_box = new BoxModel(Sprite(Rectf(0,0,16,16)), RectfOffset(6,6,6,6));
			//_box = new BoxModel(Sprite(Rectf(0,0,16,16)));
			//_box.color = Vec3f(0.7, 0.7, 0.7);
		}

		// Update style region set.
		// TODO: only on changes
		//_textStyler.update();

		// TODO: get transform
		// Vec2f worldSize = widget.window.pixelSizeToWorld(widget.rect.size);

		_model.clear(); // Clear model buffers
		_model.resetGlyphPositions(); // TODO: this call should probably be part of clear()

		// _layout = TextBoxLayout(_model, Rectf(0, 0, worldSize.x, worldSize.y));
		RectfOffset padding = widget.style.padding;
		_layout.updateFontMaps();
		_layout = TextBoxLayout(_model, Rectf(padding.left, padding.top, layoutSize.x, layoutSize.y));
		
		static if (__traits(compiles, text.bufferStartOffset))
			int textOffset = text.bufferStartOffset;
		else
			int textOffset = 0;

		static if (__traits(compiles, text.visibleLineCount))
			int visibleLineCount = text.visibleLineCount;
		else
			int visibleLineCount = 10000000;

		StyleSheet styleSheet = widget.window.styleSheet;

		foreach (r; _textStyler.regionSet)
		{
			if (_layout.lineCount > visibleLineCount)
				break;

			if (r.b <= textOffset) continue;
			if (r.contains(textOffset))
			{
				r.a = textOffset;
			}
			
			string styleName = _textStyler.styleIDToName(r.id);
			_curClasses[0] = styleName;
			Style style = styleName is null ? widget.style : styleSheet.getStyle(this);

			//style.font.updateFontMap();
			auto intersectParts = r.intersect3(selection);
			if (!intersectParts.before.empty)
			{
				// unselected
				auto r2 = intersectParts.before;
				_layout.add(text[r2.a .. r2.b], style);
			}

			if (!intersectParts.at.empty)
			{
				// selected
				//import graphics.color;
//				selectionStyle.parent = style;
				// selectionStyle.color = Color(0,0,1);
				//selectionStyle.font.updateFontMap();
				auto r2 = intersectParts.at;
				_layout.add(text[r2.a .. r2.b], style); // selectionStyle
			}

			if (!intersectParts.after.empty)
			{
				// unselected
				auto r2 = intersectParts.after;
				_layout.add(text[r2.a .. r2.b], style);
			}

			//if (!r.empty)
				//_layout.add(text[r.a .. r.b], style);
			
			if (_layout.done)
				break;
		}
		
		// Invalidate glyphRect cache
		_bufferOffsetForCurrentCache = int.max;

		_textDirty = false;

		if (_layout.lines.empty)
			_model.clear(); // Clear model buffers

		layoutChanged();
	}

	// World rect relative to widget
	private Rectf getRectForViewIndex(int idx)
	{
		auto relIdx = cast(int)idx - cast(int)textBufferStartOffset;
		Rectf rect = Rectf(0, 0, 0, 0);

		if (relIdx < 0)
		{
			return rect;
		}
		else if (idx == text.length)
		{
			// Special handling for end of doc because no glyph info is present for that index obviously
			if (relIdx < 1)
				return rect; // no text for cursor

			// The last character may be \n or \r\n in which case the rect should be located on the beginning
			// of the next line.
			bool lastIsNewline = false;
			if (text[relIdx-1] == '\n')
			{
				lastIsNewline = true;
				relIdx--;
				if (text.length > 2 && text[relIdx-1] == '\r')
				{
					relIdx--;
				}
				auto r = getRectForViewIndex(relIdx);
				if (!r.x.isFinite())
					return rect;
				// Modify to start of line
				r.x = 0;
				r.y -= r.h;
				return r;
			}

			rect = _model.getGlyphPos(relIdx-1);
			if (!rect.x.isFinite())
				return rect;
			rect.x = rect.x + rect.w;
		}
		else
		{
			rect = _model.getGlyphPos(relIdx);
		}
		return rect;
	}

	private Mat4f getTransformForViewIndex(int idx, ref Rectf rect)
	{
		rect = getRectForViewIndex(idx);
		if (!rect.x.isFinite())
			return Mat4f.IDENTITY;
		
		return Mat4f.makeTranslate(Vec3f(rect.x, rect.y, 0f));
	}

	private Mat4f getTransformForViewIndex(int idx)
	{
		Rectf rect = void;
		return getTransformForViewIndex(idx, rect);
	}

	private void getTransformForIdx(ref Mat4f transform, float fontLineSkip, int idx)
	{
		Rectf rect = void;
		auto posTrans = getTransformForViewIndex(idx, rect);
		auto isStartOfText = idx == 0;
		if (posTrans == Mat4f.IDENTITY)
		{
			if (!isStartOfText)
				return;
			auto fallbackHeight = fontLineSkip;
			rect.h = fallbackHeight;
			rect.x = 0;
			posTrans = Mat4f.makeTranslate(Vec3f(rect.x, -rect.h, 0f));
		}

//		auto scaleTrans = Mat4f.makeScale(Vec3f(widget.window.pixelWidthToWorld(1), rect.h, 0));
		auto scaleTrans = Mat4f.makeScale(Vec3f(1, rect.h, 0));
		transform = transform * posTrans * scaleTrans;	
	}

	private Rectf getGlyphRectRelative(Widget widget, int idx)
	{
		Rectf rect = void;
		auto posTrans = getTransformForViewIndex(idx, rect);
		if (!rect.x.isFinite())
			return rect;

		Mat4f trx;
		widget.getScreenToWorldTransform(trx);
		
		trx = widget.window.MVP * trx; // * posTrans;
		
		/*
		Rectf r = getRectForViewIndex(idx);
		if (r.x == float.nan)
			return r;		
		r = widget.window.worldToWindow(r);
		r.pos = r.pos + widget.rect.pos;
		*/

		Rectf result;
		//Vec4f p = Vec4f(rect.pos, 1f);
		result.pos = (trx * Vec4f(rect.x, rect.y, 0f, 1f)).xy;
		auto p = rect.posMax;
		result.posMax = (trx * Vec4f(p.x, p.y, 0f, 1f)).xy;
		
		auto r2 = widget.window.worldToWindow(result);
		//r2.pos.y -= r2.size.y;
		return r2;

		//return result;
	}

	Rectf getGlyphRect(Widget w, int idx)
	{
		int bufOffset = textBufferStartOffset;
		assert(idx >= bufOffset, "getGlyphRect() out of bounds. Too small.");
		// assert(idx >= bufOffset, "getGlyphRect() out of bounds. Too large.");

		int i = idx - bufOffset;

		if (bufOffset != _bufferOffsetForCurrentCache)
		{
			// Clear cache
			_bufferOffsetForCurrentCache = bufOffset;
			_glyphWindowRectCache.length = 0;
			assumeSafeAppend(_glyphWindowRectCache);
		}

		if (i < _glyphWindowRectCache.length)
		{
			return _glyphWindowRectCache[i];
		}
		else
		{
			int nextIdx = _glyphWindowRectCache.length;

			Rectf glyphRect = void;

			while (nextIdx <= i)
			{
				glyphRect = getGlyphRectRelative(w, nextIdx + bufOffset);
				_glyphWindowRectCache ~= glyphRect;
				nextIdx++;
			}
			return glyphRect;
		}
	}

	/** Get glyph index into buffer that is a window position
		
		Params:
			widget = the widget associated with this renderer
			pos = the windows position to find glyph for

		Returns:
			A tuple of bool,uint,Rectf. The is true if the position is directly at a glyph and false otherwise.
			The uint is the index into the buffer where the glyph is located in case the bool is true. 
			The uint is the index into the buffer of the end of line for the line where the mouse is located in case 
			the bool is false. If the cursor is at no buffer line uint.max is returned.
			The Rectf is the rect that the glyph occupies.
	*/
	GlyphHit getGlyphAt(Widget widget, Vec2f pos)
	{
		// TODO: Maybe this should be handled by the textrenderer ie. click detection. Maybe not.
		// Naive brute force finding of glyph pos
		int i = textBufferStartOffset;
		int bufOffset = i;

		if (bufOffset != _bufferOffsetForCurrentCache)
		{
			// Clear cache
			_bufferOffsetForCurrentCache = bufOffset;
			_glyphWindowRectCache.length = 0;
			assumeSafeAppend(_glyphWindowRectCache);
		}
		else
		{
			// Check if window rect for glyph is cached
			foreach (r; _glyphWindowRectCache)
			{
				if (pos.y <= r.y2)
					return GlyphHit(false, !r.x.isFinite() || bufOffset == i ? 
									int.max : i-1, r);

				if (r.contains(pos))
					return GlyphHit(true, i, r);

				i++;
			}
		}
		
		// int i = bufferView.bufferOffset;

		// Vec2f mousePos = event.mousePos;
		Rectf glyphRect = getGlyphRectRelative(widget, i);
		_glyphWindowRectCache ~= glyphRect;

		// glyphRect.y is bottom 
		bool found = false;
		while (glyphRect.x.isFinite() && pos.y > glyphRect.y2)
		{
			//std.stdio.writeln(glyphRect, " ", pos);
			if (glyphRect.contains(pos))
			{
				found = true;
				break;
			}
			i++;
			glyphRect = getGlyphRectRelative(widget, i);
			_glyphWindowRectCache ~= glyphRect;
		}
		if (found)
			return GlyphHit(true, i, glyphRect);
		return GlyphHit(false, !glyphRect.x.isFinite()|| bufOffset == i ? int.max : i-1, glyphRect);
	}

	void drawCursor(Widget widget, ref Mat4f transform, float fontLineSkip)
	{
		if (!cursorSupported)
			return;

		static if (!_isBasicText)
		{
			getTransformForIdx(transform, fontLineSkip, text.cursorPoint);
			_cursorModel.draw(widget.window.MVP * transform);
		}

		/*
		// Cull cursor
		int cursorLine = _multiLine ? text.buffer.lineNumber(text.cursorPoint) : 0;
		
		//7std.stdio.writeln("FOOOO ", cursorLine, " ", view.cursorPoint, " ", view.bufferOffset, " ", view.lineOffset, " ", _layout.lines.length, " ", view.buffer.length);
		if (cursorLine < text.lineOffset || cursorLine > (text.lineOffset + _layout.lines.length) || _layout.lines.empty)
			return;

		//int column = view.cursorPoint - view.buffer.startOfLine(view.cursorPoint);
		//		Vec2f cursorOffset = Window.active.pixelSizeToWorld(Vec2f(0, -cast(float)(row * font.fontLineSkip)));
		//		cursorOffset.x = cursorLineOffset;
		//std.stdio.writeln(row);
		int row = cursorLine - text.lineOffset;
		//std.stdio.writeln("row ", row, " ", view.buffer.lineNumber(view.cursorPoint), " " , view.lineOffset);
		auto lineRect = _layout.lines[row].rect;
*/

//		transform = transform * Mat4f.makeTranslate(Vec3f(rect.x, lineRect.y - (lineRect.h ), 0f)) * Mat4f.makeScale(Vec3f(widget.window.pixelWidthToWorld(1), lineRect.h, 0));
		//		transform = transform * Mat4f.makeTranslate(Vec3f(rect.x, lineRect.y - (lineRect.h - _layout.lines[row].textBaseLine), 0f)) * Mat4f.makeScale(Vec3f(rect.w, lineRect.h, 0));
		//_cursorModel.draw(widget.window.MVP * transform);
	}
}
//import application;
/*
@property BufferView content(Widget widget, string text)
{
	//auto bv = Application.bufferViewManager.create(text);
	return content(widget, bv);
}
*/

@property auto content(Text)(Widget widget, Text view)
{
//	auto styledText = new StyledText!Text(view, new DSourceStyler!Text());
	auto textStyler = new TextStyler!Text(view);
	auto tr = new TextRenderer!Text(textStyler);
	widget.features ~= tr;
	return tr;
}

Text text(Text)(Widget widget)
{
	foreach (f; widget.features)
	{
		auto tr = cast(TextRenderer!Text) f;
		if (tr !is null)
			return tr.text;
	}
	return null;
}
