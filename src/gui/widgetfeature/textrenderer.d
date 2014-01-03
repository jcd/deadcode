module gui.widgetfeature.textrenderer;

import graphics.model; 
import gui.resources.material : Material;
import gui._;
import math._;
import std.range;
import std.variant;
import std.conv;
import std.traits;

/** The Text feature of a widget can be used to displays the contents of a TextView
 *  on the widget
 */
class TextRenderer(Text) : WidgetFeature
{
	import core.buffer;
	import core.command;
	
	private
	{
		TextModel _model;
		StyledText!Text _styledText;
		Model _cursorModel = null;
		TextBoxLayout _layout;
		bool _multiLine = true;
		bool _textDirty = true;
		enum _isBasicText = ! hasMember!(Text, "dirty");
	}

	bool cursorEnabled = true;

	alias void delegate(TextRenderer!Text) Callback;
	
	Callback onLayoutChanged;
	private void layoutChanged()
	{
		if (onLayoutChanged !is null)
			onLayoutChanged(this);
	}

	this(StyledText!Text _styledText)
	{
		this._styledText = _styledText;
		 // TODO: maybe model should be owner of styledText_
		//assert(StyleSet.builtin.length != 0);
		//assert(StyleSet.builtin[0].font !is null);
		//Font f = StyleSet.builtin[0].font;
		import util.system;
		this._cursorModel = createQuad(Rectf(0,0,1, 1), gui.resources.material.Material.create(getRunningExecutablePath() ~ "white.png"));
		// std.stdio.writeln(getRunningExecutablePath() ~ "white.png");
		//this._cursorModel.material.texture = font.fontMap;
	}

	@property 
	{
		Text text()
		{
			return _styledText.text;
		}

		void text(Text t)
		{
			_textDirty = true;
			_styledText.text = text;
		}

		ref bool multiLine()
		{
			return _multiLine;
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

	override EventUsed send(Event event, Widget widget)
	{
		if (!widget.isKeyboardFocusWidget())
			return EventUsed.no;

		switch (event.type)
		{
			case EventType.Text: // KeyBindings listen on KeyDown but here we listen on Text ie. last keybinding char gets here!! :(
				text.insert(event.ch); // put text at cursor
				//std.stdio.writeln(event.ch, " ", std.conv.to!string(event.mod));
				return EventUsed.yes;
			default:
				break;
		}

		// TODO: isn't behavior just a event -> edit mapping e.g. command
		// TODO: have several kinds of behaviours for app, window, textview. 
		//       App and window should have the chance to grab events before textview
		//EditorBehavior.current.onEvent(event, bufferView);
		return EventUsed.no;
	}
	
	override void update(Widget widget)
	{
		widget.acceptsKeyboardFocus = true;		
	}

	void getTransform(Widget widget, ref Mat4f transform)
	{
		Rectf wrect = widget.window.windowToWorld(widget.rect);
		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
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
		
		if (widget.rect.h == 0f)
			return;

		if (_model is null)
			_model = new TextModel; //(styleSet);

		Mat4f transform;
		getTransform(widget, transform);
		//auto transform = Mat4f.makeTranslate(Vec3f(-1,1,0));
		
		static if (_isBasicText)
		{
			if (_textDirty) 
			{
				updateTextModelMultiline(text, widget, styleSet, 0);			
			}
		}
		else
		{
			if (true || _textDirty || text.dirty)
			{
				Style style = styleSet.getStyle(DefaultStyleName);
				Font font = style.font;
				text.visibleLineCount = _multiLine ? cast(uint) (widget.rect.size.y / font.fontLineSkip) : 1;
				updateTextModelMultiline(text, widget, styleSet, text.bufferOffset);
				text.dirty = false;
			}
		}


		_model.draw(widget.window.MVP * transform);

		//uint glyphLineIndex = view.cursorPoint - view.buffer.startOfLine(view.cursorPoint);
		// float cursorLineOffset = _layout.lines[row].glyphWorldPos(glyphLineIndex).x;
		//float cursorLineOffset = _model.getGlyphWorldPos(view.cursorPoint - view.bufferOffset).x;
	
		static if (!_isBasicText)
		{
			if (cursorEnabled)
			{
				Style style = styleSet.getStyle(DefaultStyleName);
				drawCursor(widget, transform, style.font.fontLineSkip);
			}
		}
	}
		
	void updateTextModelMultiline(TextRange)(TextRange textRange, Widget widget, StyleSet styleSet, uint textOffset)
	{

		// Update style region set.
		// TODO: only on changes
		_styledText.update(styleSet);

		// TODO: get transform
		Vec2f worldSize = widget.window.pixelSizeToWorld(widget.rect.size);

		_model.resetGlyphPositions();

		_layout = TextBoxLayout(_model, Rectf(0, 0, worldSize.x, worldSize.y));
		foreach (r; _styledText.regionSet)
		{
			if (r.b <= textOffset) continue;
			if (r.contains(textOffset))
			{
				r.a = text.bufferOffset;
			}
			
			Style style = styleSet.getStyle(_styledText.styleIDToName(r.id));
			_layout.add(text[r.a .. r.b], style);
			if (_layout.done)
				break;
		}
		
		if (_layout.lines.empty)
			_model.clear(); // Clear model buffers
		
		_textDirty = false;
		layoutChanged();
	}

	/*
	void updateTextModelSingleline(Widget widget, StyleSet styleSet)
	{
		// Update style region set.
		// TODO: only on changes
		_styledText.update(styleSet);

		// TODO: get transform
		Vec2f worldSize = widget.window.pixelSizeToWorld(widget.rect.size);
		_model.resetGlyphPositions();

		auto lb = TextModel.LineBox(Rectf(0, 0, worldSize.x, worldSize.y), false, true, false, float.init, 0);
		size_t charsUsed = 0;

		foreach (r; _styledText.regionSet)
		{
			if (charsUsed >= text.length || lb.isFull) break;
			charsUsed += _model.add(lb, text.buffer[r.a .. r.b], styleSet[r.id]);	
		}

		if (charsUsed == 0)
			_model.clear(); // Clear model buffers
		
		_textDirty = false;
	}
*/
	Rectf getRectForViewIndex(uint idx)
	{
		auto relIdx = cast(int)idx - cast(int)text.bufferOffset;
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
				if (r.x == float.nan)
					return rect;
				// Modify to start of line
				r.x = 0;
				r.y -= r.h;
				return r;
			}

			rect = _model.getGlyphWorldPos(relIdx-1);
			if (rect.x == float.nan)
				return rect;
			rect.x = rect.x + rect.w;
		}
		else
		{
			rect = _model.getGlyphWorldPos(relIdx);
		}
		return rect;
	}

	Mat4f getTransformForViewIndex(uint idx, ref Rectf rect)
	{
		rect = getRectForViewIndex(text.cursorPoint);
		if (rect.x == float.nan)
			return Mat4f.IDENTITY;
		
		return Mat4f.makeTranslate(Vec3f(rect.x, rect.y, 0f));
	}

	Mat4f getTransformForViewIndex(uint idx)
	{
		Rectf rect = void;
		return getTransformForViewIndex(idx, rect);
	}

	void drawCursor(Widget widget, ref Mat4f transform, float fontLineSkip)
	{
		Rectf rect = void;
		auto posTrans = getTransformForViewIndex(text.cursorPoint, rect);
		auto isStartOfText = text.cursorPoint == 0;
		if (posTrans == Mat4f.IDENTITY)
		{
			if (!isStartOfText)
				return;
			auto fallbackHeight = Window.active.pixelHeightToWorld(fontLineSkip);
			rect.h = fallbackHeight;
			rect.x = 0;
			posTrans = Mat4f.makeTranslate(Vec3f(rect.x, -rect.h, 0f));
		}
		
		auto scaleTrans = Mat4f.makeScale(Vec3f(widget.window.pixelWidthToWorld(1), rect.h, 0));
		transform = transform * posTrans * scaleTrans;
		_cursorModel.draw(widget.window.MVP * transform);

		/*
		// Cull cursor
		uint cursorLine = _multiLine ? text.buffer.lineNumber(text.cursorPoint) : 0;
		
		//7std.stdio.writeln("FOOOO ", cursorLine, " ", view.cursorPoint, " ", view.bufferOffset, " ", view.lineOffset, " ", _layout.lines.length, " ", view.buffer.length);
		if (cursorLine < text.lineOffset || cursorLine > (text.lineOffset + _layout.lines.length) || _layout.lines.empty)
			return;

		//uint column = view.cursorPoint - view.buffer.startOfLine(view.cursorPoint);
		//		Vec2f cursorOffset = Window.active.pixelSizeToWorld(Vec2f(0, -cast(float)(row * font.fontLineSkip)));
		//		cursorOffset.x = cursorLineOffset;
		//std.stdio.writeln(row);
		uint row = cursorLine - text.lineOffset;
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
	auto styledText = new StyledText!Text(view, new DSourceStyler!Text());
	auto tr = new TextRenderer!Text(styledText);
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
