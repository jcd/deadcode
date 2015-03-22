module core.bufferview;

import core.buffer; // : TextBuffer;
import core.bufferviewaction;
import core.copybuffer;
import core.language;
import math.region;
import std.container;
import std.conv;
import std.exception;
import std.range;
import core.signals;
import std.stdio;
import std.variant;

debug import std.string;

version(unittest) import test;

enum RegionQuery
{
	none,
	selection,
	selectionOrWord,
	selectionOrLine,
	selectionOrBuffer,
	word,
	line,
	buffer,
}

class RegionView
{
	string name;
    BufferView bufferView;
	Region region;
	alias toString this;

	@property
	{
		int length() const pure nothrow @safe
		{
                    return cast(int)region.length;
		}

		bool empty() const pure nothrow @safe
		{
			return region.empty;
		}
	}

	private this(string name, BufferView bv, Region r)
	{
		this.name = name;
        bufferView = bv;
		region = r;
		bufferView.onInsert.connect(&this.textInserted);
		bufferView.onRemove.connect(&this.textRemoved);
	}

    bool detach()
    {
        if (bufferView is null)
            return false;
        return bufferView.removeRegionView(name); // TODO: It should really remove not only by name but by specific instance
    }

    //dstring toString() const
    //{
    //    return bufferView.getText(region);
    //}

	private void textInserted(BufferView v, BufferView.BufferString text, int pos)
	{
            region.entriesInserted(pos, cast(int)text.length);
	}

	private void textRemoved(BufferView v, BufferView.BufferString text, int pos)
	{
            region.entriesRemoved(pos, cast(int)text.length);
	}
    /*

	RegionView opAssign(dstring s)
	{
		bufferView.replace(s, region);
		return this;
	}

	RegionView opAssign(string s)
	{
		bufferView.replace(dtext(s), region);
		return this;
	}

	RegionView opSlice(Region r)
	{
		assert(r.a >= 0 && r.a <= region.a);
		assert(r.b >= 0 && r.b <= region.b);
		return RegionView(this, r);
	}

	RegionView opSlice(int a, int b)
	{
		return opSlice(Region(a,b));
	}

	// Replace this RegionView content with the contents of v
	void doPut(RegionView v)
	{
		bufferView.replace(v.toString(), region);
	}

	void doPut(string v)
	{
		bufferView.replace(dtext(v), region);
	}

	void doPut(dstring v)
	{
		bufferView.replace(v, region);
	}

	void doPut(dchar v)
	{
		bufferView.replace(dtext(v), region);
	}

	void doPut(char v)
	{
		bufferView.replace(dtext(v), region);
	}
    */
}


// TODO:
//  * Cannot page down until out after buffer length. Think buffer.startOfLine/endOfLine are guilty

/** A BufferView is used as a view to he contents of a buffer.
 * A BufferView is non GUI related but only used for representing and controlling a buffer.
 * Several BufferViews may display the same buffer.
 * The selection, cursor position etc. is distinct for each BufferView.
 * Changes to the buffer is usually done through a view.
 * To render a specific BufferView on screen use a TextRenderer.
 */
class BufferView
{
	private int _id;
	string name;
	TextBuffer buffer;     // This should be changeable to something else if wanted
	// private GapBuffer!int lineStarts; // Indexes into buffer for all line starts. Purely a optimization.

	package
    {
        CopyBuffer copyBuffer;
    }

	private
	{
		int _preferredCursorColumn;
		int _lineOffset;   // line offset into the buffer from where to draw.
		int _bufferStartOffset; // Cached value of index of first char on line specified by lineOffset
		int _visibleLineCount;    // Number of lines to visible in view
		bool _modified;
		ActionTree _undoStack; // TODO: rename field to match type
	}

	bool autoCursorInView = true;

	private Region _selection;

    private RegionView[string] _regionViews;

	// RegionSet selections;

	alias immutable(TextBuffer.CharType)[] BufferString;
	alias TextBuffer.CharType CharType;

	ICodeModel codeModel;
	Variant[string] userData;

	TextBufferAnchor[] visibleAnchors;

	//
	private bool _dirty;

	// TODO: hese signals should really be forwarde from the underlaying buffer in order to
	// get signal when other bufferviews alters the underlaying buffer!
	// emit(this, text, insertedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, int) onInsert;

	// emit(this, text, removedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, int) onRemove;

	// emit(this, text, copiedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, int) onCopy;

	// When something happened that would change the bufferView appearance e.g. text changes or achors changed/set.
	// emit(this);
	mixin Signal!(BufferView) onDirty;

	// When the text changed since last load/save. The isModified flag can be false in case of undoing all changes
	// since last save/load.
	// emit(this, isModified);
	mixin Signal!(BufferView, bool) bufferModified;

	// emit(this, TextBufferAnchor[])
	mixin Signal!(BufferView, TextBufferAnchor[]) onAnchorVisibilityChanged;

	@property
	{
        int id() const pure nothrow @safe
        {
            return _id;
        }

        int bufferID() const pure nothrow @safe
        {
            return buffer.id;
        }

        string fileName() const pure nothrow @safe
        {
            if (isPersistant)
                return name;
            return null;
        }

		bool isPersistant() const pure nothrow @safe
		{
			return buffer.isPersistant;
		}

		void isPersistant(bool p) pure nothrow @safe
		{
			buffer.isPersistant = p;
		}

		void selection(Region r)
		{
			if (_selection == r)
				return;

			if (r.a != _selection.a)
                cursorPoint = r.a; // will also put this action on undo stack

			bool selecting = !r.empty;
            _undoStack.push!CursorAction(this, TextBoundary.unit, r.b - _selection.b, selecting);
		}

		const(Region) selection() const pure nothrow
		{
			return _selection;
		}
		void dirty(bool d)
		{
			if (d)
			{
				signalVisibleAnchors();
				onDirty.emit(this);
			}
			_dirty = d;
		}

		bool dirty() const pure nothrow
		{
			return _dirty;
		}
	}

    RegionView getOrCreateRegionView(string name, Region r = Region(0,0))
    {
        if (auto rv = name in _regionViews)
            return *rv;

        auto res = new RegionView(name, this, r);
        _regionViews[name] = res;
        return res;
    }

    bool removeRegionView(string name)
    {
        if (auto v = name in _regionViews)
            v.bufferView = null;
        return _regionViews.remove(name);
    }

    void pushSelection()
    {
        _undoStack.push!SelectionStackAction(this, true);
    }

    package void _pushSelection()
    {
        foreach (i; 0..10)
        {
            string name = text("_selectStack_", i);
            if (name in _regionViews)
            {
            }
            else
            {
                auto v = getOrCreateRegionView(name, selection);
                return;
            }

        }
        assert(0, "Selection stack overflow"); // TODO: proper error instead
    }

    void popSelection()
    {
        _undoStack.push!SelectionStackAction(this, false);
    }

    package void _popSelection()
    {
        foreach (i; 0..10)
        {
            string name = text("_selectStack_", 9 - i);
            if (auto rv = name in _regionViews)
            {
                setSelectRegion(rv.region);
                removeRegionView(name);
                return;
            }
        }
        assert(0, "Selection stack underflow"); // TODO: proper error instead
    }

	void clearSelection()
	{
		if (_selection.empty)
			return;
		_selection.clear();
		dirty = true;
	}

	package void navigated()
	{
		dirty = true;
		auto lastLine = lineOffset + visibleLineCount - 1;

		// Make sure the cursor in inside the visible area by changing the lineOffset
		if (autoCursorInView && (lineNumber < lineOffset || lineNumber > lastLine))
		{
			// Cursor outside of current view
			viewOnLine(lineNumber);
		}
	}

    /** Scroll view so that line is in view

        Behaves line viewOnLinePaged() except when scrolling is needed only the minimum scroll is performed to
        get the line into view.
    */
	void viewOnLine(int line)
	{
		auto lastLine = lineOffset + visibleLineCount - 1;
		if (line < lineOffset)
			lineOffset = line;
		else if (line > lastLine)
			lineOffset = line - visibleLineCount + 1;
	}

	bool isLineInView(int line)
	{
		return line >= lineOffset && line < lineOffset + visibleLineCount;
	}

	void scrollToLineInView(int line)
	{
		if (line < lineOffset)
			lineOffset = line;
		else if (line >= lineOffset + visibleLineCount)
			lineOffset = line - visibleLineCount + 1;
	}

	void centerOnLine(int line, bool onlyWhenNotInView = false)
	{
		auto endLine = lineOffset + visibleLineCount;

		if (onlyWhenNotInView && lineOffset <= line && line < endLine)
        {
            return;
        }

        auto offset = visibleLineCount / 2;
		if (offset > line)
			lineOffset = 0;
		else
			lineOffset = line - offset;
	}

	void centerOnChar(int index, bool onlyWhenNotInView = false)
    {
        int line = buffer.lineNumberAt(index);
        centerOnLine(line, onlyWhenNotInView);
    }

    /** Scroll view so that line is in view

        Behaves line viewOnLine() except when scrolling is needed the line will be centered in view.
    */
    void viewOnLinePaged(int line)
    {
        if (!isLineInView(line))
            centerOnLine(line);
    }

    void viewOnCharPaged(int index)
    {
        int line = buffer.lineNumberAt(index);
        viewOnLinePaged(line);
    }


	@property bool modified() const pure nothrow @safe
	{
		return _modified;
	}

	package @property void modified(bool v)
	{
		dirty = true;
		if (modified != v)
		{
			_modified = v;
			bufferModified.emit(this, v);
		}
	}

	auto opSlice(size_t from, size_t to) const
	{
        import std.string;
        assert((to >= 0 && to <= length) || (from >= 0 && from <= length), format("Slice overflow %s: 0 <= %s .. %s <= %s", name, from, to, length));
		return buffer.opSlice(from, to);
	}

/*
	RegionView opSlice(Region r)
	{
		assert(r.a >= 0 && r.a <= region.a);
		assert(r.b >= 0 && r.b <= region.b);
		return RegionView(this, r);
	}
*/
	auto opIndex(size_t i) const
	{
		return buffer[i];
	}

	/*
	RegionView opIndex(RegionQuery q) const
	{
		auto r = getRegion(q);
		return new RegionView(this, q);
	}
*/
	void ensureCapacity(size_t s)
	{
		if (s <= buffer.length)
			return;
		buffer.gbuffer.ensureGapCapacity(cast(int)(s - buffer.length));
	}

	debug void enableUndoStackDumps() { _undoStack.dumpEnabled = true; }

	package this(string txt)
	{
		import std.conv;
		this(new TextBuffer(to!dstring(txt), 10));
	}

	package this(TextBuffer buffer)
	{
		this.buffer = buffer;
		_dirty = true;
		_modified = false;
		//selections = new RegionSet(true); // should be false
		_undoStack = new ActionTree;
		// copyBuffer = new CopyBuffer;
		buffer.onAnchorAdded.connect(&onAnchorAdded);
		buffer.onAnchorRemoved.connect(&onAnchorRemoved);
	}

	@property
	{
		int lineNumber() const
		{
			return buffer.lineNumberAt(cursorPoint);
		}

		int lineNumberRelativeToView() const
		{
			return lineNumber - lineOffset;
		}

		void lineNumberRelativeToView(int offset)
		{
			int curRel = lineNumberRelativeToView;
			if (offset < curRel)
				cursorUp(curRel - offset);
			else
				cursorDown(offset - curRel);
		}

		// TODO: keep up to date
		//ref int lineOffset()
		//{
		//    return _lineOffset;
		//}

		int bufferStartOffset() const pure nothrow
		{
			return _bufferStartOffset;
		}

		int bufferEndOffset() const
		{
			return buffer.endAtLineNumber(lineNumber + visibleLineCount);
		}

		int lineOffset() const pure nothrow
		{
			return _lineOffset;
		}

		// TODO: optimize
		void lineOffset(int o)
		{
			if (_lineOffset == o || o >= (buffer.lineCount - 1))
				return;

			_lineOffset = o;
			_bufferStartOffset = buffer.startAtLineNumber(o);
			dirty = true;
		}

		//int lineOffsetKeepCursorLine() const pure nothrow
		//{
		//    return _lineOffset;
		//}

		//void lineOffsetKeepCursorLine(int o)
		//{
		//    int old = lineOffset;
		//    lineOffset = o;
		//    cursorDown(old < lineOffset ? lineOffset - old : old - lineOffset);
		//}

		// TODO: keep up to date and rename maybe
		int visibleLineCount() const pure nothrow
		{
			return _visibleLineCount;
		}

		void visibleLineCount(int c)
		{
			if (_visibleLineCount != c)
			{
				_visibleLineCount = c;
				dirty = true;
			}
		}

		int length() const nothrow
		{
                    return cast(int)buffer.length;
		}

		const(TextBuffer.CharType)[] lastLine() const
		{
			return buffer.lastLine;
		}

		TextBuffer.CharType[] selectedText() const
		{
			auto sel = selection.normalized();
			return buffer.toArray(sel.a, sel.b);
		}
	}

	Region getRegion(RegionQuery query)
	{
		final switch (query)
		{
		case RegionQuery.none:
			return Region(cursorPoint, cursorPoint);
		case RegionQuery.selection:
			return selection;
		case RegionQuery.selectionOrWord:
			if (selection.empty)
				goto case RegionQuery.word;
			return selection;
		case RegionQuery.selectionOrLine:
			if (selection.empty)
				goto case RegionQuery.line;
			return selection;
		case RegionQuery.selectionOrBuffer:
			if (selection.empty)
				goto case RegionQuery.buffer;
			return selection;
		case RegionQuery.word:
			auto a = buffer.offsetToBeginningOfWord(cursorPoint);
			auto b = buffer.offsetToEndOfWord(cursorPoint);
			if (a == InvalidIndex || b == InvalidIndex)
				return Region(cursorPoint, cursorPoint);
			else
				return Region(a, b);
		case RegionQuery.line:
			auto ends = buffer.lineEndsAt(cursorPoint);
			return Region(ends[0], ends[1]);
		case RegionQuery.buffer:
                    return Region(0, cast(int)buffer.length);
		}
	}

	TextBuffer.CharType[] getText(int begin = 0, int end = int.max) const
	{
		return buffer.toArray(begin, end);
	}

	TextBuffer.CharType[] getText(Region r) const
	{
		auto rn = r.normalized();
		return buffer.toArray(rn.a, rn.b);
	}

    TextBuffer.CharType[] getLineAtCursor() const
    {
        auto ends = buffer.lineEndsAt(selection.b);
        return getText(ends[0], ends[1]);
    }

    TextBuffer.CharType[] getLineAtSelection() const
    {
        auto ends = buffer.lineEndsAt(selection.a);
        return getText(ends[0], ends[1]);
    }

	bool isCursorFollowing(string s) const
    {
        if (cursorPoint >= s.length)
            return getText(cast(int)(cursorPoint - s.length), cursorPoint) == s.to!dstring;
        return false;
    }

	void replace(dstring txt, Region r)
	{
		int restoreCursorPoint = cursorPoint;
		int begin = r.a;
		int end = r.b;

		//Region oldSelection = selection;
		//oldSelection.entriesRemoved(begin, (end == int.max ? buffer.length : end) - begin);
		//oldSelection.entriesInserted(begin, txt.length);

		// cursorPoint = r.a;

		//writeln("replaceA");
		auto offsetToStart = r.a - cursorPoint;
		_undoStack.push!ActionGroupAction(this,
										  new CursorAction(TextBoundary.unit, offsetToStart),
                                                  new RemoveAction(TextBoundary.unit, cast(int)r.length),
										  new InsertAction(txt));

		if (restoreCursorPoint <= begin)
			cursorPoint = restoreCursorPoint;
		else if (Region(begin, end).contains(restoreCursorPoint))
                    cursorPoint = begin + cast(int)txt.length;
		else
                    cursorPoint = cast(int)(restoreCursorPoint - ((end == int.max ? buffer.length : end) - begin - txt.length));
		// selection = oldSelection;
	}

	void map(alias Func, Rs...)(Rs r) if (Rs.length > 0 && is(Rs[0] : Region))
	{
		replace(cast(immutable)Func(getText(r)), r);
	}

	void map(alias Func)(RegionQuery query)
	{
		this.map!Func(getRegion(query));
	}

	Region wordAtCursor() const
	{
        //auto startOfWord = buffer.offsetToWordBoundary(cursorPoint, true);
        //auto endOfWord = buffer.offsetToWordBoundary(cursorPoint, false);
		auto startOfWord = buffer.offsetByBoundary(cursorPoint, -1, TextBoundary.wordBegin, TextBoundaryStrength.hard);
		auto endOfWord = buffer.offsetByBoundary(cursorPoint, 1, TextBoundary.wordEnd, TextBoundaryStrength.hard);
		if (startOfWord == InvalidIndex || endOfWord == InvalidIndex)
			return Region(cursorPoint, cursorPoint);
		else
			return Region(startOfWord, endOfWord);
	}

	//void replace(dstring txt, Region r)
	//{
	//    replace(txt, r.a, r.b);
	//}

	int lineCount() const
	{
            return buffer.lineNumberAt(buffer.length == 0 ? 0 : cast(int)buffer.length - 1);
	}

	// Note that using this may mess with the modified state reset in undo()!
	// Use with care.
	void clearUndoStack()
	{
		_undoStack.clear();
	}

	void undo()
	{
		if (_undoStack.canUndo())
			_undoStack.undo(this);

		if (modified && _undoStack.empty)
			modified = false;
	}

	void redo()
	{
		if (_undoStack.canRedo())
			_undoStack.redo(this);
	}

	void copy()
	{
		_undoStack.push!CopySelectedAction(this);
	}

	void paste(int copyBufferEntryOffset = 0)
	{
		_undoStack.push!PasteAction(this, copyBufferEntryOffset);
	}

	void pasteCycle()
	{
		_undoStack.push!PasteAction(this, -1);
	}

	void cut()
	{
		_undoStack.push!ActionGroupAction(this,
										  new CopySelectedAction(),
										  new RemoveAction(TextBoundary.unit, 0)); // remove 0 to remove selection
	}

	void clear(string dl)
	{
	    clear(dl.to!BufferString);
    }

    void clear(immutable(TextBuffer.CharType)[] dl)
	{
		_undoStack.push!ActionGroupAction(this,
											new CursorAction(TextBoundary.buffer, -1),
											new RemoveAction(TextBoundary.buffer, 1),
											new InsertAction(dl));
	}

	void write(File file)
	{
		// TODO: use iomanager and IOs for writing
		file.rawWrite(std.conv.text(buffer.beforeGap));
		file.rawWrite(std.conv.text(buffer.afterGap));
		isPersistant = true;
	}

	void cursorToStart()
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.buffer, -1, false);
		navigated();
	}

	void cursorToEnd()
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.buffer, 1, false);
		navigated();
	}

	void cursorToLine(int l)
	{
		clearSelection();
		int origLineNumber = lineNumber;
		int origLineOffset = lineOffset;

		int lineCursorOffset = l - origLineNumber;
		_undoStack.push!CursorDownAction(this, lineCursorOffset);

		// In case we jump out of view from last active line number
		// we center the line
		bool inOldView = l >= origLineOffset && l < origLineOffset + visibleLineCount;
		if (!inOldView)
			centerOnLine(l);
	}

	@property int cursorPoint() const pure nothrow
	{
		return _selection.b;
	}

	@property void cursorPoint(int v)
	{
		if (!isValidCursorPoint(v))
		{
			v = v;
		}

		assert(isValidCursorPoint(v), "Cursor out of range");
		if (cursorPoint == v)
			return;

		_undoStack.push!CursorAction(this, TextBoundary.unit, v - _selection.b, false);

        assert(_selection.empty);
        assert(_selection.b == v, text(selection.b, " ", v));

		navigated();
	}

	bool isValidCursorPoint(int v)
	{
		return buffer !is null && v >= 0 && v <= buffer.length;
	}

    TextBoundary classify(int idx = int.min)
    {
        return buffer.classify(idx == int.min ? cursorPoint : idx);
    }

    int findByClass(bool forward, TextBoundary bound, int index = int.min)
    {
        return buffer.findByClass(index == int.min ? cursorPoint : index, forward, bound, false);
    }

    Region expandByClass(TextBoundary bound, int index = int.min)
    {
        int idx = index == int.min ? cursorPoint : index;
        int a = buffer.findByClass(idx, false, bound, false);
        int b = buffer.findByClass(idx, true, bound, false);
        return Region(a == InvalidIndex ? idx : a,
                      b == InvalidIndex ? idx : b);
    }

    Region expandByClass(TextBoundary bound, Region r)
    {
        bool swap = r.a > r.b;

        int a = buffer.findByClass(swap ? r.b : r.a, false, bound, false);
        int b = buffer.findByClass(swap ? r.a : r.b, true, bound, false);

        if (swap)
        {
            int tmp = a;
            a = b;
            b = tmp;
        }
        return Region(a == InvalidIndex ? r.a : a, b == InvalidIndex ? r.b : b);
    }

    // TODO: support flags
    auto find(const(char)[] regex, const(char)[] flags, int index = int.min)
    {
        return buffer.findRegex(index == int.min ? cursorPoint : index, regex, flags);
    }

    auto find(string regex, int index = int.min)
    {
        return find(regex, "", index);
    }

    @property int preferredCursorColumn() const pure nothrow
	{
		return _preferredCursorColumn;
	}

	@property void preferredCursorColumn(int col)
	{
		if (_preferredCursorColumn == col)
			return;
		_preferredCursorColumn  = col;
		navigated();
	}

	void setPreferredCursorColumnFromIndex(int index = InvalidIndex)
	{
		if (index == InvalidIndex)
			index = cursorPoint;

		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		int startOfLine = buffer.offsetToBeginningOfLine(index);
		auto old = _preferredCursorColumn;
		_preferredCursorColumn = index - startOfLine;
		if (old != _preferredCursorColumn)
			navigated();
	}

	void setIndexFromPreferredCursorColumn(int col = InvalidIndex)
	{
		if (col == InvalidIndex)
			col = _preferredCursorColumn;

		auto old = cursorPoint;

		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		int startOfLine = buffer.offsetToBeginningOfLine(cursorPoint);
		int endOfLine = buffer.offsetToEndOfLine(cursorPoint);
		int diff = endOfLine - startOfLine;
		if (diff > col)
			cursorPoint = startOfLine + col;
		else
			cursorPoint = endOfLine;

		if (old == cursorPoint)
			navigated();
	}



	void insert(dchar item)
	{
		dchar[1] buf;
		buf[0] = item;
		insert(buf.idup);
	}

	void insert(dstring txt)
	{
		_undoStack.push!InsertAction(this, txt);
	}

	void insert(char item)
	{
		dchar[1] buf;
		buf[0] = item;
		insert(buf.idup);
	}

	void insert(const(char)[] txt)
	{
		insert(dtext(txt));
	}

    void storeState()
    {
		_undoStack.push!StoreState(this);
    }

	//void insert(string txt)
	//{
	//    insert(txt.to!dstring);
	//}

	void append(dstring items)
	{
		cursorToEnd();
		insert(items);
	}

	void append(const(char)[] items)
	{
		cursorToEnd();
		insert(items);
	}

	void remove(int count)
	{
		//writeln("removeA");
		_undoStack.push!RemoveAction(this, TextBoundary.chr, count);
	}

    void beginUndoGroup()
    {
        _undoStack.beginGroup();
    }

    void endUndoGroup()
    {
        _undoStack.endGroup(this);
    }

	void clear()
	{
		_undoStack.push!ActionGroupAction(this,
										  new CursorAction(TextBoundary.buffer, -1),
										  new RemoveAction(TextBoundary.buffer, 1));
	}

	void cursorLeft(int c = 1)
	{
		_undoStack.push!CursorAction(this, TextBoundary.chr, -c, false);
	}

	void cursorRight(int c = 1)
	{
		_undoStack.push!CursorAction(this, TextBoundary.chr, c, false);
	}

	// Move cursor up and scroll when hitting top of view so that cursor sticks to the op
	void cursorUp(int c = 1)
	{
		_undoStack.push!CursorDownAction(this, -c);
	}

	// Move cursor down and scroll when hitting bottom of view so that cursor sticks to the bottom
	void cursorDown(int c = 1)
	{
		_undoStack.push!CursorDownAction(this, c);
	}

	void selectLeft(int c = 1)
	{
		_undoStack.push!CursorAction(this, TextBoundary.chr, -c, true);
	}

	void selectRight(int c = 1)
	{
		_undoStack.push!CursorAction(this, TextBoundary.chr, c, true);
	}

	void selectUp(int c = 1)
	{
		_undoStack.push!CursorDownAction(this, -c, true);
	}

	void selectDown(int c = 1)
	{
		_undoStack.push!CursorDownAction(this, c, true);
	}

	// Should only be called from an Action (see bufferviewaction.d)
	package void selectTo(int c)
	{
		_selection.b = c;
        //if (_selection.empty)
        //    selectionStartIndex = cursorPoint;
        //
        //import std.algorithm;
        //
        //if (selectionStartIndex < c)
        //    _selection = Region(selectionStartIndex, min(c, buffer.length));
        //else
        //    _selection = Region(max(c,0), selectionStartIndex);
	}

	// Should only be called from an Action (see bufferviewaction.d)
    // Just using "selection = Region(a,b)" does not work since assigning that
    // property will itself create a new action.
	package void setSelectRegion(Region r)
	{
		_selection = r;
		//selectionStartIndex = r.a;
        //cursorPoint = r.b;
	}

	package void setSelectRegion(int cursor)
    {
        _selection.a = cursor;
        _selection.b = cursor;
    }


	void scrollUp()
	{
		lineOffset = lineOffset - 1;
	}

	void scrollDown()
	{
		lineOffset = lineOffset + 1;
	}

	void cursorToBeginningOfLine()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineBegin, -1, false, TextBoundaryStrength.hard);
	}

	void cursorToEndOfLine()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineEnd, 1, false, TextBoundaryStrength.hard);
	}

	void cursorToLineBefore()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineBegin, -1, false);
	}

	void cursorToLineAfter()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineEnd, 1, false);
	}

	void selectToBeginningOfLine()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineEnd, -1, true);
	}

	void selectToEndOfLine()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineEnd, 1, true);
	}

	void cursorToBeginningOfWord()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordBegin, -1, false);
	}

	void cursorToEndOfWord()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd, 1, false);
	}

	void cursorToWordBefore()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordBegin | TextBoundary.punctuationBegin | TextBoundary.lineBegin, -1, false);
	}

	void selectToWordBefore()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordBegin | TextBoundary.punctuationBegin | TextBoundary.lineBegin, -1, true);
	}

	void selectToBeginningOfWord()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd, -1, true);
	}

	void selectToEndOfWord()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd, 1, true);
	}

	void deleteToWordBefore()
	{
		//writeln("dtwb");
		_undoStack.push!RemoveAction(this, TextBoundary.wordBegin | TextBoundary.punctuationBegin | TextBoundary.lineBegin, -1);
	}

	void cursorToWordAfter()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd | TextBoundary.punctuationEnd |TextBoundary.lineEnd, 1, false);
	}

	void selectToWordAfter()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd | TextBoundary.punctuationEnd | TextBoundary.lineEnd, 1, true);
	}

	void deleteToWordAfter()
	{
		_undoStack.push!RemoveAction(this, TextBoundary.wordEnd | TextBoundary.punctuationEnd | TextBoundary.lineEnd, 1);
	}

	void deleteToEndOfLine()
	{
		//writeln("dtweol");

		_undoStack.push!RemoveAction(this, TextBoundary.lineBegin | TextBoundary.lineEnd, 1);
	}

	int incrementalFind(int index, string str)
	{
		return 1;
	}

	int[] findAll(string str)
	{
		return [1u,2,3];
	}

	TextBufferAnchor getLineAnchor(int lineNum)
	{
		return buffer.getLineAnchor(lineNum);
	}

	TextBufferAnchor createLineAnchor(int lineNum)
	{
		return buffer.createLineAnchor(lineNum);
	}

	private void onAnchorAdded(TextBuffer buf, TextBufferAnchor anchor)
	{
		// TODO: if this becomes a performance problem the do not just dirty
		dirty = true;
	}

	private void onAnchorRemoved(TextBuffer buf, TextBufferAnchor anchor)
	{
		// TODO: if this becomes a performance problem the do not just dirty
		dirty = true;
	}

	private void signalVisibleAnchors()
	{
		import std.algorithm;
		// Find visible anchor in view and emit signal if changed since last time
		auto as = buffer.getAnchorsForLines(lineOffset, visibleLineCount);
		auto sortedAs = as.sort!("a.number < b.number");

		if (as.length != visibleAnchors.length)
		{
			visibleAnchors = array(sortedAs);
			onAnchorVisibilityChanged.emit(this, visibleAnchors);
			return;
		}

		TextBufferAnchor[] existing = visibleAnchors[];

		foreach (a; sortedAs)
		{
			if (existing.empty || existing.front != a)
			{
				visibleAnchors = array(sortedAs);
				onAnchorVisibilityChanged.emit(this, visibleAnchors);
				break;
			}
			existing.popFront();
		}
	}

}

class BufferViewManager
{
	private
	{
		int _nextBufferViewID = 1;
	}

	BufferView[int] buffers;
	CopyBuffer copyBuffer;

	mixin Signal!BufferView onBufferViewCreated;
	mixin Signal!BufferView onBufferViewDestroyed;
	mixin Signal!(BufferView,bool) bufferModified;

	// BufferView has beem renamed from the second parameter to BufferView.name
	mixin Signal!(BufferView, string) onBufferViewRenamed;

	this()
	{
		copyBuffer = new CopyBuffer;
	}

	private string uniqueName()
	{
		int namingSeq = 0;
		while (true)
		{
			string autoName = text("Buffer ", namingSeq);
			if (this[autoName] is null)
				return autoName;
			namingSeq++;
		}
	}

	auto create(string content = "", string name = null)
	{
		sanitizeName(name);
		auto b = new BufferView(content);
		setup(b, name);
		return b;
	}

	auto create(TextBuffer buf, string name = null)
	{
		sanitizeName(name);
		auto b = new BufferView(buf);
		setup(b, name);
		return b;
	}

	private void sanitizeName(ref string name)
	{
		if (name is null)
			name = uniqueName();
		enforceEx!Exception(this[name] is null, text("A buffer with the name ", name, "already exists"));
	}

	private auto setup(BufferView b, string name)
	{
		if (name is null)
			name = uniqueName();
		enforceEx!Exception(this[name] is null, text("A buffer with the name ", name, "already exists"));

		b.bufferModified.connect(&onBufferModified);
		b.copyBuffer = copyBuffer;
		b.name = name;
		b._id = _nextBufferViewID++;
		buffers[b.id] = b;
		onBufferViewCreated.emit(b);
	}

	/**
	 * Params:
	 * path = path to file
	 * name = name of buffer. Leave empty to use the path as the name
	 */
	BufferView createFromPath(string path, string name = null)
	{
		auto b = create(name is null ? path : name);
		auto f = std.stdio.File(path, "rb");
		ulong size = f.size();
		b.buffer.reserve(cast(size_t)size);
		auto range = f.byLine!(dchar,char)(std.stdio.KeepTerminator.yes, '\n');
		foreach (line; range)
		{
			b.buffer.insert(to!(dchar[])(line));
		}
		return b;
	}

	BufferView opIndex(string name)
	{
		foreach (b; buffers)
		{
			if (b.name == name)
				return b;
		}
		return null;
	}

    BufferView opIndex(int idx)
    {
        if (auto b = idx in buffers)
            return *b;
        return null;
    }

	BufferView getOrCreate(string name)
	{
		auto b = this[name];
		if (b) return b;
		return create(name);
	}

	void rename(string from, string to)
	{
		auto b = this[from];
		if (b !is null)
		{
			b.name = to;
			onBufferViewRenamed.emit(b, from);
		}
	}

	void destroy(string name)
	{
		auto b = this[name];
		if (b)
		{
			buffers.remove(b.id); // TODO: make sure dependent actors get notified? or rely on GC?
			onBufferViewDestroyed.emit(b);
		}
	}

	void destroy(BufferView b)
	{
		foreach (key, value; buffers)
		{
			if (value == b)
			{
				destroy(value.name);
				return;
			}
		}
	}

	private void onBufferModified(BufferView b, bool isModified)
	{
		// propagate
		bufferModified.emit(b, isModified);
	}
}
