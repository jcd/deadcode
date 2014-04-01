module core.buffer;

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.typecons;


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

	@safe @property length() const nothrow 
	{
		return buffer.length - (gapEnd - gapStart);
	}
		
	@safe @property empty() const nothrow 
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
			// Move wchars from before gap to end of gap thereby creating a gap a index.
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
			// Move wchars from after gap to beginning of gap thereby creating a gap a index.
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
			index = gapStart - 1;
		enforceEx!Exception(index >= 0 && index < length, text("Index out of bounds 0 <= ", index , " < ", length));
		placeGapStart(index);
		buffer[gapEnd] = T.init;
		gapEnd++;
	}
	
	void reset(T[])
	{
		
	}
	
	T opIndex(size_t index) const
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

	auto opSlice(size_t from, size_t to) const
	{
		static struct Range
		{
			private 
			{
				const(GapBuffer!T) gbuf;
				size_t from;
				size_t to;
			}
			
			this(const(GapBuffer!T) gbuf, size_t f, size_t t)
			{
				assert(t <= gbuf.length);
				assert(f <= t);
				this.gbuf = gbuf;
				this.from = f;
				this.to = t > gbuf.length ? gbuf.length : t;				
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


	T[] toArray(size_t from, size_t to) const
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

	T[] toArray()
	{
		T[] res;
		res ~= buffer[0..gapStart];
		res ~= buffer[gapEnd..$];
		return res;
	}
}

enum TextBoundary
{
	chr,
	word,
	line,
	buffer,
}

class TextGapBuffer
{
	GapBuffer!dchar gbuffer;
	alias gbuffer this;
	
	this(const(dchar)[] str, size_t initialGapSize)
	{
		gbuffer = new GapBuffer!dchar(str, initialGapSize);
	}

	@property dchar[] beforeGap()
	{
		return gbuffer.buffer[0..gbuffer.gapStart];
	}

	@property dchar[] afterGap()
	{
		return gbuffer.buffer[gbuffer.gapEnd..$];
	}

	@property const(dchar)[] lastLine() const
	{
		return toArray(offsetToStartOfLine(length), length);
	}

	@property size_t lineCount() 
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

	@property size_t charCount() 
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

	uint prev(int index) const
	{
		assert(index <= gbuffer.length);
		index--;
		if (index <= 0) return 0;

		dchar c = gbuffer[index]; 
		
		// Magic to handle \r\n newlines
		// If we landed on a \n and a \r is preceeding the do one more 
		// step to land on the \r.
		// If we landed on a \n the do one more step to land before the \r
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

	bool isWordChar(int index)
	{
		return std.algorithm.canFind(WORDCHARS, this[index]);
	}
	

	uint offsetBy(uint index, int count, TextBoundary bound)
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
	uint offsetByChar(uint startIndex, int diff = 1)
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
		auto b = new TextGapBuffer("Hello world\r\nHow are you\r\ntoday\nwell"d, 3);
		
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
	uint offsetByWord(uint startIndex, int offs = 1)
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
		auto b = new TextGapBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell"d, 3);

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
		auto b = new TextGapBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell\ndd\nfdsas"d, 3);

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
		auto b = new TextGapBuffer("  Hello woerld\r\nHow are you\r\n\nwell\ndd\nfdsas"d, 3);
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
	//    auto b = new TextGapBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell"d, 3);
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
				while (diff--) // TODO: optimize this because it moves the gap all the time
				{
					index--;
					gbuffer.remove(index);
				}
			}
		}
	}

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

	uint lineNumberAt(uint index)
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

	uint startAtLineNumber(uint lineNum) const
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
		return toArray(ends[0], ends[1]);
	}

}
