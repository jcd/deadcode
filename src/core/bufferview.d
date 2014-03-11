module core.bufferview;

import core.buffer; // : TextGapBuffer;
import core.bufferviewaction;
import math.region;
import std.container;
import std.conv;
import std.exception;
import std.range;
import std.signals;
import std.stdio;

version(unittest) import test;

class CopyBuffer
{
	static class Entry
	{
		this(dstring t)
		{
			txt = t;
		}
		dstring txt;
	}
	Entry[] entries;

	@property bool empty() const
	{
		return entries.empty;
	}

	@property size_t length() const
	{
		return entries.length;
	}

	void add(dstring t)
	{
		entries ~= new Entry(t);
	}

	Entry get(int offset)
	{
		if (offset >= entries.length)
			return null;
		return entries[$-offset-1];
	}
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
	TextGapBuffer buffer;     // This should be changeable to something else if wanted
	// private GapBuffer!int lineStarts; // Indexes into buffer for all line starts. Purely a optimization.
	
	CopyBuffer copyBuffer;

	uint selectionStartIndex;
	Region selection;
	// RegionSet selections;

	alias immutable(TextGapBuffer.CharType)[] BufferString;

	bool dirty;
	uint _bufferOffset; // char offset into the buffer from where to draw
	
	// emit(this, text, insertedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, uint) onInsert;
	
	// emit(this, text, removedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, uint) onRemove;

	// emit(this, text, removedTextAfterThisIndex)
	mixin Signal!(BufferView, BufferString, uint) onCopy;

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
		this(new TextGapBuffer(to!dstring(txt), 10));
	}

	this(TextGapBuffer buffer)
	{
		this.buffer = buffer;
		dirty = true;
		//selections = new RegionSet(true); // should be false
		_undoStack = new ActionStack;
		copyBuffer = new CopyBuffer;
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
		
		uint bufferOffset() const
		{
			return _bufferOffset;
		}

		void bufferOffset(uint o)
		{
			_bufferOffset = o;
			_lineOffset = buffer.lineNumberAt(o);
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
				dirty = true;
			}
		}

		uint length() const nothrow
		{
			return buffer.length;
		}	

		const(TextGapBuffer.CharType)[] lastLine() const
		{
			return buffer.lastLine;
		}

		const(TextGapBuffer.CharType)[] selectedText() const
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

	void clear(immutable(TextGapBuffer.CharType)[] dl)
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
		selection.clear();
		_undoStack.push!CursorAction(this, TextBoundary.buffer, -1);
	}

	void cursorToEnd() 
	{
		selection.clear();
		_undoStack.push!CursorAction(this, TextBoundary.buffer, 1);
	}

	@property uint cursorPoint() const pure nothrow
	{
		return _cursorPoint;
	}

	@property void cursorPoint(uint v) 
	{
		assert(isValidCursorPoint(v), "Cursor out of range");
		_cursorPoint = v;
		
		//_undoStack.push!CursorRightAction(this, v - _cursorPoint);
		// _cursorPoint = v;
		// setPreferredCursorColumnFromIndex(v);
	}

	bool isValidCursorPoint(uint v)
	{
		return  buffer !is null && v >= 0 && v <= buffer.length;
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
		_preferredCursorColumn  = col;
	}

	void setPreferredCursorColumnFromIndex(uint index = uint.max) 
	{
		if (index == uint.max)
			index = _cursorPoint;
		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		uint startOfLine = buffer.offsetToStartOfLine(index);
		_preferredCursorColumn = index - startOfLine;
	}
	
	void setIndexFromPreferredCursorColumn(uint col = uint.max) 
	{
		if (col == uint.max)
			col = _preferredCursorColumn;
		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		uint startOfLine = buffer.offsetToStartOfLine(_cursorPoint);
		uint endOfLine = buffer.offsetToEndOfLine(_cursorPoint);
		uint diff = endOfLine - startOfLine;
		if (diff > col)
			cursorPoint = startOfLine + col;
		else
			cursorPoint = endOfLine;
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
		selection.clear();
		_undoStack.push!CursorAction(this, TextBoundary.chr, -c);
	}	

	void cursorRight(uint c = 1)
	{
		selection.clear();
		_undoStack.push!CursorAction(this, TextBoundary.chr, c);
	}

	void cursorUp(uint c = 1) 
	{
		selection.clear();
		_undoStack.push!CursorDownAction(this, -c);
	}
	
	void cursorDown(uint c = 1)
	{
		selection.clear();
		_undoStack.push!CursorDownAction(this, c);
	}
	
	void selectLeft(uint c = 1) 
	{
		selectTo(_cursorPoint - c);
		_undoStack.push!CursorAction(this, TextBoundary.chr, -c);
	}

	void selectRight(uint c = 1)
	{
		selectTo(_cursorPoint + c);
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
		
		if (selectionStartIndex < c)
			selection = Region(selectionStartIndex, c);
		else
			selection = Region(c, selectionStartIndex);
	}

	void scrollUp()
	{	
		_bufferOffset = buffer.offsetToStartOfLine(buffer.endOfPreviousLine(bufferOffset));
		if (_lineOffset > 0)
			_lineOffset--;
		dirty = true;
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
			dirty = true;
		}
	}

	void cursorToBeginningOfLine()
	{
		selection.clear();
		_undoStack.push!CursorAction(this, TextBoundary.line, -1);
	}
	
	void cursorToEndOfLine()
	{
		selection.clear();
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
		selection.clear();
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
		selection.clear();
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
}

class BufferViewManager
{
	BufferView[string] buffers;
	uint _namingSeq;

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
		buffers[name] = b;
		b.name = name;
		return b;
	}

	auto create(TextGapBuffer buf, string name = null)
	{
		if (name is null)
			name = uniqueName();
		enforceEx!Exception(! (name in buffers), text("A buffer with the name ", name, "already exists"));
		auto b = new BufferView(buf);
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
		b.buffer.ensureGapCapacity(cast(uint)size);
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
