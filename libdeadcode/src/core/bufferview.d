module core.bufferview;

import core.buffer; // : TextBuffer;
import core.bufferviewaction;
import core.copybuffer;
import math.region;
import std.container;
import std.conv;
import std.exception;
import std.range;
import std.signals;
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
	string name;
	TextBuffer buffer;     // This should be changeable to something else if wanted
	// private GapBuffer!int lineStarts; // Indexes into buffer for all line starts. Purely a optimization.
	
	package CopyBuffer copyBuffer;

	bool autoCursorInView = true;

	int selectionStartIndex;
	private Region _selection;
	// RegionSet selections;
	
	alias immutable(TextBuffer.CharType)[] BufferString;
	alias TextBuffer.CharType CharType;

	Variant[string] userData;

	TextBufferAnchor[] visibleAnchors;

	// 
	private bool _dirty;
	
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
		void selection(Region r)
		{
			if (_selection == r)
				return;
			_selection = r;
			dirty = true;
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

	void centerOnLine(int line)
	{
		auto offset = visibleLineCount / 2;
		auto lastLine = lineOffset + visibleLineCount - 1; 
		if (offset > line)
			lineOffset = 0;
		else 
			lineOffset = line - offset;
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
		assert((to >= 0 && to <= length) || (from >= 0 && from <= length), format("Slice overflow %s: 0 <= %s .. %s <= %s", name, from, to, length));
		return buffer.opSlice(from, to);
	}

	auto opIndex(size_t i) const
	{
		return buffer[i];
	}

	void ensureCapacity(size_t s)
	{
		if (s <= buffer.length)
			return;
		buffer.gbuffer.ensureGapCapacity(s - buffer.length);
	}

	package int _cursorPoint;
	
	private 
	{
		int _preferredCursorColumn;	
		int _lineOffset;   // line offset into the buffer from where to draw.
		int _bufferStartOffset; // Cached value of index of first char on line specified by lineOffset
		int _visibleLineCount;    // Number of lines to visible in view
		bool _modified;
		ActionStack _undoStack;
	}
	
	debug void enableUndoStackDumps() { _undoStack.dumpEnabled = true; }
	
	this(string txt)
	{
		import std.conv;
		this(new TextBuffer(to!dstring(txt), 10));
	}

	this(TextBuffer buffer)
	{
		this.buffer = buffer;
		_dirty = true;
		_modified = false;
		//selections = new RegionSet(true); // should be false
		_undoStack = new ActionStack;
		// copyBuffer = new CopyBuffer;
		buffer.onAnchorAdded.connect(&onAnchorAdded);
		buffer.onAnchorRemoved.connect(&onAnchorRemoved);
	}
	
	@property 
	{
		int lineNumber() const
		{
			return buffer.lineNumber(_cursorPoint);
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
			return buffer.length;
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
			if (a == int.max || b == int.max)
				return Region(cursorPoint, cursorPoint);
			else
				return Region(a, b);
		case RegionQuery.line:
			auto ends = buffer.lineEndsAt(cursorPoint);
			return Region(ends[0], ends[1]);
		case RegionQuery.buffer:
			return Region(0, buffer.length);
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

	void replace(dstring txt, Region r)
	{
		int restoreCursorPoint = cursorPoint;
		int begin = r.a;
		int end = r.b;
		
		//Region oldSelection = selection;
		//oldSelection.entriesRemoved(begin, (end == int.max ? buffer.length : end) - begin);
		//oldSelection.entriesInserted(begin, txt.length);
		
		// cursorPoint = r.a;

		writeln("replaceA");
		auto offsetToStart = r.a - _cursorPoint;
		_undoStack.push!ActionGroupAction(this, 
										  new CursorAction(TextBoundary.unit, offsetToStart),
										  new RemoveAction(TextBoundary.unit, r.length),
										  new InsertAction(txt));

		if (restoreCursorPoint <= begin)
			cursorPoint = restoreCursorPoint;
		else if (Region(begin, end).contains(restoreCursorPoint))
			cursorPoint = begin + txt.length;
		else
			cursorPoint = restoreCursorPoint - ((end == int.max ? buffer.length : end) - begin - txt.length);
		// selection = oldSelection;
	}

	void transform(alias Func)(Region r)
	{
		if (!r.empty)
			replace(cast(immutable)Func(getText(r)), r);
	}

	void transform(alias Func)(RegionQuery query)
	{
		transform!Func(getRegion(query));
	}

	Region wordAtCursor() const
	{
		auto startOfWord = buffer.offsetToWordBoundary(_cursorPoint, true);
		auto endOfWord = buffer.offsetToWordBoundary(_cursorPoint, false);
		if (startOfWord == int.max || endOfWord == int.max)
			return Region(_cursorPoint, _cursorPoint);
		else
			return Region(startOfWord, endOfWord);
	}

	//void replace(dstring txt, Region r)
	//{
	//    replace(txt, r.a, r.b);
	//}
	
	int lineCount() const
	{
		return buffer.lineNumber(buffer.length == 0 ? 0 : buffer.length - 1);
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
		writeln("cutA");
		_undoStack.push!ActionGroupAction(this, 
										  new CopySelectedAction(),
										  new RemoveAction(TextBoundary.unit, 0)); // remove 0 to remove selection
	}

	void clear(immutable(TextBuffer.CharType)[] dl)
	{
		writeln("clearA1 ", name, " ", length, " ", dl.length);
		_undoStack.push!ActionGroupAction(this, 
											new CursorAction(TextBoundary.buffer, -1),
											new RemoveAction(TextBoundary.buffer, 1),
											new InsertAction(dl));
		writeln("clearA2");
	}

	void write(File file)
	{
		// TODO: use iomanager and IOs for writing
		file.rawWrite(std.conv.text(buffer.beforeGap));
		file.rawWrite(std.conv.text(buffer.afterGap));
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
		return _cursorPoint;
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

		_undoStack.push!CursorAction(this, TextBoundary.unit, v - _cursorPoint, false);

		navigated();
	}

	bool isValidCursorPoint(int v)
	{
		return  buffer !is null && v >= 0 && v <= buffer.length;
	}

	bool isCursorAtEndOfline()
	{
		return cursorPoint == buffer.offsetToEndOfLine(_cursorPoint);
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

	void setPreferredCursorColumnFromIndex(int index = int.max) 
	{
		if (index == int.max)
			index = _cursorPoint;
	
		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		int startOfLine = buffer.offsetToBeginningOfLine(index);
		auto old = _preferredCursorColumn;
		_preferredCursorColumn = index - startOfLine;
		if (old != _preferredCursorColumn)
			navigated();
	}
	
	void setIndexFromPreferredCursorColumn(int col = int.max) 
	{
		if (col == int.max)
			col = _preferredCursorColumn;
		
		auto old = cursorPoint;

		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		int startOfLine = buffer.offsetToBeginningOfLine(_cursorPoint);
		int endOfLine = buffer.offsetToEndOfLine(_cursorPoint);
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
		insert(dtext(items));
	}

	void remove(int count)
	{
		writeln("removeA");
		_undoStack.push!RemoveAction(this, TextBoundary.chr, count);
	}
	
	void clear()
	{
		writeln("clearB");
		_undoStack.push!ActionGroupAction(this, 
										  new CursorAction(TextBoundary.buffer, -1),
										  new RemoveAction(TextBoundary.buffer, 1));
		writeln("clearB");

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
		if (selection.empty)
			selectionStartIndex = cursorPoint;
		
		import std.algorithm;

		if (selectionStartIndex < c)
			selection = Region(selectionStartIndex, min(c, buffer.length));
		else
			selection = Region(max(c,0), selectionStartIndex);
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
		_undoStack.push!CursorAction(this, TextBoundary.lineEnd, -1, false);
	}

	void cursorToEndOfLine()
	{
		_undoStack.push!CursorAction(this, TextBoundary.lineEnd, 1, false);
	}

	void cursorToLineBefore()
	{
		_undoStack.push!CursorAction(this, TextBoundary.line, -1, false);
	}

	void cursorToLineAfter()
	{
		_undoStack.push!CursorAction(this, TextBoundary.line, 1, false);
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
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd, -1, false);
	}

	void cursorToEndOfWord()
	{
		_undoStack.push!CursorAction(this, TextBoundary.wordEnd, 1, false);
	}

	void cursorToWordBefore()
	{
		_undoStack.push!CursorAction(this, TextBoundary.word, -1, false);
	}

	void selectToWordBefore()
	{		
		_undoStack.push!CursorAction(this, TextBoundary.word, -1, true);
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
		writeln("dtwb");
		_undoStack.push!RemoveAction(this, TextBoundary.word, -1);
	}

	void cursorToWordAfter()
	{
		_undoStack.push!CursorAction(this, TextBoundary.word, 1, false);
	}
	
	void selectToWordAfter()
	{
		_undoStack.push!CursorAction(this, TextBoundary.word, 1, true);
	}

	void deleteToWordAfter()
	{	
		writeln("dtwa");
		_undoStack.push!RemoveAction(this, TextBoundary.word, 1);
	}

	void deleteToEndOfLine()
	{
		writeln("dtweol");

		_undoStack.push!RemoveAction(this, TextBoundary.line, 1);
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
	BufferView[string] buffers;
	int _namingSeq;

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
		while (true)
		{
			string autoName = text("Buffer ", _namingSeq);
			if (autoName !in buffers)
				return autoName;
			_namingSeq++;
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
		enforceEx!Exception(! (name in buffers), text("A buffer with the name ", name, "already exists"));
	}

	private auto setup(BufferView b, string name)
	{
		if (name is null)
			name = uniqueName();
		enforceEx!Exception(! (name in buffers), text("A buffer with the name ", name, "already exists"));

		b.bufferModified.connect(&onBufferModified);
		b.copyBuffer = copyBuffer;
		buffers[name] = b;
		b.name = name;
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
		auto b = name in buffers;
		if (b) return *b;
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
		buffers.remove(from);
		buffers[to] = b;
		b.name = to;
		onBufferViewRenamed.emit(b, from);
	}

	void destroy(string name)
	{
		auto b = name in buffers;
		if (b)
		{
			buffers.remove(name); // TODO: make sure dependent actors get notified? or rely on GC?
			onBufferViewDestroyed.emit(*b);
		}
	}
	
	void destroy(BufferView b)
	{
		foreach (key, value; buffers)
		{
			if (value == b)
			{
				destroy(key);
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
