module controls.texteditor;

import core.bufferview;
import core.command : CommandManager;
import graphics._;
import gui.event;
import gui.style;
import gui.widget;
import gui.widgetfeature._;
import guiapplication;
import math._;


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
	private uint _mouseStartSelectionIdx;

	this(Widget parent, BufferView buf)
	{
		super(parent);
		acceptsKeyboardFocus = true;
		features ~= new BoxRenderer("edit-background");
		this.alignTo(Anchor.TopLeft);
		this.alignTo(Anchor.BottomRight);
		renderer = (this.content = buf);
		bufferView = buf;
		bufferView.onInsert.connect(&this.onTextInserted);
		bufferView.onRemove.connect(&this.onTextRemoved);
		_mouseStartSelectionIdx = uint.max;
	}

	override void draw()
	{	
		if (!visible)
			return;
		
		renderer.selection = bufferView.selection;
		super.draw();
	}

	override EventUsed onMouseScroll(Event event)
	{
		std.stdio.writeln("scrool");
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
		_updateSelectionEnd(hit, event.mousePos);
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
	}

	// TODO: move slots to bufferView
	// Text inserted at pos and forward
	void onTextInserted(BufferView v, BufferView.BufferString text, uint pos)
	{
		bufferView.selection.entriesInserted(pos, text.length);
	}

	// Text remove from pos and forward
	void onTextRemoved(BufferView v, BufferView.BufferString text, uint pos)
	{
		bufferView.selection.entriesRemoved(pos, text.length);
	}
}
