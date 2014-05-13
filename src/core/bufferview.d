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

version(unittest) import test;

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
	
	CopyBuffer copyBuffer;

	uint selectionStartIndex;
	private Region _selection;
	// RegionSet selections;

	
	enum LineTag
	{
		none,
		test,
	}
	
	struct LineInfo
	{
		uint number; // zero indexed
		LineTag tag;
	}
	
	// NOTE: make this into gap buffer if performance becomes and issue
	LineInfo[] _lineInfo;

	alias immutable(TextBuffer.CharType)[] BufferString;

	Variant[string] userData;

	private bool _dirty;
	
	uint _bufferOffset; // char offset into the buffer from where to draw
	
	// emit(this, text, insertedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, uint) onInsert;
	
	// emit(this, text, removedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, uint) onRemove;

	// emit(this, text, removedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, uint) onCopy;

	// emi(this);
	mixin Signal!(BufferView) onDirty;

	@property 
	{
		void selection(Region r)
		{
			if (_selection == r)
				return;
			_selection = r;
			navigated();

		}

		Region selection() const pure nothrow
		{
			return _selection;
		}
		void dirty(bool d)
		{
			if (d)
				onDirty.emit(this);
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
		navigated();
	}

	package void navigated()
	{
		dirty = true;
	}

	package void changed()
	{
		dirty = true;
	}

	auto opSlice(size_t from, size_t to) const
	{
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

	package uint _cursorPoint;
	
	private 
	{
		uint _preferredCursorColumn;	
		uint _lineOffset;   // line offset into the buffer from where to draw. Could be derived from bufferOffset.
		uint _visibleLineCount;    // Number of lines to visible in view
		ActionStack _undoStack;
	}
	
	this(string txt)
	{
		import std.conv;
		this(new TextBuffer(to!dstring(txt), 10));
	}

	this(TextBuffer buffer)
	{
		this.buffer = buffer;
		buffer.lbuffer.onLinesInserted.connect(&this.onLinesInserted);
		buffer.lbuffer.onLinesRemoved.connect(&this.onLinesRemoved);

		_dirty = true;
		//selections = new RegionSet(true); // should be false
		_undoStack = new ActionStack;
		// copyBuffer = new CopyBuffer;
	}
	
	@property 
	{
		uint lineNumber()
		{
			return buffer.lineNumber(_cursorPoint);
		}

		// TODO: keep up to date
		ref uint lineOffset()
		{
			return _lineOffset;
		}
		
		uint bufferOffset() const pure nothrow
		{
			return _bufferOffset;
		}

		void bufferOffset(uint o)
		{
			if (_bufferOffset == o)
				return;
			_bufferOffset = o;
			_lineOffset = buffer.lineNumberAt(o);
			navigated();
		}

		// TODO: keep up to date and rename maybe
		uint visibleLineCount()
		{
			return _visibleLineCount;
		}

		void visibleLineCount(uint c)
		{
			if (_visibleLineCount != c)
			{
				_visibleLineCount = c;
				navigated();
			}
		}

		uint length() const nothrow
		{
			return buffer.length;
		}	

		const(TextBuffer.CharType)[] lastLine() const
		{
			return buffer.lastLine;
		}

		const(TextBuffer.CharType)[] selectedText() const
		{
			return buffer.toArray(selection.a, selection.b);
		}
	}

	void clearUndoStack()
	{
		_undoStack.clear();
	}

	void undo()
	{
		if (_undoStack.canUndo())
			_undoStack.undo(this);
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
		if (!copyBuffer.empty)
			_undoStack.push!PasteAction(this, copyBufferEntryOffset);
	}

	void pasteCycle()
	{
		if (!copyBuffer.empty)
			_undoStack.push!PasteAction(this, -1);
	}

	void cut()
	{
		_undoStack.push!ActionGroupAction(this, 
										  new CopySelectedAction(),
										  new RemoveSelectedAction());
	}

	void clear(immutable(TextBuffer.CharType)[] dl)
	{
		clear();
		_undoStack.push!InsertAction(this, dl);
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
		_undoStack.push!CursorAction(this, TextBoundary.buffer, -1);
		navigated();
	}

	void cursorToEnd() 
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.buffer, 1);
		navigated();
	}

	@property uint cursorPoint() const pure nothrow
	{
		return _cursorPoint;
	}

	@property void cursorPoint(uint v) 
	{
		assert(isValidCursorPoint(v), "Cursor out of range");
		if (_cursorPoint == v)
			return;
		_cursorPoint = v;
		navigated();

		//_undoStack.push!CursorRightAction(this, v - _cursorPoint);
		// _cursorPoint = v;
		// setPreferredCursorColumnFromIndex(v);
	}

	bool isValidCursorPoint(uint v)
	{
		return  buffer !is null && v >= 0 && v <= buffer.length;
	}

	bool isCursorAtEndOfline()
	{
		return _cursorPoint == buffer.offsetToEndOfLine(_cursorPoint);
	}

	/*
	@property int cursorPointRelative() const pure nothrow
	{
		return cast(int)cursorPoint - cast(int)bufferOffset;
	}
	*/

	@property uint preferredCursorColumn() const pure nothrow
	{
		return _preferredCursorColumn;
	}

	@property void preferredCursorColumn(uint col) 
	{
		if (_preferredCursorColumn == col)
			return;
		_preferredCursorColumn  = col;
		navigated();
	}

	void setPreferredCursorColumnFromIndex(uint index = uint.max) 
	{
		if (index == uint.max)
			index = _cursorPoint;
	
		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		uint startOfLine = buffer.offsetToStartOfLine(index);
		auto old = _preferredCursorColumn;
		_preferredCursorColumn = index - startOfLine;
		if (old != _preferredCursorColumn)
			navigated();
	}
	
	void setIndexFromPreferredCursorColumn(uint col = uint.max) 
	{
		if (col == uint.max)
			col = _preferredCursorColumn;
		
		auto old = cursorPoint;

		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		uint startOfLine = buffer.offsetToStartOfLine(_cursorPoint);
		uint endOfLine = buffer.offsetToEndOfLine(_cursorPoint);
		uint diff = endOfLine - startOfLine;
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
		if (selection.empty)
			_undoStack.push!InsertAction(this, txt);
		else
			_undoStack.push!ActionGroupAction(this, 
											  new RemoveSelectedAction(),
											  new InsertAction(txt)
											);
	}

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
		if (selection.empty)
			_undoStack.push!RemoveAction(this, TextBoundary.chr, count);
		else
			_undoStack.push!RemoveSelectedAction(this);
	}
	
	void clear()
	{
		_undoStack.push!CursorAction(this, TextBoundary.buffer, -1);
		_undoStack.push!RemoveAction(this, TextBoundary.chr, length);
	}
	
	void cursorLeft(uint c = 1) 
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.chr, -c);
	}	

	void cursorRight(uint c = 1)
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.chr, c);
	}

	void cursorUp(uint c = 1) 
	{
		clearSelection();
		_undoStack.push!CursorDownAction(this, -c);
	}
	
	void cursorDown(uint c = 1)
	{
		clearSelection();
		_undoStack.push!CursorDownAction(this, c);
	}
	
	void selectLeft(uint c = 1) 
	{
		selectTo(buffer.offsetByChar(_cursorPoint, -c));
		_undoStack.push!CursorAction(this, TextBoundary.chr, -c);
	}

	void selectRight(uint c = 1)
	{
		selectTo(buffer.offsetByChar(_cursorPoint, c));
		_undoStack.push!CursorAction(this, TextBoundary.chr, c);
	}

	void selectUp(uint c = 1) 
	{
		auto p = buffer.offsetVertically(_cursorPoint, -c, preferredCursorColumn);
		selectTo(p);
		_undoStack.push!CursorDownAction(this, -c);
	}

	void selectDown(uint c = 1)
	{
		auto p = buffer.offsetVertically(_cursorPoint, c, preferredCursorColumn);
		selectTo(p);
		_undoStack.push!CursorDownAction(this, c);
	}

	void selectTo(uint c)
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
		_bufferOffset = buffer.offsetToStartOfLine(buffer.endOfPreviousLine(bufferOffset));
		if (_lineOffset > 0)
			_lineOffset--;
		navigated();
	}

	void scrollDown()
	{
		if (_lineOffset < (buffer.lineCount - _visibleLineCount))
		{
			_lineOffset++;
			auto newbo = buffer.startOfNextLine(bufferOffset);
			if (newbo == bufferOffset)
				_lineOffset--;
			else
				_bufferOffset = newbo;
			navigated();
		}
	}

	void cursorToBeginningOfLine()
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.line, -1);
	}
	
	void cursorToEndOfLine()
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.line, 1);
	}

	void selectToBeginningOfLine()
	{
		auto startOfLine = buffer.offsetByLine(_cursorPoint, -1);
		selectTo(startOfLine);
		cursorPoint = startOfLine;
		setPreferredCursorColumnFromIndex();
	}

	void selectToEndOfLine()
	{
		auto endOfLine = buffer.offsetByLine(_cursorPoint, 1);
		selectTo(endOfLine);
		cursorPoint = endOfLine;
		setPreferredCursorColumnFromIndex();
	}
	
	void cursorToWordBefore()
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.word, -1);
	}
	
	void selectToWordBefore()
	{
		
		auto b = buffer.offsetByWord(_cursorPoint, -1);
		selectTo(b);
		cursorPoint = b;
		setPreferredCursorColumnFromIndex();
	}

	void deleteWordBefore()
	{ 
		if (selection.empty)
			_undoStack.push!RemoveAction(this, TextBoundary.word, -1);
		else
			_undoStack.push!RemoveSelectedAction(this);
	}

	void cursorToWordAfter()
	{
		clearSelection();
		_undoStack.push!CursorAction(this, TextBoundary.word, 1);
	}
	
	void selectToWordAfter()
	{
		auto a = buffer.offsetByWord(_cursorPoint, 1);
		selectTo(a);
		cursorPoint = a;
		setPreferredCursorColumnFromIndex();
	}

	void deleteWordAfter()
	{
		if (selection.empty)
			_undoStack.push!RemoveAction(this, TextBoundary.word, 1);
		else
		    _undoStack.push!RemoveSelectedAction(this);
	}

	void deleteToEndOfLine()
	{
		if (selection.empty)
			_undoStack.push!RemoveAction(this, TextBoundary.line, 1);
		else
		    _undoStack.push!RemoveSelectedAction(this);
	}

	uint incrementalFind(uint index, string str)
	{
		return 1;
	}

	uint[] findAll(string str)
	{
		return [1u,2,3];
	}

	// TODO: Use more performant container for line info supporting quick lookups
	auto getLineInfo(uint lineNumber)
	{
		foreach (ref info; _lineInfo)
		{
			if (lineNumber == info.number)
				return info;
		}
		return LineInfo();
	}
	
	void setLineInfo(LineInfo i)
	{
		foreach (ref info; _lineInfo)
		{
			if (i.number == info.number)
			{
				info = i;
				return;
			}
		}
		_lineInfo ~= i;
	}

	void onLinesInserted(uint lineNumber, uint lineCount)
	{
		foreach (ref info; _lineInfo)
		{
			if (info.number >= lineNumber)
				info.number += lineCount;
		}
	}

	void onLinesRemoved(uint lineNumber, uint lineCount)
	{
		foreach (ref info; _lineInfo)
		{
			if (info.number >= lineNumber)
				info.number -= lineCount;
		}
	}
}

class BufferViewManager
{
	BufferView[string] buffers;
	uint _namingSeq;

	CopyBuffer copyBuffer;
	
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
		if (name is null)
			name = uniqueName();
		enforceEx!Exception(! (name in buffers), text("A buffer with the name ", name, "already exists"));
		auto b = new BufferView(content);
		b.copyBuffer = copyBuffer;
		buffers[name] = b;
		b.name = name;
		return b;
	}

	auto create(TextBuffer buf, string name = null)
	{
		if (name is null)
			name = uniqueName();
		enforceEx!Exception(! (name in buffers), text("A buffer with the name ", name, "already exists"));
		auto b = new BufferView(buf);
		b.copyBuffer = copyBuffer;
		buffers[name] = b;
		b.name = name;
		return b;
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
	}

	void destroy(string name)
	{
		auto b = name in buffers;
		if (b)
			buffers.remove(name); // TODO: make sure dependent actors get notified? or rely on GC?
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
}
