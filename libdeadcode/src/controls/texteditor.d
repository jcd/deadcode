module controls.texteditor;

import edit.buffer;
import edit.bufferview;
import dccore.command : CommandManager;
import graphics;
import gui.event;
import gui.style;
import gui.text;
import gui.widget : Widget;
import gui.widgetfeature;
import gui.window;
//import application;
import math;

import std.conv;
import std.datetime : SysTime, Duration;
import dccore.signals;
import std.string;

alias TextRenderer!BufferView BufferViewRenderer;

import extensionapi.rpc;
mixin registerRPC;

@RPC
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

    // region set name -> decoration
    RegionSetDecoration[string] decorations;



    @property
    {
        TextStyler textStyler()
        {
            return renderer is null ? null : renderer.textStyler;
        }
        void textStyler(TextStyler s)
        {
            if (renderer !is null)
                renderer.textStyler = s;
        }
    }

    mixin Signal!() onChanged;
    mixin Signal!(MouseReleasedEvent, GlyphHit) onGlyphMouseUp;

    @property TextBuffer.CharType[] text() const
	{
            return bufferView.getText();
	}

    // Binding access
    @RPC
    @property void value(string txt)
    {
        bufferView.clear(txt);
    }

    // Binding access
    @RPC
    @property string value() const
    {
        return this.text.to!string;
    }

	// Child widget of TextEditor
	TextEditorAnchorWidget[] visibleAnchorsChildWidgets;

	private 
	{
		int _mouseStartSelectionIdx;
		SysTime _lastMouseWheelEventTimestamp;
	}

	private @property Duration timeSinceLastMouseWheel()
	{
		return Clock.currTime - _lastMouseWheelEventTimestamp;
	}

	this(BufferView buf)
	{
		acceptsKeyboardFocus = true;
		// background = "edit-background";

		// features ~= new NineGridRenderer("edit-background");
		// this.alignTo(Anchor.TopLeft, Vec2f(-1, -1), Vec2f(6,0));
		// this.alignTo(Anchor.BottomRight);
		renderer = (this.content = buf);
		bufferView = buf;
		bufferView.onChanged.connect(&this.onTextChanged);

		// bufferView.onDirty.connect(&this.onBufferViewDirty);

		bufferView.onAnchorVisibilityChanged.connect(&onAnchorVisibilityChanged);

		_mouseStartSelectionIdx = InvalidIndex;
		_lastMouseWheelEventTimestamp = SysTime.min;

		//onKeyboardFocusSignal.connect((Event ev) {
		//    //window.mouseCursor(MouseCursor.iBeam);
		//});

		//onKeyboardUnfocusSignal.connect((Event ev) {
		//    window.mouseCursor(MouseCursor.arrow);
		//});
        setRegionSetStyle("selection", "selection", true);
        setRegionSetStyle("lineHighlight");
        updateLineHighlight();
	}

    //final TextHighlighter getOrCreateHighlighter(string name)
    //{
    //    return renderer.getOrCreateHighlighter(name);
    //}
    //
    //final void removeHighlighter(string name)
    //{
    //    renderer.removeHighlighter(name);
    //}

    final RegionSet getRegionSet(string name, lazy RegionSet _default = new RegionSet())
    {
        return bufferView.getRegionSet(name, _default);
    }

    final void setRegionSetStyle(string name, string cssClassName = null, bool mergeBorders = false)
    {
        if (cssClassName is null)
            cssClassName = name;

        RegionSetDecoration* d = name in decorations;
        RegionSetDecoration rsd = null;
        if (d is null)
        {
            rsd = new RegionSetDecoration(cssClassName);
            decorations[name] = rsd;
        }
        else
        {
            rsd = *d;
            rsd.classNames.length = 0;
            rsd.classNames ~= cssClassName;
        }
        rsd.mergeBorders = mergeBorders;
    }

	override EventUsed onMouseOverEvent(MouseOverEvent e)
	{
		window.mouseCursor(MouseCursor.iBeam);
		return EventUsed.no;
	}

	override EventUsed onMouseOutEvent(MouseOutEvent e)
	{
		window.mouseCursor(MouseCursor.arrow);
		return EventUsed.no;
	}

	void toggleCursorVisibility()
	{
		renderer.toggleCursorVisibility();
	}

	override EventUsed onEvent(GUIEvent event)
	{
		if (event.type == GUIEvents.windowResized)
		{
			renderer.textDirty = true;
		} 
		else if (event.type == GUIEvents.text)
		{
			auto ev = cast(TextEvent)event;
			// KeyBindings listen on KeyDown but here we listen on Text ie. last keybinding char gets here!! :(
				bufferView.insert(ev.unicodeChar); // put text at cursor
				//std.stdio.writeln(event.ch, " ", std.conv.to!string(event.mod));
				return EventUsed.yes;
		}
		else if (event.type == GUIEvents.command)
		{
			auto ev = cast(CommandEvent)event;
			switch (ev.commandName)
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
		}

		// TODO: isn't behavior just a event -> edit mapping e.g. command
		// TODO: have several kinds of behaviours for app, window, textview.
		//       App and window should have the chance to grab events before textview
		//EditorBehavior.current.onEvent(event, bufferView);
		return super.onEvent(event);
		//return EventUsed.no;
	}

    //override void updateLayout(bool fit, Widget positionReference)
    //{
    //    // Get sized ready for the children so that any layouter have them
    //    foreach (w; children)
    //        w.size = calcSize(w);
    //
    //    layoutChildren(fit, positionReference);
    //
    //    // Position goes last so that a base position calculated by e.g. DirectionalLayout feature
    //    // can be used as relative pos for the calcPosition (ie. the styled position)
    //    foreach (w; children)
    //        w.pos = calcPosition(w);
    //    //		w.recalcPosition();
    //
    //    // Positions and sizes for children are now set and we can recurse
    //    layoutRecurse(fit, positionReference);
    //}

	override void draw()
	{
		if (!visible || w() == 0)
			return;

        updateLineHighlight();

		//renderer.selection = bufferView.selection.normalized();

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

    override void drawFeatures()
    {
		auto bg = background;
		if (bg !is null)
			bg.draw(this);

		// Draw features
		foreach (f; features)
		{
			if (f !is renderer)
                f.draw(this);
		}

        renderer.updateLayout(this);

		drawDecorations();

        renderer.draw(this);
    }

    private void drawDecorations()
    {
        // TODO: get selection regionset directly when it becomes a region set
        bufferView.getRegionSet("selection").clear(bufferView.selection.normalized());

        auto sheet = window.styleSheet;

        foreach (k, d; decorations)
        {
            auto rs = getRegionSet(k);
            if (rs !is null)
            {
                d.styleSheet = sheet;
                d.textLayout = renderer.layout;
                d.regions = rs;
                d.update(bufferView.bufferStartOffset, this.size);
            }
        }

        Mat4f transform;
		getStyledScreenToWorldTransform(transform);
		Mat4f trx = window.MVP * transform;

        string[] removeDecors;

        foreach (k, d; decorations)
        {
            d.draw(trx);
        }
    }

    override void layoutRecurse(bool fit, Widget positionReference)
    {
        foreach (w; visibleAnchorsChildWidgets)
            w.recalcPosition();
        super.layoutRecurse(fit, positionReference);
    }

	override EventUsed onMouseClickedEvent(MouseClickedEvent event)
	{
        setKeyboardFocusWidget();
		return EventUsed.yes;
	}

	override EventUsed onMouseWheelEvent(MouseWheelEvent event)
	{
		int speed = 1;
		int d = cast(int) event.scroll.y;
		int maxScrollFreq = 300;
		static maxD = 0;
		maxD = d > maxD ? d : maxD;

		auto msSinceLastMouseWheel = timeSinceLastMouseWheel.total!"msecs";
		if (msSinceLastMouseWheel < maxScrollFreq)
		{
			// Scroll view
			speed = cast(int)(d*d*(maxScrollFreq - msSinceLastMouseWheel) / 30f);
		}

		if (speed == 0)
			speed = 1;

		// std.stdio.writeln(d, " ", speed, " ", event.scroll.y, " ", event.msSinceLastScroll);
		if (d < 0)
		{
			bufferView.scrollDown(speed);
		}
		else
		{
			bufferView.scrollUp(speed);
		}

		_lastMouseWheelEventTimestamp = event.timestamp;

		return EventUsed.yes;
	}

    auto getGlyphRect(int bufferIndex)
    {
        return renderer.getGlyphRect(this, bufferIndex);
    }

    auto getGlyphRect(Vec2f pos)
    {
        return renderer.getGlyphAt(this, pos);
    }

	override EventUsed onMousePressedEvent(MousePressedEvent event)
	{
		auto info = getGlyphRect(event.position);
		if (info.isValid)
			return onGlyphMousePressedEvent(event, info);

		return EventUsed.yes;
	}

	override EventUsed onMouseDoubleClickedEvent(MouseDoubleClickedEvent event)
	{
		auto info = getGlyphRect(event.position);
		if (info.isValid)
		{
			bufferView.cursorToWordBefore();
			bufferView.selectToWordAfter();
		}

		return EventUsed.yes;
	}

	override EventUsed onMouseTripleClickedEvent(MouseTripleClickedEvent event)
	{
		auto info = getGlyphRect(event.position);
		if (info.isValid)
		{
			bufferView.cursorToBeginningOfLine();
			bufferView.selectToEndOfLine();
			bufferView.selectRight();
		}

		return EventUsed.yes;
	}

	override EventUsed onMouseMoveEvent(MouseMoveEvent event)
	{
		if (_mouseStartSelectionIdx == InvalidIndex)
			return super.onMouseMoveEvent(event);

		auto info = getGlyphRect(event.position);
		if (info.isValid)
			_updateSelectionEnd(info, event.position);

		return EventUsed.yes;
	}

	override EventUsed onMouseReleasedEvent(MouseReleasedEvent event)
	{
		auto info = getGlyphRect(event.position);
		if (info.isValid)
			return _onGlyphMouseReleasedEvent(event, info);

		_mouseStartSelectionIdx = InvalidIndex;

		return EventUsed.yes;
	}

	private EventUsed onGlyphMousePressedEvent(MousePressedEvent event, GlyphHit hit)
	{
        if (auto r = handleRegionActivation(event, hit))
            return r;

        if (event.modifiers.isShiftDown())
		{
			if (_mouseStartSelectionIdx == InvalidIndex)
			{
				if (bufferView.selection.empty)
					_mouseStartSelectionIdx = bufferView.cursorPoint;
				else
					_mouseStartSelectionIdx = bufferView.selection.a;
			}
			_updateSelectionEnd(hit, event.position);
			bufferView.setPreferredCursorColumnFromIndex();
		}
		else
		{
			_mouseStartSelectionIdx = InvalidIndex;
			_updateSelectionEnd(hit, event.position);
			bufferView.setPreferredCursorColumnFromIndex();
		}
		return EventUsed.yes;
	}

	private EventUsed _onGlyphMouseReleasedEvent(MouseReleasedEvent event, GlyphHit hit)
	{
		//_updateSelectionEnd(hit, event.mousePos);
		_mouseStartSelectionIdx = InvalidIndex;
		bufferView.setPreferredCursorColumnFromIndex();

        onGlyphMouseUp.emit(event, hit);

		return EventUsed.yes;
	}

	private EventUsed handleRegionActivation(MousePressedEvent event, GlyphHit hit)
    {
        // Check if glyph is part of a region that can be activated
        return !hit.endOfLine && hit.isValid && bufferView.handleRegionActivation(hit.index) ?
               EventUsed.no : EventUsed.no;
    }

	private void _updateSelectionEnd(GlyphHit hit, Vec2f mousePos)
	{
		int index;
		if (true || _mouseStartSelectionIdx == InvalidIndex)
		{
			// Selection start not set. Do so.
			// When picking the start glyph we want to split the hit glyph vertically and if the
			// mouse pointer is on the right side then include the glyph in the selection. If it is on the
			// left side we exclude it from the selection. This magic is only done when finding the start of the
			// selection, not when determining the end or when expanding the selection.
			auto yPosHalfWayGlyphRect = hit.rect.x + hit.rect.w * .5f;
			index = yPosHalfWayGlyphRect < mousePos.x && !hit.endOfLine ? hit.index+1 : hit.index;
			if (_mouseStartSelectionIdx == InvalidIndex)
				_mouseStartSelectionIdx = index;
		}
		else
		{
			index = hit.index;
		}

		// Region r = _mouseStartSelectionIdx < index ? Region(_mouseStartSelectionIdx, index, 0) : Region(index, _mouseStartSelectionIdx, 0);
		bufferView.selection = Region(_mouseStartSelectionIdx, index, 0);

		// bufferView.cursorPoint = index;
		renderer.cursorVisible = true;
	}

    private void updateLineHighlight()
    {
        auto ends = bufferView.buffer.lineEndsAt(bufferView.cursorPoint);
        auto last = bufferView.buffer.next(ends[1]); // bump it to after the newline in order to have a region for empty lines also.
        auto hl = getRegionSet("lineHighlight");
        //auto hl = getOrCreateHighlighter("lineHighlight");
        hl.clear();
        hl.set(ends[0], last);
    }

	// TODO: move slots to bufferView
	// Text inserted at pos and forward
	private void onTextChanged(BufferView v, int pos, int count, bool insertOrRemove)
	{
		//Region r = bufferView.selection;
		//r.entriesInserted(pos, text.length);
		//bufferView.selection = r;
        onChanged.emit();
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
	private TextEditorAnchorWidget ensureAnchorWidget(TextBufferAnchor anchor)
	{
		string candidateName = anchor.id.to!string ~ "-textBufferAnchor";
		foreach (c; children)
		{
			if (c.name == candidateName)
				return cast(TextEditorAnchorWidget) c;
		}

		if (anchor.owner !is null)
		{
			ITextEditorAnchorOwner anchorOwner = cast(ITextEditorAnchorOwner) anchor.owner;
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

	auto setLineAnchor(int lineNumber, ITextBufferAnchorOwner owner)
	{
		return bufferView.buffer.ensureLineAnchor(lineNumber, owner);
	}

	void unsetLineAnchor(int lineNumber, string type)
	{
		auto anchor = bufferView.buffer.getLineAnchor(lineNumber);
		if (anchor.id == InvalidAnchorID)
			return; // no anchor
		bufferView.buffer.removeLineAnchorByLine(anchor.id); // TODO: optimize
	}

	void unsetAnchorById(int anchorID)
	{
		bufferView.buffer.removeLineAnchorByID(anchorID);
	}

    GenericTextEditorAnchorWidget setLineAnchor(int lineNumber, string cssClassName)
    {
        // TODO: fix coupling on children length and ensureLineAnchor
		auto origLen = children.length;
        auto a = bufferView.buffer.ensureLineAnchor(lineNumber, getManager!GenericTextEditorAnchorManager());
        GenericTextEditorAnchorWidget res = null;
        if (origLen != children.length)
        {
            res = cast(GenericTextEditorAnchorWidget)(children[$-1]);
            res._classes = [ cssClassName ];
        }
        return res;
    }

/*
    void unsetLineAnchors(string cssClassName)
    {
		foreach (a; bufferView.buffer.getLineAnchors(GenericTextEditorAnchor.anchorManager))
        {
            if (a.classes[0] == cssClassname)
				bufferView.buffer.removeLineAnchorByID(a.id);
        }
    }
*/
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


//class TextEditorAnchorWidgetFactory
//{
//    TextEditorAnchorWidget createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
//    {
//        // TODO: support pooling.
//        auto w = new DataAnchorWidget();
//        w.anchorID = anchor.id;
//        // w.manager = this;
//        w.onMouseClickCallback((Event e, Widget wi) {
//            onAnchorClicked.emit(e, w, editor, getAnchorData(anchor.id));
//            return EventUsed.yes;
//        });
//        return w;
//    }
//}

//editor.setLineAnchor!EOLAnchor(32);
//editor.clearLineAnchor!EOLAnchor(32);
//
//auto setLineAnchor(AnchorWidget : TextEditorAnchorWidget)(TextEditor editor, int lineNumber)
//{
//    enum wid = typeid(AnchorWidget).stringof;
//    auto w = wid in editor._anchorManagers;
//    TextEditorAnchorWidgetManager!AnchorWidget mgr = null;
//    if (w is null)
//    {
//        // First of its kind
//        mgr = new TextEditorAnchorWidgetFactory!AnchorWidget;
//        editor._anchorManagers[wid] = new TextEditorAnchorWidgetManager!AnchorWidget(editor);
//    }
//    else
//    {
//        mgr = *w;
//    }
//    return editor.bufferView.buffer.ensureLineAnchor(lineNumber, mgr);
//}

//bool clearLineAnchor(AnchorWidget : TextEditorAnchorWidget)(TextEditor editor, int lineNumber)
//{
//    enum wid = typeid(AnchorWidget).stringof;
//    auto w = wid in editor._anchorManagers;
//    if (w !is null)
//        editor.bufferView.buffer.removeLineAnchorByLine(lineNumber, *w);
//}
//
//bool clearLineAnchor(T)(TextEditor editor, int lineNumber)
//{
//    foreach (k, v; editor._anchorManagers)
//        editor.bufferView.buffer.removeLineAnchorByLine(lineNumber, v);
//}

import gui.layout.constraintlayout;

class TextEditorAnchorWidget : Widget
{
    int anchorID;
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
		if (visible && inView && w() > 0)
			super.draw();
	}

	protected void recalcPosition()
	{
		if (visible)
			recalculateRect();
	}

	void recalculateRect()
	{
        import std.math : isNaN;
		TextEditor editor = cast(TextEditor) parent;

		TextBuffer buffer = editor.bufferView.buffer;
		auto lineIdx = textAnchor.number;
		auto lineStart = buffer.startAtLineNumber(lineIdx);
		auto lineEnd = buffer.endAtLineNumber(lineIdx);

        if (lineEnd != lineStart)
        {
            auto lineEndChar = buffer.findOneNotOfReverse(lineEnd, " \t\r\n");
		    if (lineEndChar != InvalidIndex)
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

        //lineRect = editor.lineRect(textAnchor.number);
		rect = r;

        updateLayout(false, this);
	}
}

interface ITextAnchorDataProvider(AnchorData)
{
    import std.typecons;
    Nullable!AnchorData getAnchorData(int anchorID);
}

interface ITextEditorAnchorOwner : ITextBufferAnchorOwner
{
	TextEditorAnchorWidget createAnchorWidget(TextBufferAnchor anchor, TextEditor editor);
}

class TextEditorDataAnchorWidget(AnchorDat) : TextEditorAnchorWidget
{
    alias AnchorData = AnchorDat;
    private AnchorData _anchorData;
    //alias Manager = TextEditorDataAnchorManager!(typeof(this));
    //Manager manager;

    @property
    {
        AnchorData anchorData() { return _anchorData; }
        void anchorData(AnchorData d) { _anchorData = d; }
    }

    protected string[] _classes;

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes;
	}
}

class TextEditorDataAnchorManager(DataAnchorWidget) : ITextEditorAnchorOwner, ITextAnchorDataProvider!(DataAnchorWidget.AnchorData)
{
    import std.typecons;
    alias AnchorData = DataAnchorWidget.AnchorData;
    // AnchorData[anchorID][buffer.toHash()]
    private struct AnchorDataInternal
    {
        AnchorData data;
        alias data this;
        TextEditor editor;
    }

    AnchorDataInternal[int] _anchorData;

    mixin Signal!(Event, DataAnchorWidget, TextEditor, Nullable!AnchorData) onAnchorClicked;

	auto getAnchorIDs(TextEditor ed)
    {
		int[] ids;
        foreach (k, v; _anchorData)
        {
            if (v.editor is ed)
            ids ~= k;
        }
        return ids;
    }

    TextEditorAnchorWidget createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
    {
        // TODO: support pooling.
        auto w = new DataAnchorWidget();
        w.anchorID = anchor.id;
        // w.manager = this;
        w.onMouseClickCallback((Event e, Widget wi) {
            onAnchorClicked.emit(e, w, editor, getAnchorData(anchor.id));
            return EventUsed.yes;
        });
        return w;
    }

    void removeLineAnchor(int lineNumber, TextEditor ed)
    {
        ed.bufferView.buffer.removeLineAnchorByLine(lineNumber, this);
    }

    // In case editor is null it will be automatically looked up. You can get rid of a loopup
    // by providing it.
    void removeLineAnchorByID(int anchorID, TextEditor ed = null)
    {
        if (ed is null)
        {
            auto a = anchorID in _anchorData;
            if (a is null)
                return; // Unknown anchorID
            ed = a.editor;
        }
        ed.bufferView.buffer.removeLineAnchorByID(anchorID);
    }

    void removeLineAnchors(TextEditor ed)
    {
        foreach (k, v; _anchorData)
            if (ed is v.editor)
                ed.bufferView.buffer.removeLineAnchorByID(k);
    }

    auto ensureLineAnchor(TextEditor ed, int lineNumber, AnchorData data)
    {
        auto anchor = ed.bufferView.buffer.ensureLineAnchor(lineNumber, this);
        _anchorData[anchor.id] = AnchorDataInternal(data, ed);
	    return anchor;
    }

    Nullable!AnchorData getAnchorData(int anchorID)
    {
        Nullable!AnchorData res;
        if (auto d = anchorID in _anchorData)
            res = *d;
        return res;
    }
}

template Manager(T, Args...)
{
    T getManager(S : T)()
    {
        static T _singleton;
        if (_singleton is null)
            _singleton = new T(Args);
        return _singleton;
    }
}

//template Singleton(T)
//{
//    enum TN = T.stringof;
//    mixin("private " ~ TN ~ " _instance" ~ TN ~ " = null;" ~
//          TN ~ " get()
//          {
//          if (_instance" ~ TN ~ " is null)
//          _instance" ~ TN ~ " = new " ~ TN ~ ";
//          return _instance;
//          }
//          ");
//}

alias BasicTextEditorDataAnchorManager(AnchorData) = TextEditorDataAnchorManager!(TextEditorDataAnchorWidget!AnchorData);


//class ManagedTextEditorAnchor(AnchorData) : TextEditorAnchor
//{
//    import std.typecons;
//    int anchorID;
//    ITextAnchorDataProvider!AnchorData manager;
//
//    // TextEditorAnchorManager!(AnchorData, typeof(this)) manager;
//
//    final Nullable!AnchorData getAnchorData()
//    {
//        return manager.getAnchorData(anchorID);
//    }
//
//    this()
//    {
//    }
//}

//class GenericTextEditorAnchor(AnchorData = ubyte) : ManagedTextEditorAnchor!AnchorData
//{
//    string[] _classes;
//    private static TextEditorAnchorManager!(AnchorData, GenericTextEditorAnchor) _mgr;
//
//    override protected @property const(string[]) classes() const pure nothrow @safe
//    {
//        return _classes;
//    }
//
//    @property
//    static TextEditorAnchorManager!(AnchorData, GenericTextEditorAnchor) anchorManager()
//    {
//        if (_mgr is null)
//            _mgr = new TextEditorAnchorManager!(AnchorData, GenericTextEditorAnchor);
//        return _mgr;
//    }
//    //    static this()
//    //{
//    //    anchorManager = new typeof(anchorManager);
//    //}
//}

//class GenericTextEditorAnchor : TextEditorDataAnchorWidget!Object
//{
//    this()
//    {
//        _classes ~= cssClassName;
//    }
//}

alias GenericTextEditorAnchorWidget = TextEditorDataAnchorWidget!Object;

class GenericTextEditorAnchorManager : TextEditorDataAnchorManager!GenericTextEditorAnchorWidget
{
    string[] cssClasses;
    this(string[] cssClasses)
    {
        this.cssClasses = cssClasses;
    }

    override TextEditorAnchorWidget createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
    {
        auto w = cast(GenericTextEditorAnchorWidget) super.createAnchorWidget(anchor, editor);
        w._classes ~= cssClasses;
        return w;
    }
}

mixin Manager!(GenericTextEditorAnchorManager, ["generic"]);
