module controls.texteditor;

import core.buffer;
import core.bufferview;
import core.command : CommandManager;
import graphics._;
import gui.event;
import gui.style;
import gui.widget;
import gui.widgetfeature._;
import gui.window;
import guiapplication;
import math._;

import std.conv;
import std.string;

alias TextRenderer!BufferView BufferViewRenderer;

class TextEditor : Widget
{
	/*
		Text editor
		* selection (should also work for simple text rendering)
		* undo/redo
		* move line/word
		* linelayout caching (textrenderer)
	 */
	BufferView bufferView;
	BufferViewRenderer renderer;

	// Child widget of TextEditor
	TextEditorAnchor[] visibleAnchorsChildWidgets;

	private uint _mouseStartSelectionIdx;

	this(Widget parent, BufferView buf)
	{
		super(parent);
		acceptsKeyboardFocus = true;
		// background = "edit-background"; 
		
		// features ~= new NineGridRenderer("edit-background");
		// this.alignTo(Anchor.TopLeft, Vec2f(-1, -1), Vec2f(6,0));
		// this.alignTo(Anchor.BottomRight);
		renderer = (this.content = buf);
		bufferView = buf;
		bufferView.onInsert.connect(&this.onTextInserted);
		bufferView.onRemove.connect(&this.onTextRemoved);
		
		// bufferView.onDirty.connect(&this.onBufferViewDirty);
		
		bufferView.onAnchorVisibilityChanged.connect(&onAnchorVisibilityChanged);

		_mouseStartSelectionIdx = uint.max;

		//onKeyboardFocusSignal.connect((Event ev) {
		//    //window.mouseCursor(MouseCursor.iBeam);
		//});

		//onKeyboardUnfocusSignal.connect((Event ev) {
		//    window.mouseCursor(MouseCursor.arrow);
		//});
	}

	override EventUsed onMouseOver(Event e)
	{
		window.mouseCursor(MouseCursor.iBeam);
		return EventUsed.no;
	}

	override EventUsed onMouseOut(Event e)
	{
		window.mouseCursor(MouseCursor.arrow);
		return EventUsed.no;
	}

	void toggleCursorVisibility()
	{
		renderer.toggleCursorVisibility();
	}

	override EventUsed onEvent(Event event)
	{
		if (event.type == EventType.Resize)
			renderer.textDirty = true;
		
		if (!isKeyboardFocusWidget())
		{
			return super.onEvent(event);
			//return EventUsed.no;
		}

		switch (event.type)
		{
			case EventType.Text: // KeyBindings listen on KeyDown but here we listen on Text ie. last keybinding char gets here!! :(
				bufferView.insert(event.ch); // put text at cursor
				//std.stdio.writeln(event.ch, " ", std.conv.to!string(event.mod));
				return EventUsed.yes;
			case EventType.Command:
				switch (event.name)
				{
					case "navigate.left":
						bufferView.cursorLeft(1);
						renderer.cursorVisible = true;
						return EventUsed.yes;
					case "navigate.right":
						bufferView.cursorRight(1);
						renderer.cursorVisible = true;
						return EventUsed.yes;
					case "navigate.up":
						bufferView.cursorUp(1);
						uint lineNum = bufferView.lineNumber;
						if (lineNum < bufferView.lineOffset)
							bufferView.scrollUp();
						renderer.cursorVisible = true;
						return EventUsed.yes;
					case "navigate.down":
						bufferView.cursorDown();
						uint lineNum = bufferView.lineNumber;
						if (lineNum > (bufferView.lineOffset + bufferView.visibleLineCount))
							bufferView.scrollDown();
						renderer.cursorVisible = true;
						return EventUsed.yes;
					default:
						break;
				}
				break;
			default:
				break;
		}

		// TODO: isn't behavior just a event -> edit mapping e.g. command
		// TODO: have several kinds of behaviours for app, window, textview. 
		//       App and window should have the chance to grab events before textview
		//EditorBehavior.current.onEvent(event, bufferView);
		return super.onEvent(event);
		//return EventUsed.no;
	}

	override void draw()
	{	
		if (!visible)
			return;
		
		renderer.selection = bufferView.selection;
		import derelict.opengl3.gl3;
		
		Rectf r = rect;
		r.y = window.size.y - (r.h + r.y);

		glScissor( cast(int)r.x, cast(int)r.y, cast(int)r.w, cast(int)r.h);
		
		glEnable(GL_SCISSOR_TEST);
		super.draw();
		glDisable(GL_SCISSOR_TEST);
	}

	override EventUsed onMouseScroll(Event event)
	{
		// Scroll view
		int d = cast(int) event.scroll.y;
		if (d < 0)
		{
			foreach (i; 0..d*d)
				bufferView.scrollDown();
		}
		else
		{
			foreach (i; 0..d*d)
				bufferView.scrollUp();
		}
		return EventUsed.yes;
	}

	override EventUsed onMouseDown(Event event)
	{
		auto info = renderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
			return onGlyphMouseDown(event, info);

		return EventUsed.yes;
	}

	override EventUsed onMouseDoubleClick(Event event)
	{
		auto info = renderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
		{
			bufferView.cursorToWordBefore();
			bufferView.selectToWordAfter();
		}

		return EventUsed.yes;
	}

	override EventUsed onMouseTripleClick(Event event)
	{
		auto info = renderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
		{
			bufferView.cursorToBeginningOfLine();
			bufferView.selectToEndOfLine();
			bufferView.selectRight();
		}

		return EventUsed.yes;
	}

	override EventUsed onMouseMove(Event event)
	{
		if (_mouseStartSelectionIdx == uint.max)
			return super.onMouseMove(event);

		auto info = renderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
			_updateSelectionEnd(info, event.mousePos);

		return EventUsed.yes;
	}

	override EventUsed onMouseUp(Event event)
	{
		auto info = renderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
			return onGlyphMouseUp(event, info);

		_mouseStartSelectionIdx = uint.max;

		return EventUsed.yes;
	}

	EventUsed onGlyphMouseDown(Event event, GlyphHit hit)
	{
		_updateSelectionEnd(hit, event.mousePos);
		_mouseStartSelectionIdx = bufferView.selection.a;
		return EventUsed.yes;
	}

	EventUsed onGlyphMouseUp(Event event, GlyphHit hit)
	{
		//_updateSelectionEnd(hit, event.mousePos);
		_mouseStartSelectionIdx = uint.max;
		return EventUsed.yes;
	}

	private void _updateSelectionEnd(GlyphHit hit, Vec2f mousePos)
	{
		uint index;
		if (true || _mouseStartSelectionIdx == uint.max)
		{
			// Selection start not set. Do so.
			// When picking the start glyph we want to split the hit glyph vertically and if the
			// mouse pointer is on the right side then include the glyph in the selection. If it is on the
			// left side we exclude it from the selection. This magic is only done when finding the start of the
			// selection, not when determining the end or when expanding the selection.
			auto yPosHalfWayGlyphRect = hit.rect.x + hit.rect.w * .5f;
			index = yPosHalfWayGlyphRect < mousePos.x ? hit.index+1 : hit.index; 
			if (_mouseStartSelectionIdx == uint.max)
				_mouseStartSelectionIdx = index;
		}
		else
		{
			index = hit.index;
		}
		
		Region r = _mouseStartSelectionIdx < index ? Region(_mouseStartSelectionIdx, index, 0) : Region(index, _mouseStartSelectionIdx, 0);
		bufferView.selection = r;

		bufferView.cursorPoint = index;
		bufferView.setPreferredCursorColumnFromIndex();
		renderer.cursorVisible = true;
	}

	// TODO: move slots to bufferView
	// Text inserted at pos and forward
	private void onTextInserted(BufferView v, BufferView.BufferString text, uint pos)
	{
		bufferView.selection.entriesInserted(pos, text.length);
	}

	// Text remove from pos and forward
	private void onTextRemoved(BufferView v, BufferView.BufferString text, uint pos)
	{
		bufferView.selection.entriesRemoved(pos, text.length);
	}

	//private void onBufferViewDirty(BufferView bv)
	//{
	//    foreach (_childWidget; visibleAnchorsChildWidgets)
	//        _childWidget.recalculateRect(this);
	//}

	private void onAnchorAdded(TextBuffer buf, TextBufferAnchor anchor)
	{
		// Dirty will rescan for anchor visibility and include this newly 
		// added anchor if visible
		bufferView.dirty = true;
	}

	private void onAnchorRemoved(TextBuffer buf, TextBufferAnchor anchor)
	{
		string candidateName = anchor.id.to!string ~ "-textBufferAnchor";
		foreach (c; children)
		{
			if (c.name == candidateName)
			{
				removeChild(c);
				return;
			}
		}
	}
	
	private void onAnchorVisibilityChanged(BufferView bufferView, TextBufferAnchor[] newAnchors)
	{
		import std.algorithm;

		foreach (_childWidget; visibleAnchorsChildWidgets)
		{
			_childWidget.visible = false;
		}

		visibleAnchorsChildWidgets.length = 0;
		assumeSafeAppend(visibleAnchorsChildWidgets);

		// Show widgets that became visible
		foreach (a; newAnchors)
		{
			auto aw = ensureAnchorWidget(a);
			if (aw !is null)
			{
				aw.textAnchor = a;
				aw.visible = true;
				visibleAnchorsChildWidgets ~= aw;
			}
		}
	}

	// Returns true if the widget is present after the call
	private TextEditorAnchor ensureAnchorWidget(TextBufferAnchor anchor)
	{
		string candidateName = anchor.id.to!string ~ "-textBufferAnchor";
		foreach (c; children)
		{
			if (c.name == candidateName)
				return cast(TextEditorAnchor) c;
		}
		
		if (anchor.owner !is null)
		{
			TextEditorAnchorOwner anchorOwner = cast(TextEditorAnchorOwner) anchor.owner;
			if (anchorOwner !is null)
			{
				auto w = anchorOwner.createAnchorWidget(anchor);
				if (w !is null)
				{
					w.parent = this;
					w.name = candidateName;
					return w;
				}
			}
		}
		return null;
	}

	void setLineAnchor(uint lineNumber, TextBufferAnchorOwner owner)
	{
		bufferView.buffer.ensureLineAnchor(lineNumber, owner);
	}

	void unsetLineAnchor(uint lineNumber, string type)
	{
		auto anchor = bufferView.buffer.getLineAnchor(lineNumber);
		if (anchor.id == uint.max)
			return; // no anchor
		bufferView.buffer.removeLineAnchorByLine(anchor.id); // TODO: optimize
	}

	Rectf lineRect(uint lineIdx)
	{
		auto lineStart = bufferView.buffer.startAtLineNumber(lineIdx);
		auto lineEnd = bufferView.buffer.endAtLineNumber(lineIdx);
		if (lineStart < bufferView.bufferStartOffset)
			return Rectf();
		Rectf startGlyphRect = glyphRect(lineStart);
		Rectf endGlyphRect = glyphRect(lineEnd);
		return startGlyphRect.makeUnion(endGlyphRect);
	}

	Rectf glyphRect(uint idx)
	{
		return renderer.getGlyphRect(this, idx);
	}
}

import gui.widgetfeature.constraintlayout;

interface TextEditorAnchorOwner : TextBufferAnchorOwner
{
	TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor);
}

class TextEditorAnchor : Widget
{
	TextBufferAnchor textAnchor;
	Anchor widgetAnchor;
	mixin styleProperty!("Vec2f", "offset");
	// Vec2f offset;
	
	bool inView;

	this()
	{
		super();
		widgetAnchor = Anchor.BottomLeft;
		w = 16; // This should be loaded from stylesheet
		h = 16;
		// offset = Vec2f(0,0);
		inView = false;
	}

	override void draw()
	{		
		if (!visible)
			return;

		recalculateRect();
		if (inView)
			super.draw();
	}

	void recalculateRect()
	{
		TextEditor editor = cast(TextEditor) parent;
		Rectf lineRect = editor.lineRect(textAnchor.number);
		inView = ! lineRect.x.isNaN;
		if (!inView)
			return;

		lineRect += offset;
		
		Rectf r = rect;
		r.pos = Vec2f(0,0);
		Rectf lr = lineRect;
		lr.pos = Vec2f(0,0);
		// Vec2f lineOffset = anchorPosition(lr, widgetAnchor);
		r.pos = lineRect.pos - anchorPosition(r, widgetAnchor); // - lineOffset;
		r.pos.x += lineRect.w;
		rect = r;
	}
}
