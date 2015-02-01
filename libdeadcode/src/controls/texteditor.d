module controls.texteditor;

import core.buffer;
import core.bufferview;
import core.command : CommandManager;
import graphics;
import gui.event;
import gui.style;
import gui.widget;
import gui.widgetfeature;
import gui.window;
//import guiapplication;
import math;

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

	@property TextBuffer.CharType[] text() const
	{
		return bufferView.getText();
	}

	// Child widget of TextEditor
	TextEditorAnchor[] visibleAnchorsChildWidgets;

	private int _mouseStartSelectionIdx;

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

		_mouseStartSelectionIdx = int.max;

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
		
		if (!hasKeyboardFocus())
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
						bufferView.cursorUp();
						renderer.cursorVisible = true;
						return EventUsed.yes;
					case "navigate.down":
						bufferView.cursorDown();
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

	override void layout(bool fit)
	{
		// Get sized ready for the children so that any layouter have them
		foreach (w; children)
			w.size = calcSize(w);

		layoutFeatures(fit);

		// Position goes last so that a base position calculated by e.g. DirectionalLayout feature
		// can be used as relative pos for the calcPosition (ie. the styled position)
		foreach (w; children)
			w.pos = calcPosition(w);
		//		w.recalcPosition();

		// Positions and sizes for children are now set and we can recurse
		layoutChildren(fit);
	}

	override void draw()
	{	
		if (!visible)
			return;
		
		renderer.selection = bufferView.selection.normalized();

		import derelict.opengl3.gl3;
		
		Rectf r = rect;
		r.y = window.size.y - (r.h + r.y);

		glScissor( cast(int)r.x, cast(int)r.y, cast(int)r.w, cast(int)r.h);
		
		glEnable(GL_SCISSOR_TEST);

		// Hack to get correct positions for anchors. recalc part should really be in the layout method
		{
			drawFeatures();
	
			foreach (w; visibleAnchorsChildWidgets)
				w.recalcPosition();
	
			drawChildren();
		}

		glDisable(GL_SCISSOR_TEST);
	}

	override EventUsed onMouseClick(Event event)
	{
		setKeyboardFocusWidget();
		return EventUsed.yes;
	}

	override EventUsed onMouseScroll(Event event)
	{
		int speed = 1;
		int d = cast(int) event.scroll.y;
		int maxScrollFreq = 300;

		if (event.msSinceLastScroll < maxScrollFreq)
		{
			// Scroll view
			speed = cast(int)(d*d*(maxScrollFreq - event.msSinceLastScroll) / 30f);
		}

		if (speed == 0)
			speed = 1;

		// std.stdio.writeln(d, " ", speed, " ", event.scroll.y, " ", event.msSinceLastScroll);
		if (d < 0)
		{
			foreach (i; 0..speed)
				bufferView.scrollDown();
		}
		else
		{
			foreach (i; 0..speed)
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
		if (_mouseStartSelectionIdx == int.max)
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

		_mouseStartSelectionIdx = int.max;

		return EventUsed.yes;
	}

	EventUsed onGlyphMouseDown(Event event, GlyphHit hit)
	{
		if (event.mouseMod.isShiftDown())
		{
			if (_mouseStartSelectionIdx == int.max)
			{
				if (bufferView.selection.empty)
					_mouseStartSelectionIdx = bufferView.cursorPoint;
				else
					_mouseStartSelectionIdx = bufferView.selection.a;
			}
			_updateSelectionEnd(hit, event.mousePos);
			bufferView.setPreferredCursorColumnFromIndex();
		}
		else
		{
			_updateSelectionEnd(hit, event.mousePos);
			_mouseStartSelectionIdx = bufferView.selection.a;
			bufferView.setPreferredCursorColumnFromIndex();
		}
		return EventUsed.yes;
	}

	EventUsed onGlyphMouseUp(Event event, GlyphHit hit)
	{
		//_updateSelectionEnd(hit, event.mousePos);
		_mouseStartSelectionIdx = int.max;
		bufferView.setPreferredCursorColumnFromIndex();
		return EventUsed.yes;
	}

	private void _updateSelectionEnd(GlyphHit hit, Vec2f mousePos)
	{
		int index;
		if (true || _mouseStartSelectionIdx == int.max)
		{
			// Selection start not set. Do so.
			// When picking the start glyph we want to split the hit glyph vertically and if the
			// mouse pointer is on the right side then include the glyph in the selection. If it is on the
			// left side we exclude it from the selection. This magic is only done when finding the start of the
			// selection, not when determining the end or when expanding the selection.
			auto yPosHalfWayGlyphRect = hit.rect.x + hit.rect.w * .5f;
			index = yPosHalfWayGlyphRect < mousePos.x ? hit.index+1 : hit.index; 
			if (_mouseStartSelectionIdx == int.max)
				_mouseStartSelectionIdx = index;
		}
		else
		{
			index = hit.index;
		}
		
		// Region r = _mouseStartSelectionIdx < index ? Region(_mouseStartSelectionIdx, index, 0) : Region(index, _mouseStartSelectionIdx, 0);
		bufferView.selection = Region(_mouseStartSelectionIdx, index, 0);

		bufferView.cursorPoint = index;
		renderer.cursorVisible = true;
	}

	// TODO: move slots to bufferView
	// Text inserted at pos and forward
	private void onTextInserted(BufferView v, BufferView.BufferString text, int pos)
	{
		//Region r = bufferView.selection;
		//r.entriesInserted(pos, text.length);
		//bufferView.selection = r;
	}

	// Text remove from pos and forward
	private void onTextRemoved(BufferView v, BufferView.BufferString text, int pos)
	{
		//Region r = bufferView.selection;
		//r.entriesRemoved(pos, text.length);
		//bufferView.selection = r;
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
				c.parent = null;
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
				auto w = anchorOwner.createAnchorWidget(anchor, this);
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

	auto setLineAnchor(int lineNumber, TextBufferAnchorOwner owner)
	{
		return bufferView.buffer.ensureLineAnchor(lineNumber, owner);
	}

	void unsetLineAnchor(int lineNumber, string type)
	{
		auto anchor = bufferView.buffer.getLineAnchor(lineNumber);
		if (anchor.id == int.max)
			return; // no anchor
		bufferView.buffer.removeLineAnchorByLine(anchor.id); // TODO: optimize
	}

	void unsetAnchorById(int anchorID)
	{
		bufferView.buffer.removeLineAnchorByID(anchorID);
	}

    GenericTextEditorAnchor setLineAnchor(int lineNumber, string cssClassName)
    {
        // TODO: fix coupling on children length and ensureLineAnchor
		auto origLen = children.length;
        auto a = bufferView.buffer.ensureLineAnchor(lineNumber, GenericTextEditorAnchor.anchorManager);
        GenericTextEditorAnchor res = null;
        if (origLen != children.length)
        {
            res = cast(GenericTextEditorAnchor)(children[$-1]);
            res._classes = [ cssClassName ];
        }
        return res;
    }

	Rectf lineRect(int lineIdx)
	{
		auto lineStart = bufferView.buffer.startAtLineNumber(lineIdx);
		auto lineEnd = bufferView.buffer.endAtLineNumber(lineIdx);
		return textRect(lineStart, lineEnd);
	}

	Rectf textRect(int startIdx, int endIdx)
	{
		if (startIdx < bufferView.bufferStartOffset)
			return Rectf();
		Rectf startGlyphRect = glyphRect(startIdx);
		Rectf endGlyphRect = glyphRect(endIdx);
		return startGlyphRect.makeUnion(endGlyphRect);
	}

	Rectf glyphRect(int idx)
	{
		return renderer.getGlyphRect(this, idx);
	}
}

import gui.layout.constraintlayout;

interface TextEditorAnchorOwner : TextBufferAnchorOwner
{
	TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor, TextEditor editor);
}

class TextEditorAnchor : Widget
{
	TextBufferAnchor textAnchor;
	Anchor widgetAnchor;
	
	bool inView;

	this()
	{
		super();
		widgetAnchor = Anchor.TopLeft;
		w = 16; 
		h = 16;
		inView = false;
	}

	override void draw()
	{		
		if (visible && inView)
			super.draw();
	}

	protected void recalcPosition()
	{
		if (visible)
			recalculateRect();
	}

	void recalculateRect()
	{
		TextEditor editor = cast(TextEditor) parent;

		TextBuffer buffer = editor.bufferView.buffer;
		auto lineIdx = textAnchor.number;
		auto lineStart = buffer.startAtLineNumber(lineIdx);
		auto lineEnd = buffer.endAtLineNumber(lineIdx);

        if (lineEnd != lineStart)
        {
		auto lineEndChar = buffer.findOneNotOfReverse(lineEnd, " \t\r\n");
		if (lineEndChar != int.max)
			lineEnd = lineEndChar;
        }

		Rectf lineRect = editor.textRect(lineStart, lineEnd);
		inView = ! lineRect.x.isNaN;
		if (!inView)
			return;

		Rectf r = rect;
		r.pos = Vec2f(0,0);
		r.pos = lineRect.pos - anchorPosition(r, widgetAnchor);
		r.pos.x += lineRect.w;
		lineRect = editor.lineRect(textAnchor.number);
		rect = r;
	}
}

interface ITextAnchorDataProvider(AnchorData)
{
    import std.typecons;
    Nullable!AnchorData getAnchorData(int anchorID);
}

class TextEditorAnchorManager(AnchorData, AnchorWidget) : TextEditorAnchorOwner, ITextAnchorDataProvider!AnchorData
{
    import std.typecons;
    // AnchorData[anchorID][buffer.toHash()]
    private struct AnchorDataInternal
    {
        AnchorData data;
        alias data this;
        TextEditor editor;
    }

    AnchorData[int] _anchorData;

    TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
    {
        // TODO: support pooling.
        auto w = new AnchorWidget();
        w.anchorID = anchor.id;
        w.manager = this;
        return w;
    }

    void removeLineAnchor(TextEditor ed, int lineNumber)
    {
        ed.bufferView.buffer.removeLineAnchorByLine(lineNumber, this);
    }

    void ensureLineAnchor(TextEditor ed, int lineNumber, AnchorData data)
    {
        auto anchor = ed.bufferView.buffer.ensureLineAnchor(lineNumber, this);
        _anchorData[anchor.id] = AnchorDataInternal(data, ed);
    }

    Nullable!AnchorData getAnchorData(int anchorID)
    {
        Nullable!AnchorData res;
        if (auto d = anchorID in _anchorData)
            res = *d;
        return res;
    }
}

class ManagedTextEditorAnchor(AnchorData) : TextEditorAnchor
{
	import std.typecons;
    int anchorID;
    ITextAnchorDataProvider!AnchorData manager;

    // TextEditorAnchorManager!(AnchorData, typeof(this)) manager;

    final Nullable!AnchorData getAnchorData()
    {
        return manager.getAnchorData(anchorID);
    }

    this()
	{
	}
}


class GenericTextEditorAnchor : ManagedTextEditorAnchor!ubyte
{
 	string[] _classes;

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes;
	}

    static TextEditorAnchorManager!(ubyte, GenericTextEditorAnchor) anchorManager;
    static this()
    {
        anchorManager = new typeof(anchorManager);
    }
}
