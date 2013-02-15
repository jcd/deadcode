module bufferview;

import buffer; // : TextGapBuffer;

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
			_visibleLineCount = c;
		}

		uint length() const nothrow
		{
			return buffer.length;
		}	
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
		_visibleLineCount = lines;
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
		std.stdio.writeln("cu ", _cursorPoint);
	}
	
	void cursorDown(uint c = 1)
	{
		_cursorPoint = buffer.linesOffset(_cursorPoint, c, _preferredCursorColumn);
		std.stdio.writeln("cd ", _cursorPoint);
	}
	
	void scrollUp()
	{
		bufferOffset = buffer.startOfLine(buffer.endOfPreviousLine(bufferOffset));
		if (_lineOffset > 0)
			_lineOffset -= 1;
	}

	void scrollDown()
	{
		bufferOffset = buffer.startOfNextLine(bufferOffset);
		if (_lineOffset < (buffer.lineCount - _visibleLineCount))
			_lineOffset += 1;
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
