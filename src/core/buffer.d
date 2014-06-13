module core.buffer;

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.typecons;
import std.signals;
import std.variant;
import math.region;

version (unittest) import test;

class GapBuffer(T = dchar)
{
	alias T CharType;
	private 
	{
		uint gapStart;
		uint gapEnd;
		uint gapDefaultSize;
		T[] buffer;
	}
		
	this(const T[] txt, uint gapSize = 40)
	{
		clear(txt, gapSize);
	}
	
	void clear(const T[] txt = null, uint gapSize = 40)
	{
		gapStart = 0;
		gapEnd = gapSize;
		gapDefaultSize = gapSize;
		buffer.length = txt.length + gapDefaultSize;
		copy(txt[], buffer[gapEnd..$]);
	}
	
	@property size_t editPoint() const pure nothrow
	{
		return gapStart;
	}

	@safe @property length() const pure nothrow 
	{
		return buffer.length - (gapEnd - gapStart);
	}
		
	@safe @property gapSize() const pure nothrow
	{
		return gapEnd - gapStart;
	}

	@safe @property empty() const pure nothrow 
	{
		return length == 0;
	}

	void moveEditPointToEnd()
	{
		placeGapStart(length);
	}

	private void placeGapStart(uint index)
	{
		// Is the index already correct
		if (index == gapStart) return;

		// Do we have a gap
		if (gapStart == gapEnd)
		{
			gapStart = index;
			gapEnd = index;
			return;
		}
		
		// Move gap in correct direction
		if (index < gapStart)
		{
			// Move wchars from before gap to end of gap thereby creating a gap at index.
			auto count = gapStart - index;
			auto gapSize = gapEnd - gapStart;
			auto deltaCount =  gapSize < count ? gapSize : count;
			
			copy(retro(buffer[index..gapStart]), retro(buffer[gapEnd-count..gapEnd]));
			gapStart = index;
			gapEnd -= count;
			// Clear gap
			fill(buffer[index..index+deltaCount], T.init);
		}
		else
		{
			// Move wchars from after gap to beginning of gap thereby creating a gap at index.
			auto count = index - gapStart;
			auto gapSize = gapEnd - gapStart;
			auto deltaIndex =  index > gapEnd ? index : gapEnd;
			copy(buffer[gapEnd..gapEnd+count], buffer[gapStart..gapStart+count]);
			gapStart += count;
			gapEnd += count;

			fill(buffer[deltaIndex..gapEnd], T.init);
		}
	}	
	
	unittest
	{
		/*
		auto b = new GapBuffer("12345"d, 3);
		dchar[8] a;
		std.algorithm.fill(a, dchar.init);
		a[3..$] = "12345"d;
		assert(std.algorithm.equal(b.buffer, a));
		
		b.placeGapStart(1);
		a[3] = dchar.init;
		a[0] = '1';
		assert(std.algorithm.equal(b.buffer, a));		
		 */
	}

	void ensureGapCapacity(uint size)
	{
		size_t gapSize = gapEnd - gapStart;
		if (gapSize >= size) return;
		
		// A resize is necessary which mean a new allocation and copy of existing content.
		// Since this should be done rarely we allocate more that needed.
		// D's built in arrays automatically reallocates and copies so we just use that
		// functionallity
		size_t deltaSize = size - gapSize;
		buffer.length = buffer.length + deltaSize; // make roomfd
		copy(retro(buffer[gapEnd..$-deltaSize]), retro(buffer[gapEnd+deltaSize..$]));
		gapEnd += deltaSize;
	}
	
	void insert(T item, uint index = uint.max)
	{
		if (index == uint.max)
			index = gapStart;
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		placeGapStart(index);
		ensureGapCapacity(1);
		buffer[index] = item;
		gapStart++;
	}

	void insert(const(T)[] items, uint index = uint.max)
	{
		if (index == uint.max)
			index = gapStart;
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		placeGapStart(index);
		ensureGapCapacity(items.length);
		buffer[index..index+items.length] = items[];
		gapStart += items.length;
	}

	unittest 
	{
		/*
		auto b = GapBuffer("12345"w, 3);
		b.insert(0, 'X');
		
		dchar[8] a;
		std.algorithm.fill(a, dchar.init);
		a[3..$] = "12345"w;
		a[0] = 'X';
		assert(std.algoritms.equals(b.buffer, a));

/+
			b.insert(2, 'X');
		a[1] = '1';
		a[3] = dchar.init;
	+/	
		*/		
	}

	// Deletes forward from index ie.:
	// abc[gap]def
	// will remove 'd' and end with
	// abc[gap]ef
	void remove(uint index = uint.max)
	{
		if (index == uint.max)
			index = gapStart - 1; // TODO: -1 ! Really?
		enforceEx!Exception(index >= 0 && index < length, text("Index out of bounds 0 <= ", index , " < ", length));
		placeGapStart(index);
		buffer[gapEnd] = T.init;
		gapEnd++;
	}
	
	void reset(T[])
	{
		
	}
	
	T opIndex(size_t index) const pure
	{
		enforceEx!Exception(index >= 0 && index < length, text("Index out of bounds 0 <= ", index , " < ", length));
		if (index >= gapStart)
			index += gapEnd - gapStart;		
		return buffer[index];
	}

	T opIndexAssign(T item, size_t index)
	{
		enforceEx!Exception(index >= 0 && index < length, text("Index out of bounds 0 <= ", index , " < ", length));
		if (index >= gapStart)
			index += gapEnd - gapStart;		
		buffer[index] = item;
		return item;
	}

	auto opSlice(size_t from, size_t to) const pure
	{
		static struct Range
		{
			private 
			{
				const(GapBuffer!T) gbuf;
				size_t from;
				size_t to;
			}
			
			this(const(GapBuffer!T) gbuf, size_t f, size_t t) pure nothrow
			{
				assert(t <= gbuf.length);
				assert(f <= t);
				this.gbuf = gbuf;
				this.from = f;
				this.to = t > gbuf.length ? gbuf.length : t;				
			}

			@property size_t firstIndex() 
			{
				return from;
			}

			@property size_t endIndex() 
			{
				return to;
			}

			@property size_t length()
			{
				return to - from;
			}
			
			@property bool empty()
			{
				return to == from;
			}
			
			@property T front() 
			{
				return gbuf[from];
			}
			
			void popFront()
			{
				from++;
			}

			@property T back() 
			{
				return gbuf[to - 1];
			}

			void popBack()
			{
				to--;
			}

			auto opSlice(size_t _from, size_t _to)
			{
				return Range(gbuf, from + _from, from + _to);
			}
		}
		enforceEx!Exception(from <= to, text("From index > to index ", from, " ", to));
		auto r = Range(this, from, to);
		return r;
	}


	T[] toArray(size_t from, size_t to) const pure
	{
		size_t gapSize = gapEnd - gapStart;

		// range is before startGap
		if (to <= gapStart || gapSize == 0)
			return buffer[from..to].dup;
		// range is after endGap
		else if ( from + gapSize >= gapEnd)
			return buffer[(from+gapSize)..(to+gapSize)].dup;

		// range is spanning the gap
		T[] res = buffer[from..gapStart].dup;
		res ~= buffer[gapEnd..to+gapSize];
		return res;
	}

	T[] toArray() const pure nothrow
	{
		T[] res;
		res ~= buffer[0..gapStart];
		res ~= buffer[gapEnd..$];
		return res;
	}
}

/** A line buffer used for keeping an index of the first char in a line
*/
class LineBuffer(T, Text) : GapBuffer!uint
{
	alias T CharType;
	
	private
	{
		uint _lastTextBufferEditPoint;
		Text _text;
	}
	
	/** Signal when a line has been modified

		The argument send with the signal is new line number of the line modified.
	*/
	mixin Signal!(uint) onLineModified;

	/** Signal when a newline has been inserted
		
		The first argument send with the signal is new line number of the 
		first inserted line zero indexed. Second argument is the number of new lines
		following the first line that has been inserted.
	*/
	mixin Signal!(uint,uint) onLinesInserted;

	/** Signal when a newline has been inserted

		The first argument send with the signal is line number of the 
		first removed line zero indexed. Second argument in the number of new lines
		following the first line that has been removed.
	*/
	mixin Signal!(uint,uint) onLinesRemoved;

	this(Text text, size_t initialGapSize)
	{
		super([0], initialGapSize);
		moveEditPointToEnd();
		_lastTextBufferEditPoint = 0;
		_text = text;
	}

	private uint getEditPoint(uint index)
	{
		auto len = length;
		uint curLineIndex = editPoint;
		assert(curLineIndex > 0, "Line index < 1");

		if (index != _lastTextBufferEditPoint)
		{
			// Need to locate the lineIndex for the index.
			while (curLineIndex < len && this[curLineIndex] <= index)
				curLineIndex++;

			while (curLineIndex > 1 && index < this[curLineIndex-1])
				curLineIndex--;
		}
		return curLineIndex;
	}

	void textInserted(const(CharType)[] txt, uint index)
	{		
		if (txt.empty)
			return;
		
		// Scan for new lines '\n' and update lineIndex accordingly
		auto len = length;
		uint curLineIndex = getEditPoint(index);
		
		placeGapStart(curLineIndex);
		auto txtLen = txt.length;

		auto prevNewlineTextBufferIndex = this[curLineIndex - 1];
		bool startLineModified;
		
		{
			bool startsAtStartOfLine = prevNewlineTextBufferIndex == index;

			auto curNewlineTextBufferIndex = curLineIndex < len ? this[curLineIndex] : _text.length;
			bool startsAtEndOfLine = 
				curNewlineTextBufferIndex - 1 == index || 
				curNewlineTextBufferIndex == _text.length ||
				(curNewlineTextBufferIndex - 2 >= 0 && _text[curNewlineTextBufferIndex - 2] == '\r');

			bool firstCharInsertedIsNewline = 
				txt[0] == '\n' || (txt.length > 1 && txt[0] == '\r' && txt[1] == '\n');
			
			startLineModified = !firstCharInsertedIsNewline || !(startsAtStartOfLine || startsAtEndOfLine);
		}
		
		// Correct all line entries after the new inserting to reflect shifted text buffer indexes
		foreach (i; curLineIndex..len)
		{
			auto newVal = this[i] + txtLen;
			this[i] = newVal;		
		}

		uint firstInsertedLineNumber = 0;
		uint linesInserted = 0;

		// Insert any new lines
		for (size_t i = 0; i < txt.length; i++)
		{
		//foreach (i, c; txt)
		//{
			CharType c = txt[i];

			// Force skip of \r in case it is part or \r\n sequence
			if (c == '\r' && txt.length > i + 1 && txt[i+1] == '\n')
			{
				i++;
				c = '\n';
			}

			if (c == '\n')
			{
				auto textBufferIndex = index + i;
				auto lineStartIndex = textBufferIndex + 1;
				
				insert(lineStartIndex);
				
				if (linesInserted == 0)
				{
					
					bool isAtStartOfLine = prevNewlineTextBufferIndex == textBufferIndex;
					firstInsertedLineNumber = isAtStartOfLine ? editPoint - 2 : editPoint - 1;
				}

				linesInserted++;
				// prevNewlineTextBufferIndex = lineStartIndex; // + 1 to get past \n as start of line
			}
		}

		auto endPoint = editPoint;

		_lastTextBufferEditPoint = index + txtLen;

		if (startLineModified)
		{
		    onLineModified.emit(curLineIndex-1); 
		}

		if (linesInserted != 0)
			onLinesInserted.emit(firstInsertedLineNumber, linesInserted);
		
	}

	version (unittest)
	{
		static class SignalRecorder
		{
			string result;
			LineBuffer!(dchar,dstring) lb;
			void onLineModified(uint lineNum)
			{
				result ~= "m" ~ text(lineNum);
			}

			void onLinesInserted(uint lineNum, uint lineCount)
			{
				result ~= "i" ~ text(lineNum, ":", lineCount);
			}

			void onLinesRemoved(uint lineNum, uint lineCount)
			{
				result ~= "r" ~ text(lineNum, ":", lineCount);
			}
		}

		static auto createTestRunner(string baseString)
		{
			auto bs = dtext(baseString);
			auto lb = new LineBuffer!(dchar,dstring)(bs, 40);
			lb.textInserted(bs, 0);
			auto rec = new SignalRecorder();
			rec.lb = lb;
			lb.onLinesInserted.connect(&rec.onLinesInserted);
			lb.onLinesRemoved.connect(&rec.onLinesRemoved);
			lb.onLineModified.connect(&rec.onLineModified);
			return rec;
		}

	}

	unittest
	{
		string base = 
q"(line1
line2
line3)";

		/*
		line1
		line2
		line3
		*/
		auto tr = createTestRunner("");
		tr.lb.textInserted(dtext(base), 0);
		Assert(tr.result, "m0i1:2", "LineBuffer initial lines");

		/*
		insertline1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert"d, 0);
		Assert(tr.result, "m0", "LineBuffer insert at front");

		/*
		liinsertne1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert"d, 2);
		Assert(tr.result, "m0", "LineBuffer insert at front + 2 chars");

		/*
		line1insert
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert"d, 5);
		Assert(tr.result, "m0", "LineBuffer insert at first eol");

		/*
		<blank>
		line1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("\n"d, 0);
		Assert(tr.result, "i0:1", "LineBuffer insert blank newline at front");

		/*
		line1
		insert
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("\ninsert"d, 5);
		Assert(tr.result, "i1:1", "LineBuffer insert newline at end and then insert");

		tr = createTestRunner(base);
		tr.lb.textInserted("insert\n"d, 6);
		Assert(tr.result, "m1i2:1", "LineBuffer insert at start of line 1 and then newline");

		/*
		insert
		line1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert\n"d, 0);
		Assert(tr.result, "m0i1:1", "LineBuffer insert at start of line 0 and then newline");

		/*
		ins
		ertline1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("ins\nert"d, 0);
		Assert(tr.result, "m0i1:1", "LineBuffer insert 'ins\\nert' at start of line 0");

		/*
		liinsert
		ne1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("ins\nert"d, 2);
		Assert(tr.result, "m0i1:1", "LineBuffer insert 'ins\\nert' at mid of line 0");

		/*
		line1
		line2
		liinsert
		ne3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert\n"d, 14);
		Assert(tr.result, "m2i3:1", "LineBuffer insert 'insert\\n' at mid of line 2");

		/*
		line1
		line2
		line3insert
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert"d, 17);
		Assert(tr.result, "m2", "LineBuffer insert 'insert' at end of buffer");

		/*
		line1
		line2
		line3insert
		test
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert\ntest"d, 17);
		Assert(tr.result, "m2i3:1", "LineBuffer insert 'insert\\ntest' at end of buffer");
	}

	void textRemoved(uint begin, uint end)
	{
		if (begin == end)
			return;

		auto len = length;
		uint curLineIndex = getEditPoint(begin);

		auto beginIsFirstCharOnLine = this[curLineIndex - 1] == begin;
		auto endIsAtEndOfBuffer = false; // TODO: get this
		
		uint firstRemovedLineNumber = 0;
		uint linesRemoved = 0;
		
		// Special handling for when remove an entire line. 
		// In that case the line reported to have been removed that line number.
		// All following 
		if (beginIsFirstCharOnLine && 
			((curLineIndex < len && this[curLineIndex] <= end) || endIsAtEndOfBuffer) )
		{
			remove(curLineIndex);
			firstRemovedLineNumber = curLineIndex - 1;
			linesRemoved++;
			len--;
		}

		// Remove deleted new lines indexes
		while (curLineIndex < len && this[curLineIndex] <= end)
		{
			if (linesRemoved == 0)
				firstRemovedLineNumber = beginIsFirstCharOnLine ? curLineIndex - 1 : curLineIndex;
			remove(curLineIndex);
			linesRemoved++;
			len--;
		}

		// Update text buffer indexes
		auto txtLen = end - begin;
		foreach (i; curLineIndex..len)
			this[i] = this[i] - txtLen;

		if (!beginIsFirstCharOnLine || linesRemoved == 0)
				onLineModified.emit(curLineIndex-1);

		if (linesRemoved != 0)
			onLinesRemoved.emit(firstRemovedLineNumber, linesRemoved);
	}

	unittest
	{
		string base = 
			q"(line1
			line2
			line3)";

		/*
		ine1
		line2
		line3
		*/
		auto tr = createTestRunner(base);
		tr.lb.textRemoved(0,1);
		Assert(tr.result, "m0", "LineBuffer remove first char");

		/*
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textRemoved(0,6);
		Assert(tr.result, "r0:1", "LineBuffer remove first line");

		/*
		le1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textRemoved(1,3);
		Assert(tr.result, "m0", "LineBuffer remove second and third char");

		/*
		line1line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textRemoved(5,6);
		Assert(tr.result, "m0r1:1", "LineBuffer remove first newline");

		/*
		lineine2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textRemoved(4,7);
		Assert(tr.result, "m0r1:1", "LineBuffer remove first newline and surrounding chars");

		/*
		line1
		line2
		line
		*/
		tr = createTestRunner(base);
		tr.lb.textRemoved(16,17);
		Assert(tr.result, "m2", "LineBuffer remove last char in buffer");

		/*
		linne3
		*/
		tr = createTestRunner(base);
		tr.lb.textRemoved(3,15);
		Assert(tr.result, "m0r1:2", "LineBuffer remove mid first line to mid last line");
	}
}

enum TextBoundary
{
	chr,
	word,
	line,
	buffer,
}


enum TextBufferAnchorType : byte
{
	none,
	character,
	line,
}

interface TextBufferAnchorOwner
{
}

struct TextBufferAnchor
{
	static uint nextID = 1;
	TextBufferAnchorType type;
	uint id;
	uint number; // zero indexed
	TextBufferAnchorOwner owner;
}

class TextBuffer
{
	alias dchar CharType;
	GapBuffer!CharType gbuffer;
	
	Variant[string] userData;

	// Offsets of first char in lines in gbuffer. For quick navigation by line.
	LineBuffer!(CharType,TextBuffer) lbuffer; 

	// NOTE: make this into gap buffer if performance becomes and issue
	private TextBufferAnchor[] _anchors;

	mixin Signal!(TextBuffer, TextBufferAnchor) onAnchorAdded;

	mixin Signal!(TextBuffer, TextBufferAnchor) onAnchorRemoved;

	this(const(CharType)[] str, size_t initialGapSize)
	{
		gbuffer = new GapBuffer!CharType(str, initialGapSize);
		lbuffer = new LineBuffer!(CharType, TextBuffer)(this, initialGapSize);
		if (!str.empty)
			lbuffer.textInserted(str, 0);

		lbuffer.onLinesInserted.connect(&this.onLinesInserted);
		lbuffer.onLinesRemoved.connect(&this.onLinesRemoved);
	}

	@safe @property length() const pure nothrow
	{
		return gbuffer.length;
	}

	@property CharType[] beforeGap()
	{
		return gbuffer.buffer[0..gbuffer.gapStart];
	}

	@property dchar[] afterGap()
	{
		return gbuffer.buffer[gbuffer.gapEnd..$];
	}

	@property const(dchar)[] lastLine() const
	{
		return gbuffer.toArray(offsetToStartOfLine(length), length);
	}

	@property size_t lineCount() const
	{
		int count = -1;
		uint index = length;
		do
		{	
			index = endOfPreviousLine(index);
			count++;
		} while ( index != 0);
		return count;
	}

	@property size_t charCount() const
	{
		uint lastIdx = 0;
		uint count = 0;
		do 
		{
			uint curIdx = next(lastIdx);
			if (curIdx == lastIdx)
				break;
			lastIdx = curIdx;
			count++;
		}
		while(true);

		return count;
	}

	CharType opIndex(size_t index) const
	{
		return gbuffer.opIndex(index);
	}

	auto opSlice(size_t from, size_t to) const
	{
		return gbuffer.opSlice(from, to);
	}

	void reserve(size_t cap)
	{
		size_t s = gbuffer.length + gbuffer.gapSize;
		if (s < cap)
			gbuffer.ensureGapCapacity(gbuffer.gapSize + (cap - s));
	}

	CharType[] toArray(size_t from, size_t to) const
	{
		return gbuffer.toArray(from, to);
	}

	CharType[] toArray() const pure nothrow
	{
		return gbuffer.toArray();
	}

	bool isNewline(uint index) const 
	{
		dchar c = gbuffer[index]; 
		
		return c == '\r' || (c == '\n' && ( index == 0 || gbuffer[index-1] != '\r') ); 
	}

	uint prev(int index) const
	{
		assert(index <= gbuffer.length);
		index--;
		if (index <= 0) return 0;

		dchar c = gbuffer[index]; 
		
		// Magic to handle \r\n newlines
		// If we landed on a \n and a \r is preceeding the do one more 
		// step to land on the \r.
		// If we landed on a \r the do one more step to land before the \r
		if (index > 0 && 
			((c == '\n' && gbuffer[index-1] == '\r') || c == '\r') )
			index--; // \r\n. eat both
		return index;
	}


	uint next(int index) const
	{
		assert(index >= 0);
		if (index >= gbuffer.length) return gbuffer.length;

		if (gbuffer[index] == '\r')
			index++; // \r\n assumed. eat both.
		index++;
		if (index >= gbuffer.length) return gbuffer.length;
		return index;
	}

	bool isWordChar(int index) const
	{
		return std.algorithm.canFind(WORDCHARS, this[index]);
	}
	

	uint offsetBy(uint index, int count, TextBoundary bound) const
	{
		final switch (bound)
		{
			case TextBoundary.chr:
				return offsetByChar(index, count);
			case TextBoundary.word:
				return offsetByWord(index, count);
			case TextBoundary.line:
				return offsetByLine(index, count);
			case TextBoundary.buffer:
				return count < 0 ? 0 : (count == 0 ? index : length);
		}
	}

	// Return the startIndex moved diff characters taking
	// the clamping on start and end.
	uint offsetByChar(uint startIndex, int diff = 1) const
	{
		while (diff > 0)
		{
			--diff;
			uint idx = next(startIndex);
			if (idx == startIndex)
				break;
			startIndex = idx;			
		}
		while (diff < 0)
		{
			++diff;
			uint idx = prev(startIndex);
			if (idx == startIndex)
				break;
			startIndex = idx;
		}
		return startIndex;
	}

	unittest
	{
		auto b = new TextBuffer("Hello world\r\nHow are you\r\ntoday\nwell"d, 3);
		
		Assert(0, b.offsetByChar(0,0));
		Assert(1, b.offsetByChar(0,1));
		Assert(0, b.offsetByChar(0,0));
		Assert(0, b.offsetByChar(0,-1));

		Assert(11, b.offsetByChar(11,0));
		Assert(13, b.offsetByChar(11,1));
		Assert(10, b.offsetByChar(11,-1));
		Assert(14, b.offsetByChar(11,2));

		Assert(13, b.offsetByChar(12,1));
		Assert(10, b.offsetByChar(12,-1));

		Assert(b.prev(b.length-2), b.offsetByChar(b.charCount,-1));
		Assert(b.charCount, b.charCount);
		Assert(b.length, b.offsetByChar(b.charCount,3));
	}

	// Algorithm like then one used for emacs/sublime. (not like vs)
	// The first char is defined by the direction of offs:
	// offs > 0 means first char is the next char ie. startIndex
	// offs < 0 meacs first char is prev char ie. startIndex-1
	// First all non-words chars are skipped in the direction, 
	// there may be no non-word chars if in the middle of a word.
	// Then all word chars are skipped to find the final result.
	//
	// This will always place the result index at the end of the
	// word when offs > 0 and at the start of the word when offs < 0.
	// This is unlike vs. which always places the result index at the
	// start of the work no matter the direction.
	//
	uint offsetByWord(uint startIndex, int offs = 1) const
	{
		while (offs < 0)
		{
			++offs;
			// Find first word char
			startIndex = findOneOfReverse(prev(startIndex), WORDCHARS);
			if (startIndex == uint.max)
				return 0; // no word char found ie. must be first word in buffer

			// Locate start of word
			startIndex = findOneNotOfReverse(startIndex, WORDCHARS);
			if (startIndex == uint.max)
				return 0; // Cannot find any non word char ie. must be start of buffer
			
			// Correct target because we found the first char before the word start boundary
			startIndex = next(startIndex);
		}

		while (offs > 0)
		{
			--offs;
			// Find first word char
			startIndex = findOneOf(startIndex, WORDCHARS);
			if (startIndex == uint.max)
				return length; // no word char found ie. must be last work in buffer

			startIndex = findOneNotOf(startIndex, WORDCHARS);
			if (startIndex == uint.max)
				return length; // Cannot find any non word char ie. must be end of buffer
		}
		return startIndex;
	}

	unittest
	{
		auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell"d, 3);

		Assert(7, b.offsetByWord(2,1));
		Assert(0, b.offsetByWord(2,-1));
		Assert(14, b.offsetByWord(2,2));

		Assert(14, b.offsetByWord(7,1));
		Assert(2, b.offsetByWord(7,-1));

		Assert(8, b.offsetByWord(14,-1));
		Assert(19, b.offsetByWord(14,1));

		Assert(8, b.offsetByWord(15,-1));
		Assert(19, b.offsetByWord(15,1));

		Assert(b.length, b.offsetByWord(0,7));
		Assert(b.length-5, b.offsetByWord(0,6));
	}

	// Same behavior as offsetByWord but instead or WORDCHARS being the delimiter
	// it is end-of-line charaters.
	uint offsetByLine(uint startIndex, sizediff_t offs = 1) const
	{
		while (offs < 0)
		{
			++offs;

			startIndex = findOneOfReverse(prev(prev(startIndex)), "\n");
			if (startIndex == uint.max)
				return 0; // no newline found ie. must be first line in buffer

			// Correct target because we found the first char before the word start boundary
			startIndex = next(startIndex);
		}

		while (offs > 0 && startIndex < length)
		{
			--offs;
			auto cur = this[startIndex];
			if (cur == '\r' || cur == '\n')
				startIndex = next(startIndex);
				
			startIndex = findOneOf(startIndex, "\r\n");
			if (startIndex == uint.max)
				return length; // Cannot find any non word char ie. must be end of buffer
		}
		return startIndex;
	}

	unittest
	{
		auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell\ndd\nfdsas"d, 3);

		Assert(14, b.offsetByLine(0,1));
		Assert(27, b.offsetByLine(14,1));
		Assert(27, b.offsetByLine(15,1));
		Assert(27, b.offsetByLine(0,2));
		
		Assert(16, b.offsetByLine(27,-1)); 
		Assert(0, b.offsetByLine(27,-2)); 
		Assert(0, b.offsetByLine(26,-2)); 
		Assert(b.length-5, b.offsetByLine(b.length,-1));  
		Assert(b.length-8, b.offsetByLine(b.length,-2));  
	}

	// Return a buffer index obtained by moving 'lines' lines from index using
	// preferredColumn. If preferredColumn is uint.max the column of the index
	// param is used. lines == 0 is a valid input in order to just navigate current line
	// using preferredColumn.
	uint offsetVertically(uint index, sizediff_t lines = 1, uint preferredColumn = uint.max) const
	{
		if (preferredColumn == uint.max)
			preferredColumn = index - offsetToStartOfLine(index);

		uint newPos = index;

		if (lines < 0)
		{
			// locate the char just above the current index
			lines = -lines;
			for (uint i = 0; i < lines; i++)
				newPos = endOfPreviousLine(newPos);

			uint eol = offsetToEndOfLine(newPos);
			newPos = offsetToStartOfLine(newPos) + preferredColumn;
			if (newPos > eol)
				newPos = eol;
		}
		else
		{

			// locate the char just above the current cursor char
			for (uint i = 0; i < lines; i++)
				newPos = startOfNextLine(newPos);

			uint eoline = offsetToEndOfLine(newPos);
			newPos = offsetToStartOfLine(newPos) + preferredColumn;

			if (newPos > eoline)
				newPos = eoline;
		}
		return newPos;
	}

	unittest
	{
		auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\n\nwell\ndd\nfdsas"d, 3);
		Assert(30, b.offsetVertically(0, 3));
	}

	//unittest
	//{
	//    auto b = new TextGapBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell\ndd\nfdsas"d, 3);
	//
	//    Assert(3, b.offsetByLine(21,1));
	//    Assert(34, b.offsetByLine(21,-1)); 
	//    Assert(44, b.offsetByLine(21,4));  // preferred colum not possible next line
	//    Assert(b.length-6, b.offsetByLine(b.length-1,1));  // preferred colum not possible prev line
	//}

	//uint offsetTo(uint index, TextBoundary bound, bool startOfBoundary = true)
	//{
	//    final switch (bound)
	//    {
	//        case TextBoundary.chr:
	//            return offsetToChar(index, startOfBoundary);
	//        case TextBoundary.word:
	//            return offsetToWord(index, startOfBoundary);
	//        case TextBoundary.line:
	//            return offsetToLine(index, startOfBoundary);
	//        case TextBoundary.buffer:
	//            return offsetToBuffer(index, startOfBoundary);
	//    }
	//}
	//
	//uint offsetToChar(uint index, bool startOfBoundary)
	//{
	//    return startOfBoundary ? index : next(index);
	//}
	//
	//uint offsetToWord(uint index, bool startOfBoundary)
	//{
	//    return offsetByWord(index, startOfBoundary ? -1 : 1);
	//}
	//
	//uint offsetToLine(uint index, bool startOfBoundary)
	//{
	//    return offsetByLine(index, startOfBoundary ? -1 : 1, uint.max-1);
	//}

	//unittest
	//{
	//    auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell"d, 3);
	//
	//    Assert(2, b.offsetToWord(0, false));
	//    Assert(6, b.offsetToWord(2, false));
	//
	//    Assert(0, b.offsetToWord(0, true));
	//    Assert(0, b.offsetToWord(2, true));
	//    Assert(2, b.offsetToWord(3, true));
	//    Assert(2, b.offsetToWord(7, true));
	//    Assert(8, b.offsetToWord(8, true));
	//}

	uint offsetToLineBoundary(uint index, bool startOfBoundary) const
	{
		if (startOfBoundary)
		{
			enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));

			if (gbuffer.empty) return 0;

			dchar c = index == gbuffer.length ? 0xFFEF : gbuffer[index];

			// border case where index is at the end of line
			if (index == gbuffer.length || c == '\n' || c == '\r')
			{
				uint newidx = prev(index);
				if (newidx == 0)
					return 0;

				c = gbuffer[newidx];

				// In case it was an empty line we already were at start of line.
				if (c == '\n' || c == '\r')
					return index;
				index = newidx;
			}

			auto r = gbuffer[0u..index];

			// locate the first \n
			size_t i = 0;
			foreach_reverse (v; r)
			{
				if (v == '\n')
					break;
				i++;
			}
			return index - i;
		}
		else // not startOfBoundary
		{
			enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));

			if (index == length)
				return index;

			auto r = gbuffer[index..gbuffer.length];

			// locate the next \n
			size_t i = 0;
			foreach (v; r)
			{
				if (v == '\n')
				{
					if (i > 0 && this[i-1] == '\r')
						i--;
					break;
				}
				i++;
			}

			return index + i;
		}
	}

	uint offsetToBuffer(uint index, bool startOfBoundary)
	{
		if (startOfBoundary)
			return 0;
		else
			return length;
	}

	uint offsetToEndOfLine(uint index) const
	{
		return offsetToLineBoundary(index, false);
	}

	uint offsetToStartOfLine(uint index) const
	{
		return offsetToLineBoundary(index, true);
	}

	/*
	void offset(int count, TextOffset offsetType, uint index = uint.max)
	{
	
	}
*/


	uint startOfNextLine(uint index) const
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		auto r = gbuffer[index..gbuffer.length];

		if (index == length)
			return index;

		uint nc = offsetToEndOfLine(index);

		nc = next(nc);
		return nc;
		//// locate the next \n
		//size_t i = 0;
		//foreach (v; r)
		//{
		//    if (v == '\n')
		//        break;
		//    i++;
		//}
		//
		//i = index + i + 1;
		//if (i >= gbuffer.length)
		//    return gbuffer.length;
		//return i;
	}

	uint endOfPreviousLine(uint index) const
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));		

		uint nc = offsetToStartOfLine(index);
			
		if (nc > 0)
			nc = prev(nc);
		return nc;
	}

	uint lineNumber(uint index) const
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <=sa ", length));		
		
		int count = -1;
		do
		{	
			index = endOfPreviousLine(index);
			count++;
		} while ( index != 0);
		return count;
	}

	uint find(uint index, const(char)[] needle) const
	{
		size_t needleSize = needle.length;
		size_t curEnd = needleSize + index;
		size_t len = length;
		while (curEnd < len && !std.algorithm.equal(this[index..curEnd], needle))
		{
			index++;
			curEnd++;
		}
		return curEnd <= len && std.algorithm.equal(this[index..curEnd], needle) ? index : uint.max;
	}

	enum WORDCHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
	
	uint findOneOf(uint index, const(char)[] needles) const
	{
		size_t len = length;
		
		while (index < len && !std.algorithm.canFind(needles, this[index]))
		{
			index++;
		}
		return index < len ? index : uint.max;
	}
	
	uint findOneNotOf(uint index, const(char)[] needles) const
	{
		size_t len = length;
		
		while (index < len && std.algorithm.canFind(needles, this[index]))
		{
			index++;
		}
		return index < len ? index : uint.max;
	}

	uint findOneOfReverse(uint index, const(char)[] needles) const
	{
		size_t len = length;
		
		while (index < len && index != uint.max && !std.algorithm.canFind(needles, this[index]))
		{
			index--;
		}
		return index != uint.max && index < len ? index : uint.max;
	}

	uint findOneNotOfReverse(uint index, const(char)[] needles) const
	{
		size_t len = length;
		
		while (index < len && index != uint.max && std.algorithm.canFind(needles, this[index]))
		{
			index--;
		}
		return index != uint.max && index < len ? index : uint.max;
	}

	Region regionForLineNumber(uint lineNum)
	{
		if (lbuffer.length > lineNum)
		{
			auto begin = lbuffer[lineNum];
			if (lbuffer.length > (lineNum+1))
				return Region(begin, prev(lbuffer[lineNum+1]));
			else
				return Region(begin, offsetToEndOfLine(begin));
		}
		else
		{
			auto i = lbuffer[lbuffer.length - 1];
			return Region(i, offsetToEndOfLine(i));
		}
	}

	uint lineNumberAt(uint index) const
	{
		uint curLine = 0;
		uint i = 0;
		do 
		{
			i = startOfNextLine(i);
			if (index < i)
				break;
			curLine++;
		} 
		while (i != length);
		return curLine;
	}

	uint startAtLineNumberScan(uint lineNum) const
	{
		uint curLine = 0;
		uint i = 0;
		do 
		{
			if (curLine == lineNum)
				return i;
			i = startOfNextLine(i);
			curLine++;
		}
		while (i != length);
		return offsetToStartOfLine(i);
	}

	uint startAtLineNumber(uint lineNum) const
	{
		if (lbuffer.length > lineNum)
			return lbuffer[lineNum];
		else
			return lbuffer[lbuffer.length - 1];
	}

	uint endAtLineNumber(uint lineNum) const
	{
		lineNum++;
		uint idx = 0;
		if (lbuffer.length > lineNum)
			idx = lbuffer[lineNum];
		else
			return length;
		return prev(idx);
	}

	auto lineEndsAt(uint index) const
	{
		return tuple(offsetToStartOfLine(index), offsetToEndOfLine(index));
	}

	auto lineEndsAtLineNumber(uint lineNum) const
	{
		auto start = startAtLineNumber(lineNum);
		return tuple(start, offsetToEndOfLine(start));
	}

	const(dchar)[] lineContaining(uint index) const
	{
		auto ends = lineEndsAt(index);
		return gbuffer.toArray(ends[0], ends[1]);
	}
	
	const(dchar)[] lineString(uint lineNumber) const
	{
		return gbuffer.toArray(startAtLineNumber(lineNumber), 
							   endAtLineNumber(lineNumber));
	}

	///
	/// Mutating methods below
	///

	void insert(const(CharType)[] items, uint index = uint.max)
	{
		index = index == uint.max ? gbuffer.editPoint : index;
		gbuffer.insert(items, index);
		lbuffer.textInserted(items, index);
	}

	unittest
	{
		class LineListener
		{
			uint[] expect;
			int nextIdx;

			void onLinesInserted(uint lineNum, uint lineCount)
			{
				Assert(lineNum, expect[nextIdx*2], "Line num match test " ~ to!string(nextIdx));
				Assert(lineCount, expect[nextIdx*2+1], "Line num match test " ~ to!string(nextIdx));
				nextIdx++;
			}
		}
		
		auto ll = new LineListener;
		ll.expect = [ 
			0, 1,
			1, 1,
			0, 1,
			3, 1,
			4, 1, 
			6, 1,
			7, 3,
		];
		
		TextBuffer b1 = new TextBuffer(""d, 40);
		b1.lbuffer.onLinesInserted.connect(&ll.onLinesInserted);
		
		Assert(b1.lbuffer.editPoint, 1, "Line editpoint is initially 1");
		Assert(b1.lbuffer.length, 1, "Line len is initially 1");

		b1.insert("\n");
		Assert(b1.lbuffer.editPoint, 2, "Line editpoint is 2 after inserting lf");
		Assert(b1.lbuffer.length, 2, "Line len is 2");

		b1.insert("\n");
		Assert(b1.lbuffer.editPoint, 3, "Line editpoint is 3 after inserting lf");
		Assert(b1.lbuffer.length, 3, "Line len is 3");

		b1.insert("\n", 0);
		Assert(b1.lbuffer.editPoint, 2, "Line editpoint is 2 after inserting lf at beginning");
		Assert(b1.lbuffer.length, 4, "Line len is 4");

		b1.insert("\n", 3);
		Assert(b1.lbuffer.editPoint, 5, "Line editpoint is 5 after inserting lf after third lf");
		Assert(b1.lbuffer.length, 5, "Line len is 5");

		b1.insert("\n", b1.length);
		Assert(b1.lbuffer.editPoint, 6, "Line editpoint is 6 after inserting lf at end");
		Assert(b1.lbuffer.length, 6, "Line len is 6");

		b1.insert("foobar", b1.length);
		b1.insert("\n", b1.length);
		Assert(b1.lbuffer.editPoint, 7, "Line editpoint is 7 after inserting lf after text at end");
		Assert(b1.lbuffer.length, 7, "Line len is 7");

		b1.insert("one\ntwo\nthree\n", b1.length);
		Assert(b1.lbuffer.editPoint, 10, "Line editpoint is 10 after inserting 3 text and lf at end");
		Assert(b1.lbuffer.length, 10, "Line len is 10");


		TextBuffer b = new TextBuffer(""d, 40);		
		b.insert("one");
		Assert(b.lbuffer.editPoint, 1, "Line editpoint is 0 after non-lf string");
		// Assert(b.lbuffer[b.lbuffer.editPoint], 0, "Line editpoint value is 0 after non-lf string");
		b.insert("two\nthree");
		Assert(b.lbuffer.editPoint, 2, "Line editpoint is 1 after lf string");
		Assert(b.lbuffer.length, 2, "Line editpoint length is 2 after lf string");
	}

	// Remove count characters from the buffers starting at index 
	// If count is negative the characters are moved backwards
	void remove(int count, uint index)
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " < ", length));

		if (count > 0)
		{
			while (count--)
			{
				uint idx = next(index);

				uint diff = idx - index;
				if (diff == 0)
					break;

				lbuffer.textRemoved(index, index + diff);

				while (diff--)
					gbuffer.remove(index);
			}
		}
		else if (count < 0)
		{
			while (count++)
			{
				uint idx = prev(index);
				uint diff = index - idx;
				if (diff == 0)
					break;
				index -= diff;

				lbuffer.textRemoved(index, index + diff);

				while (diff--)
					gbuffer.remove(index);
			}
		}
	}

	void removeRange(uint start, uint end)
	{
		enforceEx!Exception(start >= 0 && start <= end && end <= length, text("Index out of bounds 0 <= ", start , " <= ", end, " <= ", length));
		auto idx = start;
		while (idx++ < end)
			gbuffer.remove(start);
		lbuffer.textRemoved(start, end);
	}

	unittest
	{
		class LineListener
		{
			uint[] expect;
			int nextIdx;

			void onLinesRemoved(uint lineNum, uint lineCount)
			{
				Assert(lineNum, expect[nextIdx*2], "Line num match test " ~ to!string(nextIdx));
				Assert(lineCount, expect[nextIdx*2+1], "Line count match test " ~ to!string(nextIdx));
				nextIdx++;
			}
		}

		auto ll = new LineListener;
		ll.expect = [ 
			0, 1,
			2, 1,
			2, 2,
		];

		TextBuffer b1 = new TextBuffer(""d, 40);
		b1.lbuffer.onLinesRemoved.connect(&ll.onLinesRemoved);

		b1.insert("\nSecond line\nThird line\nFourth line\n");
		Assert(b1.lbuffer.editPoint, 5, "Line editpoint is 5 after inserting 4 x text+lf : " ~ b1.toArray().replace("\n", r"\n").to!string);
		Assert(b1.lbuffer.length, 5, "Line len is 5");

		// remove "\n"
		b1.removeRange(0,1);
		Assert(b1.lbuffer.editPoint, 1, "Line editpoint is 1 after removing 1st lf : " ~ b1.toArray().replace("\n", r"\n").to!string);
		Assert(b1.lbuffer.length, 4, "Line len is 4");

		// remove "Se"
		b1.removeRange(0,2);
		Assert(b1.lbuffer.editPoint, 1, "Line editpoint is 1 after removing 2 chars : " ~ b1.toArray().replace("\n", r"\n").to!string);
		Assert(b1.lbuffer.length, 4, "Line len is 4");

		// remove "cond line"
		b1.removeRange(0, 9);
		Assert(b1.lbuffer.editPoint, 1, "Line editpoint is 1 after removing chars until newline : " ~ b1.toArray().replace("\n", r"\n").to!string);
		Assert(b1.lbuffer.length, 4, "Line len is 4");

		// remove "hird line\nFourt"
		b1.removeRange(2, 17);
		Assert(b1.lbuffer.editPoint, 2, "Line editpoint is 2 after removing chars and until newline and then some chars : " ~ b1.toArray().replace("\n", r"\n").to!string);
		Assert(b1.lbuffer.length, 3, "Line len is 3");

		b1.insert("Fifth line\nSixth Line\nSeventh line", b1.length);
		
		// remove "\nTh line\nFifth line\nSixth L"
		b1.removeRange(2, 27);
		Assert(b1.lbuffer.editPoint, 2, "Line editpoint is 2 after inserting and removing : " ~ b1.toArray().replace("\n", r"\n").to!string);
		Assert(b1.lbuffer.length, 3, "Line len is 3");
	}

	// TODO: Use more performant container for line info supporting quick lookups etc.
	auto getLineAnchor(uint lineNumber, TextBufferAnchorOwner owner = null)
	{
		bool ownerIsNull = owner is null;
		foreach (ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line && 
				lineNumber == info.number && 
				(ownerIsNull || owner is info.owner))
				return info;
		}
		return TextBufferAnchor(TextBufferAnchorType.none, uint.max);
	}

	auto createLineAnchor(uint lineNumber, TextBufferAnchorOwner owner = null)
	{
		auto id = TextBufferAnchor.nextID++;
		auto a = TextBufferAnchor(TextBufferAnchorType.line, id, lineNumber, owner);
		_anchors ~= a;
		onAnchorAdded.emit(this, a);
		return a;
	}

	auto ensureLineAnchor(uint lineNumber, TextBufferAnchorOwner owner = null)
	{
		auto la = getLineAnchor(lineNumber, owner);
		if (la.id != uint.max)
			return la;
		return createLineAnchor(lineNumber, owner);
	}

	void removeLineAnchorByID(uint lineAnchorID)
	{
		foreach (i, ref info; _anchors)
		{
			if (info.id == lineAnchorID)
			{
				info = _anchors[$-1];
				_anchors.length = _anchors.length-1;
				return;
			}
		}	
	}

	void removeLineAnchorByLine(uint lineNumber, TextBufferAnchorOwner owner = null)
	{
		bool ownerIsNull = owner is null;
		foreach (ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line && 
				lineNumber == info.number && 
				(ownerIsNull || owner is info.owner))
			{
				info = _anchors[$-1];
				_anchors.length = _anchors.length-1;
				return;
			}
		}
	}

	TextBufferAnchor[] getAnchorsForLines(uint lineOffset, uint visibleLineCount)
	{
		auto res = appender!(TextBufferAnchor[]);
		auto endLine = lineOffset + visibleLineCount;
		foreach (ref info; _anchors)
		{
			if (info.number >= lineOffset && info.number < endLine)
				res.put(info);
		}
		return res.data;
	}

	bool hasAnchors() const
	{
		return !_anchors.empty;
	}

	private void onLinesInserted(uint lineNumber, uint lineCount)
	{
		foreach (ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line && info.number >= lineNumber)
				info.number += lineCount;
		}
	}

	private void onLinesRemoved(uint lineNumber, uint lineCount)
	{
		foreach (ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line && info.number >= lineNumber)
			{
				if (info.number - lineCount < lineNumber)
				{
					onAnchorRemoved.emit(this, info);
					info.number = uint.max; // TODO: bad... fix
				}
				else
				{
					info.number -= lineCount;
				}
			}
		}
	}
}
