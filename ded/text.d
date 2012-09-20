module text;

import std.algorithm;
import std.exception;
import std.range;
import std.conv;

class GapBuffer(T = dchar)
{
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

	@property length() const  
	{
		return buffer.length - (gapEnd - gapStart);
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
	
	
	
	
	private void ensureGapCapacity(uint size)
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
				this.to = t;				
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
		}
		enforceEx!Exception(from <= to, "From index > to index");
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
	
	@property size_t lineCount() 
	{
		int count = -1;
		uint index = 0;
		do
		{	
			index = endOfPreviousLine(index);
			count++;
		} while ( index != 0);
		return count;
	}
	
	void remove(int count, int index = uint.max)
	{
		enforceEx!Exception(index >= 0 && index < length, text("Index out of bounds 0 <= ", index , " < ", length));
		
		// TODO: optimize
		int d = count > 0 ? 1 : -1;
		int at = index;
		if (d < 0) 
		{
			at--;
			count = -count;
		}
		
		for (int i = 0; i < count; i++)
		{
			if (at >= gbuffer.length || at < 0)
				break; // done
			gbuffer.remove(at);
			//at += d;
		}
	}

	uint charsOffset(uint startIndex, sizediff_t diff)
	{
		if (diff < 0)
		{
			if (startIndex >= -diff) 
				return startIndex + diff;
			else
				return 0;
		}
		startIndex += diff;
		if (startIndex > buffer.length)
			return buffer.length;
		return startIndex;
	}

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
		
		if (newPos > buffer.length)
			newPos = buffer.length;
		else if (newPos > eol)
			newPos = eol;
		return newPos;
	}
	
	uint startOfLine(uint index)   
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		
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
		
		auto r = gbuffer[index..gbuffer.length];
		
		// locate the next \n
		size_t i = 0;
		foreach (v; r)
		{
			if (v == '\n' || v == '\r')
				break;
			i++;
		}
		
		return index + i;
	}
	
	uint startOfNextLine(uint index)   
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		auto r = gbuffer[index..gbuffer.length];
		
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
		
		auto r = gbuffer[0..index];
		
		// locate the next \n
		size_t i = 0;
		foreach_reverse (v; r)
		{
			i++;
			if (v == '\n')
				break;
		}
		
		uint nc = index - i;
		if (nc > 0 && gbuffer[nc-1] == '\r')
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

