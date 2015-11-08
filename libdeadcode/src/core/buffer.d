module core.buffer;

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.typecons;
import core.signals;
import std.variant;
import math.region;

import test;
mixin registerUnittests;

enum InvalidIndex = int.min;

class GapBuffer(T)
{
	alias T CharType;
	private
	{
		int gapStart;
		int gapEnd;
		int gapDefaultSize;
		T[] buffer;
	}

	this(const T[] txt, int gapSize = 40)
	{
		clear(txt, gapSize);
	}

	void clear(const T[] txt = null, int gapSize = 40)
	{
		gapStart = 0;
		gapEnd = gapSize;
		gapDefaultSize = gapSize;
		buffer.length = txt.length + gapDefaultSize;
		static if (T.sizeof == 1)
            copy(cast(ubyte[])(txt)[], cast(ubyte[])(buffer)[gapEnd..$]);
        else
            copy(txt[], buffer[gapEnd..$]);
	}

	@property int editPoint() const pure nothrow
	{
		return gapStart;
	}

	@safe @property int length() const pure nothrow
	{
		return cast(int)buffer.length - (gapEnd - gapStart);
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

	private void placeGapStart(int index)
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

			static if ( T.sizeof == 1 )
            {
                copy(retro(cast(ubyte[])(buffer)[index..gapStart]), retro(cast(ubyte[])(buffer)[gapEnd-count..gapEnd]));
			}
            else
            {
                copy(retro(buffer[index..gapStart]), retro(buffer[gapEnd-count..gapEnd]));
            }
            gapStart = index;
			gapEnd -= count;
			// Clear gap
			buffer[index..index+deltaCount] = T.init;
		}
		else
		{
			// Move wchars from after gap to beginning of gap thereby creating a gap at index.
			auto count = index - gapStart;
			auto gapSize = gapEnd - gapStart;
			auto deltaIndex =  index > gapEnd ? index : gapEnd;
			static if ( T.sizeof == 1 )
            {
                copy(cast(ubyte[])(buffer)[gapEnd..gapEnd+count], cast(ubyte[])(buffer)[gapStart..gapStart+count]);
			}
            else
            {
                copy(buffer[gapEnd..gapEnd+count], buffer[gapStart..gapStart+count]);
            }
            gapStart += count;
			gapEnd += count;

			buffer[deltaIndex..gapEnd] = T.init;
		}
	}

	unittest
	{
		/*
		auto b = new GapBuffer("12345", 3);
		dchar[8] a;
		std.algorithm.fill(a, dchar.init);
		a[3..$] = "12345";
		assert(std.algorithm.equal(b.buffer, a));

		b.placeGapStart(1);
		a[3] = dchar.init;
		a[0] = '1';
		assert(std.algorithm.equal(b.buffer, a));
		 */
	}

	void ensureGapCapacity(int size)
	{
		size_t gapSize = gapEnd - gapStart;
		if (gapSize >= size) return;

		// A resize is necessary which mean a new allocation and copy of existing content.
		// Since this should be done rarely we allocate more that needed.
		// D's built in arrays automatically reallocates and copies so we just use that
		// functionallity
		size_t deltaSize = size - gapSize;
		buffer.length = buffer.length + deltaSize; // make roomfd
		static if (T.sizeof == 1)
            copy(retro(cast(ubyte[])(buffer)[gapEnd..$-deltaSize]), retro(cast(ubyte[])(buffer)[gapEnd+deltaSize..$]));
        else
            copy(retro(buffer[gapEnd..$-deltaSize]), retro(buffer[gapEnd+deltaSize..$]));
		gapEnd += deltaSize;
	}

	void insert(T item, int index = InvalidIndex)
	{
		if (index == InvalidIndex)
			index = gapStart;
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		placeGapStart(index);
		ensureGapCapacity(1);
		buffer[index] = item;
		gapStart++;
	}

	void insert(const(T)[] items, int index = InvalidIndex)
	{
		if (index == InvalidIndex)
			index = gapStart;
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));
		placeGapStart(index);
		ensureGapCapacity(cast(int)items.length);
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
	void remove(int index = InvalidIndex)
	{
		if (index == InvalidIndex)
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
                //if (t > gbuf.length)
                //{
                //    f = t;
                //}
                assert(t <= gbuf.length, text(t, " <= ", gbuf.length));
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

            void popFrontN(int n)
            {
                from += n;
            }

			@property T back()
			{
				return gbuf[to - 1];
			}

			void popBack()
			{
				to--;
			}

            Range save() const pure nothrow
            {
                return this;
            }

			T opIndex(size_t index) const pure
			{
				return gbuf[from+index];
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


	T[] toArray(int from, int to) const pure
	{
		int gapSize = gapEnd - gapStart;

		// range is before startGap
		if (to <= gapStart || gapSize == 0)
		{
			int clampTo = min(to, buffer.length);
			return buffer[from..clampTo].dup;
		}

		// sanitize
        int end = int.max - gapSize <= to ? cast(int)buffer.length : to+gapSize;

		// range is after endGap
		if ( from + gapSize >= gapEnd)
			return buffer[(from+gapSize)..end].dup;

		// range is spanning the gap
		T[] res = buffer[from..gapStart].dup;
		res ~= buffer[gapEnd..end];
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
class LineBuffer(T, Text) : GapBuffer!int
{
	alias T CharType;

	private
	{
		int _lastTextBufferEditPoint;
		Text _text;
	}

	/** Signal when a line has been modified

		The argument send with the signal is new line number of the line modified.
	*/
	mixin Signal!(int) onLineModified;

	/** Signal when a newline has been inserted

		The first argument send with the signal is new line number of the
		first inserted line zero indexed. Second argument is the number of new lines
		following the first line that has been inserted.
	*/
	mixin Signal!(int,int) onLinesInserted;

	/** Signal when a newline has been inserted

		The first argument send with the signal is line number of the
		first removed line zero indexed. Second argument in the number of new lines
		following the first line that has been removed.
	*/
	mixin Signal!(int,int) onLinesRemoved;

	this(Text text, size_t initialGapSize)
	{
            super([0], cast(int)initialGapSize);
		moveEditPointToEnd();
		_lastTextBufferEditPoint = 0;
		_text = text;
	}

	private int getEditPoint(int index)
	{
		auto len = length;
		int curLineIndex = editPoint;
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

	void textInserted(const(CharType)[] txt, int index)
	{
		if (txt.empty)
			return;

		// Scan for new lines '\n' and update lineIndex accordingly
		auto len = length;
		int curLineIndex = getEditPoint(index);

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
                        auto newVal = this[i] + cast(int)txtLen;
			this[i] = newVal;
		}

		int firstInsertedLineNumber = 0;
		int linesInserted = 0;

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

				insert(cast(int)lineStartIndex);

				if (linesInserted == 0)
				{

					bool isAtStartOfLine = prevNewlineTextBufferIndex == textBufferIndex;
					firstInsertedLineNumber = cast(int)(isAtStartOfLine ? editPoint - 2 : editPoint - 1);
				}

				linesInserted++;
				// prevNewlineTextBufferIndex = lineStartIndex; // + 1 to get past \n as start of line
			}
		}

		auto endPoint = editPoint;

		_lastTextBufferEditPoint = cast(int)(index + txtLen);

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
			LineBuffer!(char,string) lb;
			void onLineModified(int lineNum)
			{
				result ~= "m" ~ text(lineNum);
			}

			void onLinesInserted(int lineNum, int lineCount)
			{
				result ~= "i" ~ text(lineNum, ":", lineCount);
			}

			void onLinesRemoved(int lineNum, int lineCount)
			{
				result ~= "r" ~ text(lineNum, ":", lineCount);
			}
		}

		static auto createTestRunner(string baseString)
		{
			auto bs = text(baseString);
			auto lb = new LineBuffer!(char,string)(bs, 40);
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
		tr.lb.textInserted(text(base), 0);
		Assert(tr.result, "m0i1:2", "LineBuffer initial lines");

		/*
		insertline1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert", 0);
		Assert(tr.result, "m0", "LineBuffer insert at front");

		/*
		liinsertne1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert", 2);
		Assert(tr.result, "m0", "LineBuffer insert at front + 2 chars");

		/*
		line1insert
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert", 5);
		Assert(tr.result, "m0", "LineBuffer insert at first eol");

		/*
		<blank>
		line1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("\n", 0);
		Assert(tr.result, "i0:1", "LineBuffer insert blank newline at front");

		/*
		line1
		insert
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("\ninsert", 5);
		Assert(tr.result, "i1:1", "LineBuffer insert newline at end and then insert");

		tr = createTestRunner(base);
		tr.lb.textInserted("insert\n", 6);
		Assert(tr.result, "m1i2:1", "LineBuffer insert at start of line 1 and then newline");

		/*
		insert
		line1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert\n", 0);
		Assert(tr.result, "m0i1:1", "LineBuffer insert at start of line 0 and then newline");

		/*
		ins
		ertline1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("ins\nert", 0);
		Assert(tr.result, "m0i1:1", "LineBuffer insert 'ins\\nert' at start of line 0");

		/*
		liinsert
		ne1
		line2
		line3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("ins\nert", 2);
		Assert(tr.result, "m0i1:1", "LineBuffer insert 'ins\\nert' at mid of line 0");

		/*
		line1
		line2
		liinsert
		ne3
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert\n", 14);
		Assert(tr.result, "m2i3:1", "LineBuffer insert 'insert\\n' at mid of line 2");

		/*
		line1
		line2
		line3insert
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert", 17);
		Assert(tr.result, "m2", "LineBuffer insert 'insert' at end of buffer");

		/*
		line1
		line2
		line3insert
		test
		*/
		tr = createTestRunner(base);
		tr.lb.textInserted("insert\ntest", 17);
		Assert(tr.result, "m2i3:1", "LineBuffer insert 'insert\\ntest' at end of buffer");
	}

	void textRemoved(int begin, int end)
	{
		if (begin == end)
			return;

		auto len = length;
		int curLineIndex = getEditPoint(begin);

		auto beginIsFirstCharOnLine = this[curLineIndex - 1] == begin;
		auto endIsAtEndOfBuffer = false; // TODO: get this

		int firstRemovedLineNumber = 0;
		int linesRemoved = 0;

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
	unit = 1,
	chr  = 2^^1,
	wordBegin = 2^^2,
	wordEnd = 2^^3,
	punctuationBegin = 2^^4,
	punctuationEnd = 2^^5,
	lineBegin = 2^^6,
	lineEnd = 2^^7,
	buffer = 2^^8,
	bufferBegin = 2^^9,
	bufferEnd = 2^^10,
	emptyLine = 2^^11,
}

enum TextBoundaryStrength
{
	hard,
	soft
}

enum TextBufferAnchorType : byte
{
	none,
	character,
	line,
}

interface ITextBufferAnchorOwner
{
}

enum InvalidAnchorID = -1;

struct TextBufferAnchor
{
	static int nextID = 1;
	TextBufferAnchorType type;
	int id;
	int number; // zero indexed
	ITextBufferAnchorOwner owner;
}

class TextBuffer
{
	private int _id;
    private static int _nextID = 1;

    alias char CharType;
	GapBuffer!CharType gbuffer;

	Variant[string] userData;

	bool isPersistant = false;

	// Offsets of first char in lines in gbuffer. For quick navigation by line.
	LineBuffer!(CharType,TextBuffer) lbuffer;

	// NOTE: make this into gap buffer if performance becomes and issue
	private TextBufferAnchor[] _anchors;

	mixin Signal!(TextBuffer, TextBufferAnchor) onAnchorAdded;

	mixin Signal!(TextBuffer, TextBufferAnchor) onAnchorRemoved;

    // onInsert.emit(buffer, index, count, inserted == true | deleted == false)
    mixin Signal!(TextBuffer, int, int, bool) onChanged;

final:

    @property int id() const pure nothrow @safe
    {
        return _id;
    }

	this(const(CharType)[] str, size_t initialGapSize)
	{
	    _id = _nextID++;
            gbuffer = new GapBuffer!CharType(str, cast(int)initialGapSize);
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

	@property CharType[] afterGap()
	{
		return gbuffer.buffer[gbuffer.gapEnd..$];
	}

	@property const(CharType)[] lastLine() const
	{
            return gbuffer.toArray(offsetToBeginningOfLine(length), length);
	}

	debug @property int lineCountScanned() const
	{
		int count = -1;
		int index = length;
		do
		{
			index = endOfPreviousLine(index);
			count++;
		} while ( index != 0);
		return count;
	}

    @property int lineCount() const
	{
		return lbuffer.length;
	}

	@property int charCount() const
	{
		int lastIdx = 0;
		int count = 0;
		do
		{
			int curIdx = next(lastIdx);
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
                    gbuffer.ensureGapCapacity(gbuffer.gapSize + cast(int)(cap - s));
	}

	CharType[] toArray(size_t from, size_t to) const
	{
            return gbuffer.toArray(cast(int)from, cast(int)to);
	}

	CharType[] toArray() const pure nothrow
	{
		return gbuffer.toArray();
	}

	int prev(int index, bool clamp = true) const
	{
        import std.utf;

        int len = gbuffer.length;
        assert(index <= len);
		if (index > len)
            return clamp ? len : InvalidIndex;
        else if (index == 0)
            return clamp ? 0 : InvalidIndex;

        // index--;
        import std.traits;
        try
        {
		    index -= strideBack(gbuffer[0..index]);
        }
        catch (UTFException e)
        {
            index = index;
            throw e;
        }

        if (index < 0)
            return clamp ? 0 : InvalidIndex;

		CharType c = gbuffer[index];

		// Magic to handle \r\n newlines
		// If we landed on a \n and a \r is preceeding the do one more
		// step to land on the \r. Also if we landed on a \r we go one more step since the start index is
        // probably on a \n
		if (index > 0 &&
			( (c == '\n' && gbuffer[index-1] == '\r') || c == '\r') )
			index -= strideBack(gbuffer[0..index]); // \r\n. eat both
		return index;
	}

	int next(int index, bool clamp = true) const
	{
        import std.utf;
        assert(index >= 0);
		if (index < 0)
            return clamp ? 0 : InvalidIndex;

        auto len = gbuffer.length;
		if (index >= len)
            return clamp ? len : InvalidIndex;

		if (gbuffer[index] == '\r')
        {
			index++; // \r\n assumed. eat both. TODO: fix assumption
            if (index == len)
                return len;
        }

		// index++;
        index += stride(gbuffer[index..len]);

        if (index > len)
             return clamp ? len : InvalidIndex;
		return index;
	}

	int offset(int index, bool forward, bool clamp = true) const
	{
		if (forward)
			return next(index, clamp);
		else
			return prev(index, clamp);
	}

	int offsetBy(int index, int count, TextBoundary bound,
				 TextBoundaryStrength strength = TextBoundaryStrength.soft,
				 bool clamp = true) const
	{
		switch (bound)
		{
			case TextBoundary.unit:
				return offsetByUnit(index, count, clamp);
			case TextBoundary.chr:
				return offsetByChar(index, count, clamp);
			case TextBoundary.buffer:
                if (clamp)
                    return count < 0 ? 0 : (count == 0 ? index : length);
                else if (count == -1)
                    return 0;
                else if (count == 1)
                    return length;
                else if (count == 0)
                    return index;
                else
                    return InvalidIndex;
			default:
				return offsetByBoundary(index, count, bound, strength, clamp);
		}
	}

	// Return the startIndex moved diff characters taking
	// the clamping on start and end.
	int offsetByUnit(int startIndex, int diff = 1, bool clamp = true) const
	{
		assert(startIndex >= 0);
		int newIndex = startIndex + diff;
        return diffSanitize(newIndex, diff, clamp);
	}

    private int sanitize(int idx, bool clamp) const pure nothrow @safe
    {
        if (idx < 0)
        {
            if (clamp)
                return 0;
            else
                return InvalidIndex;
        }

        int len = length;
        if (idx > len)
        {
            if (clamp)
                return len;
            else
                return InvalidIndex;
        }
        return idx;
    }

    private int diffSanitize(int newIdx, int diff, bool clamp) const pure nothrow @safe
    {
        if (newIdx < 0 || newIdx > length)
        {
            if (diff > 0)
            {
                // overflow
                if (clamp)
                    return length;
                else
                    return int.min; // signal invalid value
            }
            else if (diff < 0)
            {
                // underflow
                if (clamp)
                    return 0;
                else
                    return int.min; // signal invalid value
            }
        }
        return newIdx;
    }

	unittest
	{
		auto b = new TextBuffer("Hello", 3);

		Assert(0, b.offsetByUnit(0,0));
		Assert(1, b.offsetByUnit(0,1));
		Assert(5, b.offsetByUnit(0,10));
		Assert(5, b.offsetByUnit(0,int.max));
		Assert(5, b.offsetByUnit(int.max,int.max));
		Assert(0, b.offsetByUnit(0,int.min));
	}

	// Return the startIndex moved diff characters taking
	// the clamping on start and end.
	int offsetByChar(int startIndex, int diff = 1, bool clamp = true) const
	{
		int idx = startIndex;
        while (diff > 0)
		{
			--diff;
			idx = next(startIndex, false);
			if (idx == startIndex || idx == InvalidIndex)
				break;
			startIndex = idx;
		}
		while (diff < 0 && idx != InvalidIndex)
		{
			++diff;
			idx = prev(startIndex, false);
			if (idx == startIndex || idx == InvalidIndex)
				break;
			startIndex = idx;
		}
        if (!clamp && idx == InvalidIndex)
            return InvalidIndex;
        return startIndex;
	}

	unittest
	{
		auto b = new TextBuffer("Hello world\r\nHow are you\r\ntoday\nwell", 3);

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
	// offs < 0 means first char is prev char ie. startIndex-1
	// First all non-words chars are skipped in the direction,
	// there may be no non-word chars if in the middle of a word.
	// Then all word chars are skipped to find the final result.
	//
	// This will always place the result index at the end of the
	// word when offs > 0 and at the start of the word when offs < 0.
	// This is unlike visual studio which always places the result index at the
	// start of the work no matter the direction.
	//
version (OFF)
{
	private int OLDoffsetByWord(int startIndex, int offs = 1, bool clamp = true) const
	{
		while (offs < 0 && startIndex != InvalidIndex)
		{
			++offs;
			// Find first word char
			int fwc = findOneOfReverse(prev(startIndex), WORDCHARS);
			if (fwc == InvalidIndex)
            {
			    // no word char found ie. must be first word in buffer
                if (offs == 0)
                    return 0;
                else if (clamp)
                    // return startIndex;
                    return 0;
                else
                    return InvalidIndex; // since offset is != 0 we know the next iteration will fail
            }

			// Locate start of word
			int sow = findOneNotOfReverse(fwc, WORDCHARS);
			if (sow == InvalidIndex)
            {
                // Cannot find any non word char ie. must be start of buffer
                if (offs == 0)
                    return 0;
                else if (clamp)
                    return 0;
                    //return startIndex;
                else
                    return InvalidIndex; // since offset is != 0 we know the next iteration will fail
            }

			// Correct target because we found the first char before the word start boundary
			startIndex = next(sow);
            assert(startIndex != InvalidIndex);
		}

		while (offs > 0 && startIndex != InvalidIndex)
		{
			--offs;
			// Find first word char
			int fwc = findOneOf(startIndex, WORDCHARS);
			if (fwc == InvalidIndex)
            {
				// no word char found ie. must be last work in buffer
                if (offs == 0)
                    return length;
                else if (clamp)
                    return length;
                    // return startIndex;
                else
                    return InvalidIndex; // since offset is != 0 we know the next iteration will fail
            }

			int nwc = findOneNotOf(fwc, WORDCHARS);
			if (nwc == InvalidIndex)
            {
                // Cannot find any non word char ie. must be end of buffer
                if (offs == 0)
                    return length;
                else if (clamp)
                    return length;
                    //return startIndex;
                else
                    return InvalidIndex; // since offset is != 0 we know the next iteration will fail
            }
            startIndex = nwc;
		}
		return startIndex;
	}

    //// Offset index to the closest boundary in the direction of offs
    //private int offsetByWordBoundary(int index, int offs = 1, bool clamp = true) const
    //{
    //    while (offs < 0 && index != InvalidIndex)
    //    {
    //        ++offs;
    //        bool isInWord = std.algorithm.canFind(WORDCHARS, this[index]);
    //
    //        index = isInWord ? findOneNotOfReverse(startIndex, WORDCHARS) : findOneOfReverse(startIndex, WORDCHARS);
    //        if (index == InvalidIndex)
    //        {
    //            // Cannot find any non word char ie. must be start of buffer
    //            if (offs == 0)
    //                return 0;
    //            else if (clamp)
    //                return 0; // start of buffer
    //            else
    //                return InvalidIndex; // since offset is != 0 we know the next iteration will fail
    //        }
    //        // Correct target because we found the first char before the word start boundary
    //        if (offs == 0)
    //            return next(index);
    //
    //        assert(index != InvalidIndex);
    //    }
    //
    //    while (offs > 0 && index != InvalidIndex)
    //    {
    //        --offs;
    //        bool isInWord = std.algorithm.canFind(WORDCHARS, this[index]);
    //
    //        // Find first word char
    //        int index = isInWord ? findOneNotOf(index, WORDCHARS) : findOneOf(index, WORDCHARS);
    //        if (index == InvalidIndex)
    //        {
    //            // no word char found ie. must be last work in buffer
    //            if (offs == 0)
    //                return length;
    //            else if (clamp)
    //                return length;
    //                // return startIndex;
    //            else
    //                return InvalidIndex; // since offset is != 0 we know the next iteration will fail
    //        }
    //    }
    //    return index;
    //}

	unittest
	{
		auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell", 3);

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
	int offsetByLine(int startIndex, sizediff_t offs = 1, bool clamp = true) const
	{
		while (offs < 0 && startIndex != InvalidIndex)
		{
			++offs;

			int foor = findOneOfReverse(prev(prev(startIndex)), "\n");
			if (foor == InvalidIndex)
                return clamp ? 0 : InvalidIndex;
                // return clamp ? startIndex : InvalidIndex;

			// Correct target because we found the first char before the word start boundary
			startIndex = next(foor);
		}

		while (offs > 0 && startIndex != InvalidIndex && startIndex < length)
		{
			--offs;
			auto cur = this[startIndex];
			int curIdx = startIndex;
            if (cur == '\r' || cur == '\n')
				curIdx = next(curIdx);

			curIdx = findOneOf(curIdx, "\r\n");
			if (curIdx == InvalidIndex)
				return clamp ? length : InvalidIndex; // Cannot find any non word char ie. must be end of buffer
                // return clamp ? startIndex : InvalidIndex; // Cannot find any non word char ie. must be end of buffer

            startIndex = curIdx;
        }
		return startIndex;
	}

	unittest
	{
		auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell\ndd\nfdsas", 3);

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

}
	// Return a buffer index obtained by moving 'lines' lines from index using
	// preferredColumn. If preferredColumn is InvalidIndex the column of the index
	// param is used. lines == 0 is a valid input in order to just navigate current line
	// using preferredColumn.
	int offsetVertically(int index, sizediff_t lines = 1, int preferredColumn = InvalidIndex) const
	{
		if (preferredColumn == InvalidIndex)
			preferredColumn = index - offsetToBeginningOfLine(index);

		int newPos = index;

		if (lines < 0)
		{
			// locate the char just above the current index
			lines = -lines;
			for (int i = 0; i < lines; i++)
				newPos = endOfPreviousLine(newPos);

			int eol = offsetToEndOfLine(newPos);
			newPos = offsetToBeginningOfLine(newPos) + preferredColumn;
			if (newPos > eol)
				newPos = eol;
		}
		else
		{

			// locate the char just above the current cursor char
                    auto lll = gbuffer.toArray(newPos, newPos + 200 > gbuffer.length ? gbuffer.length : cast(int)(newPos + 200));
            for (int i = 0; i < lines; i++)
				newPos = startOfNextLine(newPos);

			int eoline = offsetToEndOfLine(newPos);
			newPos = offsetToBeginningOfLine(newPos) + preferredColumn;

			if (newPos > eoline)
				newPos = eoline;
		}
		return newPos;
	}

	unittest
	{
		auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\n\nwell\ndd\nfdsas", 3);
		Assert(30, b.offsetVertically(0, 3));
	}

	//unittest
	//{
	//    auto b = new TextGapBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell\ndd\nfdsas", 3);
	//
	//    Assert(3, b.offsetByLine(21,1));
	//    Assert(34, b.offsetByLine(21,-1));
	//    Assert(44, b.offsetByLine(21,4));  // preferred colum not possible next line
	//    Assert(b.length-6, b.offsetByLine(b.length-1,1));  // preferred colum not possible prev line
	//}

	//int offsetTo(int index, TextBoundary bound, bool startOfBoundary = true)
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
	//int offsetToChar(int index, bool startOfBoundary)
	//{
	//    return startOfBoundary ? index : next(index);
	//}
	//
	//int offsetToWord(int index, bool startOfBoundary)
	//{
	//    return offsetByWord(index, startOfBoundary ? -1 : 1);
	//}
	//
	//int offsetToLine(int index, bool startOfBoundary)
	//{
	//    return offsetByLine(index, startOfBoundary ? -1 : 1, int.max-1);
	//}

	//unittest
	//{
	//    auto b = new TextBuffer("  Hello woerld\r\nHow are you\r\ntoday\nwell", 3);
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

	TextBoundary classify(int index) const
	{
		enum Cls
		{
			punct,
			word,
			space,
			newline,
		}
		static Cls cls(const(TextBuffer) b, int idx)
		{
			bool isPunct = std.algorithm.canFind(PUNCTUATIONCHARS, b[idx]);
			if (isPunct)
				return Cls.punct;

			if (b[idx] == '\n' || b[idx] == '\r')
				return Cls.newline;

			if (std.algorithm.canFind(WHITESPACECHARS, b[idx]))
				return Cls.space;

			return Cls.word;
		}

		TextBoundary res;
		if (length == 0)
		{
			if (index == 0)
				res = TextBoundary.bufferBegin | TextBoundary.bufferEnd;
			return res;
		}

		if (index == 0)
			res = res | TextBoundary.bufferBegin | TextBoundary.lineBegin;

        if (index == length)
        {
			res = res | TextBoundary.bufferEnd | TextBoundary.lineEnd;

            if (length > 0)
            {
                Cls preIdxCls = cls(this, prev(index));
                final switch (preIdxCls)
                {
                    case Cls.word:
                        res = res | TextBoundary.wordEnd;
                        break;
                    case Cls.newline:
                        res = res | TextBoundary.emptyLine | TextBoundary.lineBegin;
                        break;
                    case Cls.punct:
                        res = res | TextBoundary.punctuationEnd;
                        break;
                    case Cls.space:
                        break;
                }
            }
            return res;
        }

		Cls curIdxCls = cls(this, index);

		if (index == 0)
		{
			final switch (curIdxCls)
			{
			case Cls.word:
				res = res | TextBoundary.lineBegin | TextBoundary.wordBegin;
                break;
			case Cls.newline:
				res = res | TextBoundary.emptyLine | TextBoundary.lineBegin | TextBoundary.lineEnd;
                break;
			case Cls.punct:
				res = res | TextBoundary.lineBegin | TextBoundary.punctuationBegin;
                break;
			case Cls.space:
				res = res | TextBoundary.lineBegin;
                break;
			}
			return res;
		}

		Cls prevIdxCls = cls(this, index - 1);
		final switch (prevIdxCls)
		{
	        case Cls.word:
				final switch (curIdxCls)
				{
					case Cls.space:
						res = res | TextBoundary.wordEnd;
						break;
					case Cls.newline:
						res = res | TextBoundary.lineEnd | TextBoundary.wordEnd;
						break;
					case Cls.punct:
						res = res | TextBoundary.punctuationBegin | TextBoundary.wordEnd;
						break;
					case Cls.word:
						break;
				}
				break;
	        case Cls.newline:
				final switch (curIdxCls)
				{
					case Cls.space:
						res = res | TextBoundary.lineBegin;
						break;
					case Cls.newline:
						res = res | TextBoundary.lineBegin | TextBoundary.lineEnd | TextBoundary.emptyLine;
						break;
					case Cls.punct:
						res = res | TextBoundary.lineBegin | TextBoundary.punctuationBegin;
						break;
					case Cls.word:
						res = res | TextBoundary.lineBegin | TextBoundary.wordBegin;
						break;
				}
				break;
		    case Cls.punct:
				final switch (curIdxCls)
				{
					case Cls.space:
						res = res | TextBoundary.punctuationEnd;
						break;
					case Cls.newline:
						res = res | TextBoundary.lineEnd | TextBoundary.punctuationEnd;
						break;
					case Cls.punct:
						break;
					case Cls.word:
						res = res | TextBoundary.punctuationEnd | TextBoundary.wordBegin;
						break;
				}
				break;
            case Cls.space:
				final switch (curIdxCls)
				{
					case Cls.space:
						break;
					case Cls.newline:
						res = res | TextBoundary.lineEnd;
						break;
					case Cls.punct:
						res = res | TextBoundary.punctuationBegin;
						break;
					case Cls.word:
						res = res | TextBoundary.wordBegin;
						break;
				}
				break;
		}
		return res;
	}

	final int findByClass(int index, bool forward, TextBoundary cls, bool clamp = true) const
	{
		int idx = index;
        while (idx != InvalidIndex && (classify(idx) & cls) == 0)
        {
            index = idx;
   			idx = offset(idx, forward, false);
        }
		return idx == InvalidIndex && clamp ? index : idx;
	}

	int offsetByBoundary(int index, int offs,
						 TextBoundary bound = TextBoundary.wordEnd,
						 TextBoundaryStrength strength = TextBoundaryStrength.soft,
						 bool clamp = true) const
	{
		if (index == InvalidIndex)
            return index;

        const bool forward = offs > 0;
        int delta = forward ? -1 : 1;

		// Locate word boundary in the search direction
		if (strength == TextBoundaryStrength.soft)
		{
			// Make sure we don't check current index and return that because if matches the boundary already
			int idx = offset(index, forward, false);
            if (idx == InvalidIndex)
                return clamp ? index : idx;
            index = idx;
		}
		else
		{
			// only need to search once when strength is hard
			offs = -delta;
		}

		int idx = index;

		while (offs != 0 && idx != InvalidIndex)
		{
			index = idx;
			idx = findByClass(index, forward, bound, false);
			offs += delta;

			// If more iterations are needed the move start index in order to not detect the same index again
			if (offs != 0 && idx != InvalidIndex)
				idx = offset(idx, forward, false);
		}

		if (clamp && idx == InvalidIndex)
			return index;
		else
			return idx;
	}

    //int OLDoffsetToWordBoundary(int index, int dir) const
    //{
    //    if (index == InvalidIndex)
    //        return index;
    //
    //    // Make sure that index is in a word (or at the end) or return InvalidIndex
    //    const bool isInWord = std.algorithm.canFind(WORDCHARS, this[index]);
    //    int result = InvalidIndex;
    //    if (isInWord)
    //    {
    //        // On a char in a word
    //        if (dir < 0)
    //            result = offsetByWord(next(index), -1);
    //        else
    //            result = offsetByWord(index, 1);
    //        return result;
    //    }
    //
    //    index = prev(index);
    //    if (index != InvalidIndex && std.algorithm.canFind(WORDCHARS, this[index]))
    //    {
    //        // At end of word
    //        if (dir < 0)
    //            result = offsetByWord(index, -1);
    //        else
    //            result = index;
    //    }
    //    return result;
    //}
    //
    //int xxoffsetByLineBoundary(int index, int dir, bool clamp = true) const
    //{
    //    if (dir == 0)
    //        return index;
    //
    //    // First offset will always go start of current line even if index is already
    //    // at start of line. All next offsets will skip start of line.
    //    // Same goes for the other direction.
    //
    //    bool startOfLineboundary = dir < 0;
    //    int idx = _offsetByLineBoundary(index, startOfLineboundary, clamp);
    //    int delta = dir < 0 ? -1 : 1;
    //    dir += delta;
    //    while (dir != 0 && idx != InvalidIndex)
    //    {
    //        // skipping the \r\n counts for one offset
    //        index = offsetByChar(idx, delta, clamp);
    //        dir += delta;
    //
    //        if (dir == 0 || index == idx || index != InvalidIndex)
    //        {
    //            idx = index;
    //            break;
    //        }
    //
    //        // skipping the line content counts for one offset
    //        idx = _offsetByLineBoundary(index, startOfLineboundary, clamp);
    //        dir += delta;
    //    }
    //    return idx;
    //}
version (OFF)
{
    int offsetByLineBoundary(int index, int dir, bool clamp = true) const
    {
        return _offsetByLineBoundary(index, dir < 0, clamp);
    }

	int _offsetByLineBoundary(int index, bool startOfBoundary, bool clamp = true) const
	{
		if (index == InvalidIndex)
            return index;

        if (startOfBoundary)
		{
			enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <= ", length));

			if (gbuffer.empty) return 0;

			dchar c = index == gbuffer.length ? 0xFFEF : gbuffer[index];

			// border case where index is at the end of line
			if (index == gbuffer.length || c == '\n' || c == '\r')
			{
				int newidx = prev(index);
				if (newidx == InvalidIndex)
				{
					if (clamp)
						return 0; // start of buffer
					else
	                    return newidx;
				}

                if (newidx == 0)
					return 0;

				c = gbuffer[newidx];

				// In case it was an empty line we already were at start of line.
				if (c == '\n' || c == '\r')
					return index;

                index = newidx;
			}

			assert(gbuffer.length >= index);
			auto r = this[0u..index];

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

			assert(gbuffer.length >= index);
			auto r = this[index..gbuffer.length];

			// locate the next \n
			size_t i = 0;
			dchar prev;
            foreach (v; r)
			{
                if (v == '\n')
				{
					if (i > 0 && prev == '\r')
						i--;
					break;
				}
                prev = v;
				i++;
			}

			return index + i;
		}
	}
}

	int offsetToEndOfLine(int index) const
	{
		return offsetBy(index, 1, TextBoundary.lineEnd, TextBoundaryStrength.hard);
	}

	int offsetToBeginningOfLine(int index) const
	{
		return offsetBy(index, -1, TextBoundary.lineBegin, TextBoundaryStrength.hard);
	}

	int offsetToEndOfWord(int index) const
	{
		return offsetBy(index, 1, TextBoundary.wordEnd, TextBoundaryStrength.hard);
	}

	int offsetToBeginningOfWord(int index) const
	{
		return offsetBy(index, -1, TextBoundary.wordBegin, TextBoundaryStrength.hard);
	}

	int startOfNextLine(int index) const
	{
		return offsetBy(index, 1, TextBoundary.lineBegin, TextBoundaryStrength.soft);
	}

	int endOfPreviousLine(int index) const
	{
		return offsetBy(index, -1, TextBoundary.lineEnd, TextBoundaryStrength.soft);
	}

    auto findRegex(int index, const(char)[] re, const(char)[] flags = "")
    {
        import std.regex;

        auto _re = regex(re, flags);

        static struct FindMatch
        {
            typeof(RegexMatch!(char[])().front) captures;

            @property int a()
            {
                return cast(int)captures.pre.length;
            }

            @property int b()
            {
                return cast(int)(captures.pre.length + captures.hit.length);
            }

            @property typeof(gbuffer).CharType[] hit()
            {
                return captures.hit;
            }
        }

        gbuffer.placeGapStart(0);
        return matchAll(gbuffer.buffer[gbuffer.gapEnd..$], _re).map!((m) => FindMatch(m));
    }

	int find(int index, const(char)[] needle) const
	{
		// TODO: consider placing gap at 0 and find directly in gbuffer.buffer
        size_t needleSize = needle.length;
		size_t curEnd = needleSize + index;
		size_t len = length;
		assert(gbuffer.length >= index && curEnd <= gbuffer.length);
		while (curEnd < len && !std.algorithm.equal(this[index..curEnd], needle))
		{
			index++;
			curEnd++;
		}
		assert(gbuffer.length >= index && curEnd <= gbuffer.length);
		return curEnd <= len && std.algorithm.equal(this[index..curEnd], needle) ? index : InvalidIndex;
	}

	enum PUNCTUATIONCHARS = r".,:;?-+*\/&^#@!()'`<>{}[]";
    enum WHITESPACECHARS = " \t";

	int findOneOf(int index, const(char)[] needles) const
	{
		size_t len = length;

		while (index < len && !std.algorithm.canFind(needles, this[index]))
		{
			index++;
		}
		return index < len ? index : InvalidIndex;
	}

	int findOneNotOf(int index, const(char)[] needles) const
	{
		size_t len = length;

		while (index < len && std.algorithm.canFind(needles, this[index]))
		{
			index++;
		}
		return index < len ? index : InvalidIndex;
	}

	int findOneOfReverse(int index, const(char)[] needles) const
	{
		if (index >= length)
            return InvalidIndex;

        while (index >= 0 && index != InvalidIndex && !std.algorithm.canFind(needles, this[index]))
		{
			index--;
		}
		return index != InvalidIndex && index >= 0 ? index : InvalidIndex;
	}

	int findOneNotOfReverse(int index, const(char)[] needles) const
	{
		if (index >= length)
            return InvalidIndex;

		while (index >= 0 && index != InvalidIndex && std.algorithm.canFind(needles, this[index]))
		{
			index--;
		}
		return index != InvalidIndex && index >= 0 ? index : InvalidIndex;
	}

	Region regionForLineNumber(int lineNum)
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

	int lineNumberAt(int index) const
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " <=sa ", length));

        int firstLine = 0;
        int lastLine = lbuffer.length;
        int lineDiff = lastLine - firstLine;
        while (lineDiff != 1)
        {
            int curLine = lineDiff / 2 + firstLine;
            int curLineStartIndex = lbuffer[curLine];
            if (curLineStartIndex <= index)
            {
                firstLine = curLine;
            }
            else if (curLineStartIndex > index)
            {
                lastLine = curLine;
            }
            lineDiff = lastLine - firstLine;
        }
        return firstLine;

        //// TODO: optimize using lbuffer
        //int curLine = 0;
        //int i = 0;
        //do
        //{
        //    i = startOfNextLine(i);
        //    if (index < i || i == InvalidIndex)
        //        break;
        //    curLine++;
        //}
        //while (i != length);
        //return curLine;
	}

	debug int startAtLineNumberScan(int lineNum) const
	{
		int curLine = 0;
		int i = 0;
		do
		{
			if (curLine == lineNum)
				return i;
			i = startOfNextLine(i);
			curLine++;
		}
		while (i != length);
		return offsetToBeginningOfLine(i);
	}

	int startAtLineNumber(int lineNum) const
	{
		if (lbuffer.length > lineNum)
			return lbuffer[lineNum];
		else
			return lbuffer[lbuffer.length - 1];
	}

	int endAtLineNumber(int lineNum) const
	{
		lineNum++;
		int idx = 0;
		if (lbuffer.length > lineNum)
			idx = lbuffer[lineNum];
		else
                    return length;
		return prev(idx);
	}

	auto lineEndsAt(int index) const
	{
		return tuple(offsetToBeginningOfLine(index), offsetToEndOfLine(index));
	}

	auto lineEndsForLineNumber(int lineNum) const
	{
		auto start = startAtLineNumber(lineNum);
		return tuple(start, offsetToEndOfLine(start));
	}

	const(CharType)[] lineContaining(int index) const
	{
		auto ends = lineEndsAt(index);
		return gbuffer.toArray(ends[0], ends[1]);
	}

	const(CharType)[] lineString(int lineNumber) const
	{
		return gbuffer.toArray(startAtLineNumber(lineNumber),
							   endAtLineNumber(lineNumber));
	}

	///
	/// Mutating methods below
	///

	void insert(const(CharType)[] items, int index = InvalidIndex)
	{
        index = index == InvalidIndex ? gbuffer.editPoint : index;
		gbuffer.insert(items, index);
		lbuffer.textInserted(items, index);
        onChanged.emit(this, index, items.length, true);
	}

	unittest
	{
		class LineListener
		{
			int[] expect;
			int nextIdx;

			void onLinesInserted(int lineNum, int lineCount)
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

		TextBuffer b1 = new TextBuffer("", 40);
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


		TextBuffer b = new TextBuffer("", 40);
		b.insert("one");
		Assert(b.lbuffer.editPoint, 1, "Line editpoint is 0 after non-lf string");
		// Assert(b.lbuffer[b.lbuffer.editPoint], 0, "Line editpoint value is 0 after non-lf string");
		b.insert("two\nthree");
		Assert(b.lbuffer.editPoint, 2, "Line editpoint is 1 after lf string");
		Assert(b.lbuffer.length, 2, "Line editpoint length is 2 after lf string");
	}

	// Remove count characters from the buffers starting at index
	// If count is negative the characters are moved backwards
	void remove(int count, int index)
	{
		enforceEx!Exception(index >= 0 && index <= length, text("Index out of bounds 0 <= ", index , " < ", length));

        int removed = 0;

		if (count > 0)
		{
            while (count--)
			{
				int idx = next(index);

				int diff = idx - index;
				if (diff == 0)
					break;

				lbuffer.textRemoved(index, index + diff);
			    removed += diff;

				while (diff--)
					gbuffer.remove(index);
            }
		}
		else if (count < 0)
		{
            while (count++)
			{
				int idx = prev(index);
				int diff = index - idx;
				if (diff == 0)
					break;
				index -= diff;
                removed += diff;

				lbuffer.textRemoved(index, index + diff);

				while (diff--)
					gbuffer.remove(index);
			}
        }
        onChanged.emit(this, index, removed, false);
	}

	void removeRange(int start, int end)
	{
		enforceEx!Exception(start >= 0 && start <= end && end <= length, text("Index out of bounds 0 <= ", start , " <= ", end, " <= ", length));
		auto idx = start;
		while (idx++ < end)
			gbuffer.remove(start);
		lbuffer.textRemoved(start, end);
        onChanged.emit(this, start, end - start, false);
	}

	unittest
	{
		class LineListener
		{
			int[] expect;
			int nextIdx;

			void onLinesRemoved(int lineNum, int lineCount)
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

		TextBuffer b1 = new TextBuffer("", 40);
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
	auto getLineAnchor(int lineNumber, ITextBufferAnchorOwner owner = null)
	{
		bool ownerIsNull = owner is null;
		foreach (ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line &&
				lineNumber == info.number &&
				(ownerIsNull || owner is info.owner))
				return info;
		}
		return TextBufferAnchor(TextBufferAnchorType.none, InvalidAnchorID);
	}

    /*
    auto getLineAnchors(Anchor)(ITextBufferAnchorOwner owner = null)
    {
		bool ownerIsNull = owner is null;
		Anchor[] result;
        foreach (ref info; _anchors)
		{
			if ((ownerIsNull || owner is info.owner) && cast(Anchor) !is null)
				result ~= info;
		}
		return TextBufferAnchor(TextBufferAnchorType.none, InvalidAnchorID);
    }
    */

    auto getLineAnchors(ITextBufferAnchorOwner owner)
    {
        TextBufferAnchor[] result;
        foreach (ref info; _anchors)
        {
            if (owner is info.owner)
                result ~= info;
        }
        return result;
    }

	auto createLineAnchor(int lineNumber, ITextBufferAnchorOwner owner = null)
	{
		auto id = TextBufferAnchor.nextID++;
		auto a = TextBufferAnchor(TextBufferAnchorType.line, id, lineNumber, owner);
		_anchors ~= a;
		onAnchorAdded.emit(this, a);
		return a;
	}

	auto ensureLineAnchor(int lineNumber, ITextBufferAnchorOwner owner = null)
	{
		auto la = getLineAnchor(lineNumber, owner);
		if (la.id != InvalidAnchorID)
			return la;
		return createLineAnchor(lineNumber, owner);
	}

	void removeLineAnchorByID(int lineAnchorID)
	{
		foreach (i, ref info; _anchors)
		{
			if (info.id == lineAnchorID)
			{
				info = _anchors[$-1];
				_anchors.length = _anchors.length-1;
                onAnchorRemoved.emit(this, info);
				return;
			}
		}
	}

	void removeLineAnchorByLine(int lineNumber, ITextBufferAnchorOwner owner = null)
	{
		bool ownerIsNull = owner is null;
        auto toDelete = appender!(size_t[]);
		foreach (idx, ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line &&
				lineNumber == info.number &&
				(ownerIsNull || owner is info.owner))
			{
				toDelete ~= idx;
                if (!ownerIsNull)
                    break; // only one line anchor per owner
			}
		}
         removeAnchorsByIndex(toDelete.data());
	}

	TextBufferAnchor[] getAnchorsForLines(int lineOffset, int visibleLineCount, ITextBufferAnchorOwner owner = null)
	{
		bool ownerIsNull = owner is null;
        auto res = appender!(TextBufferAnchor[]);
		auto endLine = lineOffset + visibleLineCount;
		foreach (ref info; _anchors)
		{
			if (info.number >= lineOffset && info.number < endLine &&
				(ownerIsNull || owner is info.owner))
				res.put(info);
		}
		return res.data;
	}

	bool hasAnchors() const
	{
		return !_anchors.empty;
	}

	private void onLinesInserted(int lineNumber, int lineCount)
	{
		foreach (ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line && info.number >= lineNumber)
				info.number += lineCount;
		}
	}

	private void onLinesRemoved(int lineNumber, int lineCount)
	{
		auto toDelete = appender!(size_t[]);
        foreach (idx, ref info; _anchors)
		{
			if (info.type == TextBufferAnchorType.line && info.number >= lineNumber)
			{
				if (info.number - lineCount < lineNumber)
				{
					toDelete ~= idx;
				}
				else
				{
					info.number -= lineCount;
				}
			}
		}
        removeAnchorsByIndex(toDelete.data());
	}

    private void removeAnchorsByIndex(size_t[] toDelete)
    {
        foreach_reverse (idx; toDelete)
        {
             auto info = _anchors[idx];
            _anchors[idx] = _anchors[$-1];
            _anchors.length = _anchors.length - 1;
             onAnchorRemoved.emit(this, info);
        }
    }
}
