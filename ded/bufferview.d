module bufferview;

import buffer; // : TextGapBuffer;
import std.conv;
import std.exception;
import std.range;

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
	static BufferView _current;
	static @property {
		BufferView current()
		{
			return _current;
		}
		void current(BufferView c)
		{
			_current = c;
		}
	}	
	string name;
	TextGapBuffer buffer; // This should be changeable to something else if wanted
	// BufferInfo bufferInfo;
	bool dirty;
	uint bufferOffset; // char offset into the buffer from where to draw
	
	private 
	{
		uint _cursorPoint;
		uint _preferredCursorColumn;	
		uint _lineOffset;   // line offset into the buffer from where to draw. Could be derived from bufferOffset.
		uint _visibleLineCount;    // Number of lines to visible in view
	}
	
	this(string txt)
	{
		import std.conv;
		this(new TextGapBuffer(to!dstring(txt), 10));
	}

	this(TextGapBuffer buffer)
	{
		if (_current is null)
			_current = this;
		this.buffer = buffer;
		// this.bufferInfo = BufferInfo( null, false );
		dirty = true;
	}
				
	@property 
	{
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
	}
	
	void cursorToEnd() nothrow
	{
		_cursorPoint = length;
	}

	@property uint cursorPoint() const pure nothrow
	{
		return _cursorPoint;
	}

	@property void cursorPoint(uint v) 
	{
		assert(buffer !is null && v >= 0 && v <= buffer.length, "Cursor out of range");
		_cursorPoint = v;
		setPreferredCursorColumnFromIndex(v);
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
	
	private void insertInternal(dchar item, uint index = uint.max)
	{
		buffer.insert(item, index);
		dirty = true;
//		bufferInfo.undoStack ~= UndoStep(fdfdasdf);
	}
	
	private void insertInternal(const(dchar)[] items, uint index = uint.max)
	{
		buffer.insert(items, index);
		dirty = true;
//		bufferInfo.undoStack ~= UndoStep(fdfdasdf);
	}

	private void removeInternal(int count, int index = uint.max)
	{
		dirty = true;
		buffer.remove(count, index);		
	}

	void insert(dchar item, uint index = uint.max)
	{
		if (index == uint.max)
			index = _cursorPoint;
		insertInternal(item, index);
		_cursorPoint = buffer.editPoint;
	}

	void insert(const(dchar)[] items, uint index = uint.max)
	{
		if (index == uint.max)
			index = _cursorPoint;
		insertInternal(items, index);
		_cursorPoint = buffer.editPoint;
	}

	void append(const(dchar)[] items)
	{
		cursorToEnd();
		insert(items);
	}

	void remove(int count, int index = uint.max)
	{
		if (index == uint.max)
			index = _cursorPoint;
		removeInternal(count, index);		
		_cursorPoint = buffer.editPoint;
	}
	
	void clear()
	{
		buffer.clear();
		cursorPoint = 0;
		_preferredCursorColumn = 0;
		cursorPoint = buffer.editPoint;		
	}
	
	void cursorLeft(uint c = 1) 
	{
		_cursorPoint = buffer.charsOffset(_cursorPoint, -c);
	}	

	void cursorRight(uint c = 1)
	{
		_cursorPoint = buffer.charsOffset(_cursorPoint, c);
	}

	void cursorUp(uint c = 1) 
	{
		_cursorPoint = buffer.linesOffset(_cursorPoint, -c, _preferredCursorColumn);
	}
	
	void cursorDown(uint c = 1)
	{
		_cursorPoint = buffer.linesOffset(_cursorPoint, c, _preferredCursorColumn);
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
	}
	
	void cursorToEndOfLine()
	{
		_cursorPoint = buffer.endOfLine(_cursorPoint);
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
		_cursorPoint = indexWordBefore();
	}
	
	void deleteWordBefore()
	{ 
		auto deleteTo = indexWordBefore();
		removeInternal(_cursorPoint - deleteTo, deleteTo);
		_cursorPoint = deleteTo;
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
		_cursorPoint = indexWordAfter();
	}
	
	void deleteWordAfter()
	{
		auto deleteTo = indexWordAfter();
		removeInternal(deleteTo - _cursorPoint, _cursorPoint);
	}

	void deleteToEndOfLine()
	{
		uint eol = buffer.endOfLine(_cursorPoint);
		if (eol == _cursorPoint)
		{
			eol = buffer.startOfNextLine(_cursorPoint);
		}
		removeInternal(eol - _cursorPoint, _cursorPoint);
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
		return "";
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
