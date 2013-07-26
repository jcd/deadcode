module buffer;

import std.algorithm;
import std.conv;
import std.exception;
import std.range;

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

	auto opSlice(size_t from, size_t to) 
	{
		static struct Range
		{
			private 
			{
				GapBuffer!T gbuf;
				size_t from;
				size_t to;
			}
			
			this(GapBuffer!T gbuf, size_t f, size_t t)
			{
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
	
	T[] toArray()
	{
		T[] res;
		res ~= buffer[0..gapStart];
		res ~= buffer[gapEnd..$];
		return res;
	}
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

	uint prev(int index)
	{
		assert(index <= gbuffer.length);
		index--;
		if (index <= 0) return 0;

		dchar c = gbuffer[index]; 
		if (c == '\r')
			index--;
		return index;
	}


	uint next(int index)
	{
		assert(index >= 0);
		index++;
		if (index >= gbuffer.length) return gbuffer.length;

		dchar c = gbuffer[index]; 
		if (c == '\r')
			index++;
		return index;
	}


	// Remove count characters from the buffers starting at index 
	// If count is negative the characters are moved backwards
	void remove(int count, int index = uint.max)
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

	// Return the startIndex moved diff characters taking
	// the clamping on start and end.
	uint charsOffset(uint startIndex, sizediff_t diff)
	{
		if (diff > 0)
		{
			while (diff--)
			{
				uint idx = next(startIndex);
				if (idx == startIndex)
					break;
				startIndex = idx;
			}
		}
		else if (diff < 0)
		{
			while (diff++)
			{
				uint idx = prev(startIndex);
				if (idx == startIndex)
					break;
				startIndex = idx;
			}
		}
		return startIndex;
	}

	// Return a buffer index obtained by moving 'lines' lines from index using
	// preferredColumn. If preferredColumn is uint.max the column of the index
	// param is used.
	uint linesOffset(uint index, sizediff_t lines = 1, uint preferredColumn = uint.max)
	{
		if (preferredColumn == uint.max)
			preferredColumn = index - startOfLine(index);
		
		uint newPos = index;
		
		if (lines < 0)
		{
			// locate the char just above the current index
			lines = -lines;
			for (uint i = 0; i < lines; i++)
				newPos = endOfPreviousLine(newPos);
		
			uint eol = endOfLine(newPos);
			newPos = startOfLine(newPos) + preferredColumn;
			if (newPos > eol)
				newPos = eol;
			return newPos;
		}
		
		// locate the char just above the current cursor char
		for (uint i = 0; i < lines; i++)
			newPos = startOfNextLine(newPos);
		
		uint eol = endOfLine(newPos);
		newPos = startOfLine(newPos) + preferredColumn;
		
		if (newPos > gbuffer.length)
			newPos = gbuffer.length;
		else if (newPos > eol)
			newPos = eol;
		return newPos;
	}
	
	uint startOfLine(uint index)   
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		
		if (gbuffer.empty) return 0;
		
		if (index == gbuffer.length)
		{
			index--;
			if (index == 0)
				return 0;
		}
		
		// border case where index is at the end of line
		if (gbuffer[index] == '\n')
		{
			index--;
			if (index == 0)
				return 0;
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
	
	uint endOfLine(uint index)   
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
				break;
			i++;
		}
		
		return index + i;
	}
	
	uint startOfNextLine(uint index)   
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		auto r = gbuffer[index..gbuffer.length];

		if (index == length)
			return index;

		// locate the next \n
		size_t i = 0;
		foreach (v; r)
		{
			if (v == '\n')
				break;
			i++;
		}
		
		i = index + i + 1;
		if (i >= gbuffer.length)
			return gbuffer.length;
		return i;
	}

	uint endOfPreviousLine(uint index)   
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));		

		uint nc = startOfLine(index);
			
		if (nc > 0)
			nc--;
		return nc;
	}

	uint lineNumber(uint index) 
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

	uint find(uint index, const(char)[] needle)
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

	static WORDCHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
	
	uint findOneOf(uint index, const(char)[] needles)
	{
		size_t len = length;
		
		while (index < len && !std.algorithm.canFind(needles, this[index]))
		{
			index++;
		}
		return index < len ? index : uint.max;
	}
	
	uint findOneNotOf(uint index, const(char)[] needles)
	{
		size_t len = length;
		
		while (index < len && std.algorithm.canFind(needles, this[index]))
		{
			index++;
		}
		return index < len ? index : uint.max;
	}

	uint findOneOfReverse(uint index, const(char)[] needles)
	{
		size_t len = length;
		
		while (index != uint.max && !std.algorithm.canFind(needles, this[index]))
		{
			index--;
		}
		return index != uint.max ? index : uint.max;
	}

	uint findOneNotOfReverse(uint index, const(char)[] needles)
	{
		size_t len = length;
		
		while (index != uint.max && std.algorithm.canFind(needles, this[index]))
		{
			index--;
		}
		return index != uint.max ? index : uint.max;
	}
}
