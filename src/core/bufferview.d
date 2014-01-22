module core.bufferview;

import core.buffer; // : TextGapBuffer;
import core.bufferviewaction;
import math.region;
import std.container;
import std.conv;
import std.exception;
import std.range;
import std.stdio;

version(unittest) import test;

// TODO:
//	* Set preferred colum doesn't work
//  * Cannot page down until out after buffer length. Think buffer.startOfLine/endOfLine are guilty

/** A BufferView is used as a view to he contents of a buffer. 
 * Several BufferViews may display the same buffer.
 * The selection, cursor position etc. is distinct for each BufferView.
 * Changes to the buffer is usually done through a view.
 * To render a specific BufferView on screen use a TextRenderer.
 */
class BufferView 
{	
	string name;
	package TextGapBuffer buffer;     // This should be changeable to something else if wanted
	// private GapBuffer!int lineStarts; // Indexes into buffer for all line starts. Purely a optimization.
	private RegionSet selections;

	bool dirty;
	uint bufferOffset; // char offset into the buffer from where to draw

	alias void delegate(BufferView) Callback;

	Callback onChanged;
	package void changed()
	{
		dirty = true;
		if (onChanged !is null)
			onChanged(this);
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
		onChanged = null;
		selections = new RegionSet(true); // should be false
		_undoStack = new ActionStack;
	}
	
	@property 
	{
		uint lineNumber()
		{
			return buffer.lineNumber(_cursorPoint);
		}

		// TODO: keep up to date
		uint lineOffset()
		{
			return _lineOffset;
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

	void clear(immutable(TextGapBuffer.CharType)[] dl)
	{
		clear();
		_undoStack.push!InsertAction(this, dl);
		// buffer = new TextGapBuffer(dl, 20);
		// changed();
	}

	void write(File file)
	{
		file.rawWrite(std.conv.text(buffer.beforeGap));
		file.rawWrite(std.conv.text(buffer.afterGap));
	}

	void cursorToStart() 
	{
		_undoStack.push!CursorToStartAction(this);
		// cursorPoint = 0;
	}

	void cursorToEnd() 
	{
		_undoStack.push!CursorToEndAction(this);
		// cursorPoint = length;
	}

	@property uint cursorPoint() const pure nothrow
	{
		return _cursorPoint;
	}

	@property void cursorPoint(uint v) 
	{
		assert(buffer !is null && v >= 0 && v <= buffer.length, "Cursor out of range");
		_undoStack.push!CursorRightAction(this, v - _cursorPoint);
		// _cursorPoint = v;
		setPreferredCursorColumnFromIndex(v);
	}

	@property int cursorPointRelative() const pure nothrow
	{
		return cast(int)cursorPoint - cast(int)bufferOffset;
	}

	@property uint preferredCursorColumn() const pure nothrow
	{
		return _preferredCursorColumn;
	}
	
	void setPreferredCursorColumnFromIndex(uint index = uint.max) 
	{
		if (index == uint.max)
			index = _cursorPoint;
		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		_preferredCursorColumn = index - buffer.startOfLine(index);
	}
	
	@property void linesVisible(uint lines)
	{
		if (_visibleLineCount != lines)
		{
			_visibleLineCount = lines;
			dirty = true;
		}
	}

	/** Step history when doing redo/undo
	 *  
	 * Params:
	 * steps number of steps to walk in history. Negative values will 
	 * undo actions done on this view.
	 */
	void stepHistory(int steps)
	{
		
	}
		
	void insert(dchar item)
	{
		dchar[1] buf;
		buf[0] = item;
		insert(buf.idup);
		//actionStack.insert(this, buf.idup);
	}

	void insert(dstring txt)
	{
		_undoStack.push!InsertAction(this, txt);
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
		_undoStack.push!RemoveAction(this, count);
	}
	
	void clear()
	{
		_undoStack.push!CursorRightAction(this, -cursorPoint);
		_undoStack.push!RemoveAction(this, length);

		//		this.cursorPoint = 0;
		//actionStack.remove(this, buffer.length);
		//buffer.clear();
		//cursorPoint = 0;
		//_preferredCursorColumn = 0;
		//cursorPoint = buffer.editPoint;		
	}
	
	void cursorLeft(uint c = 1) 
	{
		_undoStack.push!CursorRightAction(this, -c);
	}	

	void cursorRight(uint c = 1)
	{
		_undoStack.push!CursorRightAction(this, c);
	}

	void cursorUp(uint c = 1) 
	{
		_undoStack.push!CursorDownAction(this, -c);
	}
	
	void cursorDown(uint c = 1)
	{
		_undoStack.push!CursorDownAction(this, c);
	}
	
	void scrollUp()
	{
		bufferOffset = buffer.startOfLine(buffer.endOfPreviousLine(bufferOffset));
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
				_lineOffset++;
			else
				bufferOffset = newbo;
			dirty = true;
		}
	}

	void cursorToBeginningOfLine()
	{
		_cursorPoint = buffer.startOfLine(_cursorPoint);
		_preferredCursorColumn = 0;
	}
	
	void cursorToEndOfLine()
	{
		cursorPoint = buffer.endOfLine(_cursorPoint);
	}

	private uint indexWordBefore()
	{
		uint endOfWord = buffer.findOneOfReverse(_cursorPoint - 1, buffer.WORDCHARS);
		uint target = 0;
		if (endOfWord != uint.max)
		{
			target = endOfWord;
			uint startOfWord = buffer.findOneNotOfReverse(endOfWord, buffer.WORDCHARS);
			target = 0;
			if (startOfWord != uint.max)
				target = startOfWord + 1;
		}
		return target;
	}
	
	void cursorToWordBefore()
	{
		cursorPoint = indexWordBefore();
	}
	
	void deleteWordBefore()
	{ 
		auto deleteTo = indexWordBefore();
		auto deleteLen = _cursorPoint - deleteTo;
		cursorPoint = deleteTo;
		remove(deleteLen);
	}
	
	private uint indexWordAfter()
	{
		uint startOfWord = buffer.findOneOf(_cursorPoint, buffer.WORDCHARS);
		uint target = buffer.length;
		if (startOfWord != uint.max)
		{
			target = startOfWord;
			uint endOfWord = buffer.findOneNotOf(startOfWord, buffer.WORDCHARS);
			if (endOfWord != uint.max)
				target = endOfWord;
		}
		return target;
	}

	void cursorToWordAfter()
	{
		cursorPoint = indexWordAfter();
	}
	
	void deleteWordAfter()
	{
		auto deleteTo = indexWordAfter();
		auto deleteLen = deleteTo - _cursorPoint;
		cursorPoint = deleteTo;
		remove(-deleteLen);
	}

	void deleteToEndOfLine()
	{
		uint eol = buffer.endOfLine(_cursorPoint);
		if (eol == _cursorPoint)
		{
			eol = buffer.startOfNextLine(_cursorPoint);
		}
		remove(eol - _cursorPoint);
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
