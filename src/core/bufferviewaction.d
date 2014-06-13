module core.bufferviewaction;

import core.buffer;
import core.bufferview;
import math.region;

import std.algorithm;
import std.array;
import std.container;
import std.range;
import std.typecons;

version(unittest) 
{
	import test;
	import core.copybuffer;
}

// An action is revisible in regards to 
// cursor position, preferredColumn and text content.
// This also means that the reverse of nextWord isn't just prevWord since
// the cursor may be in the middle of a word to begin with and a nextWord followed
// by a prevWord would not restore the cursor position (or preferred column) correctly.
class Action
{
	bool modifying = true; // is this action modifying the buffer or just navigating
	abstract void redo(BufferView bv);
	abstract void undo(BufferView bv);
}

// A special action that contain actions itself and undoing/redoing this action
// will do it on all actions in this group in one step
class ActionGroupAction : Action
{
	Action[] actions;

	this(Args...)(Args args)
	{
		auto t = tuple(args);
		actions.length = t.length;
		foreach (i, a; t)
		{
			actions[i] = a;
			modifying = modifying || a.modifying;
		}
	}

	private bool update(Args...)(Args args)
	{
		return false; // cannot update group actions
	}

	override void redo(BufferView bv)
	{
		foreach (a; actions)
			a.redo(bv);
	}

	override void undo(BufferView bv)
	{
		foreach (a; actions.retro)
			a.undo(bv);
	}
}

class CursorDownAction : Action
{
	int count;
	//uint preferredColumn;

	this(int cnt)
	{
		modifying = false;
		count = cnt;
	}

	// Return true if this action was updated to reflect the changes
	private bool update(BufferView bv, int cnt)
	{
		count += cnt;
		perform(bv, cnt);
		return true;
	}
	private void perform(BufferView bv, int cnt)
	{
		auto v = bv.buffer.offsetVertically(bv._cursorPoint, cnt, bv.preferredCursorColumn);
		if (!bv.isValidCursorPoint(v))
			return;
		bv._cursorPoint = v;
	}

	override void redo(BufferView bv)
	{
		//preferredColumn = bv.preferredCursorColumn;
		perform(bv, count);
	}

	override void undo(BufferView bv)
	{
		auto v = bv.buffer.offsetVertically(bv._cursorPoint, -count, bv.preferredCursorColumn);
		bv._cursorPoint = v;
		//bv.preferredCursorColumn(preferredColumn);
		//bv.setIndexFromPreferredCursorColumn();
	}
}

unittest
{
	// Test reversibility
	BufferView v = new BufferView("01234\n67\n9ABCDEF\n");
	v.copyBuffer = new CopyBuffer;
	Action i1 = new CursorDownAction(1);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 6);
	i1.undo(v);
	Assert(v.cursorPoint, 0);

	i1.redo(v);
	Assert(v.cursorPoint, 6);
	i1.redo(v);
	Assert(v.cursorPoint, 9);
	i1.redo(v);
	Assert(v.cursorPoint, 17);
	i1.undo(v);
	Assert(v.cursorPoint, 9);
	i1.undo(v);
	Assert(v.cursorPoint, 6);
	i1.undo(v);
	Assert(v.cursorPoint, 0);
	i1.undo(v);
	Assert(v.cursorPoint, 0);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 5;
	Assert(v.preferredCursorColumn, 5, "preferred colum is 5");
	i1.redo(v);
	Assert(v.cursorPoint, 8);
	i1.undo(v);
	Assert(v.cursorPoint, 5);

	i1.redo(v);
	Assert(v.cursorPoint, 8);
	i1.redo(v);
	Assert(v.cursorPoint, 14);
	i1.redo(v);
	Assert(v.cursorPoint, 17);
	i1.undo(v);
	Assert(v.cursorPoint, 14);
	i1.undo(v);
	Assert(v.cursorPoint, 8);
	i1.undo(v);
	Assert(v.cursorPoint, 5);
	i1.undo(v);
	Assert(v.cursorPoint, 5);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 7;
	Assert(v.preferredCursorColumn, 7, "preferred colum is 7");
	i1.redo(v);
	Assert(v.cursorPoint, 8);
	i1.undo(v);
	Assert(v.cursorPoint, 5);

	i1.redo(v);
	Assert(v.cursorPoint, 8);
	i1.redo(v);
	Assert(v.cursorPoint, 16);
	i1.redo(v);
	Assert(v.cursorPoint, 17);
	i1.undo(v);
	Assert(v.cursorPoint, 16);
	i1.undo(v);
	Assert(v.cursorPoint, 8);
	i1.undo(v);
	Assert(v.cursorPoint, 5);
	i1.undo(v);
	Assert(v.cursorPoint, 5);
}

class InsertAction : Action
{
	immutable(TextBuffer.CharType)[] text;
	uint preferredColumn;
	
	this(immutable(TextBuffer.CharType)[] txt)
	{
		text = txt;
	}

	// Update this insert action by adding txt to existing text and redo action with
	// the concatenated text. Note that a redo() must have been performed on the existings text
	// before calling this as it is assumed that text is already in buffer.
	private bool update(BufferView bv, immutable(TextBuffer.CharType)[] txt)
	{
		if (txt == " " || txt == "\t" || txt == "\r\n" || txt == "\n")
			return false; // force undo entry for each word
		text ~= txt;
		perform(bv, txt);
		return true;
	}

	private void perform(BufferView bv, immutable(TextBuffer.CharType)[] txt)
	{
		auto insertPoint = bv.cursorPoint;
		bv.buffer.insert(txt, insertPoint);
		bv._cursorPoint = insertPoint + txt.length;
		bv.setPreferredCursorColumnFromIndex();
		bv.changed();
		bv.onInsert.emit(bv, txt, insertPoint);
	}

	override void redo(BufferView bv)
	{
		preferredColumn = bv.preferredCursorColumn;
		perform(bv, text);
	}

	override void undo(BufferView bv)
	{
		bv._cursorPoint = bv.cursorPoint - text.length;
		bv.buffer.removeRange(bv.cursorPoint, text.length + bv.cursorPoint);
		bv.preferredCursorColumn(preferredColumn);
		// bv.setIndexFromPreferredCursorColumn();
		bv.changed();
		bv.onRemove.emit(bv, text, bv.cursorPoint);
	}
}

unittest
{
	// Test reversibility
	BufferView v = new BufferView("01234\n67\n9ABCDEF\n");
	v.copyBuffer = new CopyBuffer;
	Action i1 = new InsertAction("XY"d);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 2);
	Assert(v.preferredCursorColumn, 2, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 5;
	v.cursorPoint = 7;
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 9);
	Assert(v.preferredCursorColumn, 3, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn	= 7;
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 9);
	Assert(v.preferredCursorColumn, 3, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
}

class RemoveAction : Action
{
	uint preferredColumn;
	int count;
	immutable(TextBuffer.CharType)[] text; // used to remember what to undo
	TextBoundary boundary;

	this(TextBoundary b, int cnt = 1)
	{
		count = cnt;
		boundary = b;
	}

	private bool update(BufferView bv, TextBoundary b, int cnt)
	{
		// Only some boundary moves and direction can be updated
		if (boundary != b || ((cnt < 0) != (count < 0)))
			return false;
		count += cnt;
		perform(bv, b, cnt);
		return true;
	}
	
	private void perform(BufferView bv, TextBoundary b, int cnt)
	{
		auto start = bv.buffer.offsetBy(bv._cursorPoint, cnt, b);
		auto end = bv._cursorPoint;

		// record the content for later undoing
		if (start > end)
		{
			auto tmp = start;
			start = end;
			end = tmp;
		}

		auto t = array(bv.buffer[start..end]).idup;
		if (cnt < 0)
			text = t ~ text;
		else
			text ~= t;

		bv.buffer.removeRange(start, end);
		bv._cursorPoint = start;
		bv.setPreferredCursorColumnFromIndex();
		bv.changed();
		bv.onRemove.emit(bv, t, start);
	}

	override void redo(BufferView bv)
	{
		preferredColumn = bv.preferredCursorColumn;
		perform(bv, boundary, count);
	}

	override void undo(BufferView bv)
	{
		bv.buffer.insert(text, bv.cursorPoint);
		auto origCursorPoint = bv.cursorPoint;
		auto restoredCursorPoint = origCursorPoint;
		if (count < 0)
			restoredCursorPoint += text.length;
		bv._cursorPoint = restoredCursorPoint; 
		bv.preferredCursorColumn(preferredColumn);
		// bv.setIndexFromPreferredCursorColumn();
		bv.changed();
		bv.onInsert.emit(bv, text, origCursorPoint);
		text = null;
	}
}

unittest
{
	// Test reversibility
	BufferView v = new BufferView("01234\n67\n9ABCDEF\n");
	v.copyBuffer = new CopyBuffer;
	Action i1 = new RemoveAction(TextBoundary.chr, 2);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 5;
	v.cursorPoint = 7;
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 1, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");

	Action i2 = new RemoveAction(TextBoundary.chr, -2);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	v.cursorPoint = 0;
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i2.redo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i2.undo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 5;
	v.cursorPoint = 8;
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i2.redo(v);
	Assert(v.cursorPoint, 6);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i2.undo(v);
	Assert(v.cursorPoint, 8);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
}

class RemoveSelectedAction : Action
{
	uint preferredColumn;
	bool cursorAtStartOfSelection;
	immutable(TextBuffer.CharType)[] text; // used to remember what to undo

	private bool update(BufferView bv)
	{
		return false; // cannot update this
	}

	override void redo(BufferView bv)
	{
		preferredColumn = bv.preferredCursorColumn;
		import std.math;
		// record the content for later undoing
		
		auto l = bv.selection.length;
		auto o = bv.selection.a;
		cursorAtStartOfSelection = bv.cursorPoint == o;
		text = array(bv.buffer[bv.selection.a..bv.selection.b]).idup;
		bv.buffer.removeRange(bv.selection.a, bv.selection.b);
		bv.clearSelection();
		bv._cursorPoint = o;
		bv.setPreferredCursorColumnFromIndex();
		bv.changed();
		bv.onRemove.emit(bv, text, o);
	}

	override void undo(BufferView bv)
	{
		auto origCursorPoint = bv.cursorPoint;
		bv.buffer.insert(text, bv.cursorPoint);
		bv.changed();
		bv.onInsert.emit(bv, text, origCursorPoint);
		
		if (cursorAtStartOfSelection)
		{
			bv.selection = Region(bv._cursorPoint, bv._cursorPoint + text.length);
		}
		else
		{
			bv._cursorPoint += text.length; 
			bv.selection = Region(bv._cursorPoint, bv._cursorPoint - text.length);
		}
		bv.preferredCursorColumn(preferredColumn);
		//bv.setIndexFromPreferredCursorColumn();
	}
}

unittest
{
	import math.region;
	
	// Test reversibility
	BufferView v = new BufferView("01234\n67\n9ABCDEF\n");
	v.copyBuffer = new CopyBuffer;
	Action i1 = new RemoveSelectedAction();

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	v.selection = Region(v.cursorPoint, v.cursorPoint + 2);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 5;
	v.cursorPoint = 7;
	v.selection = Region(v.cursorPoint, v.cursorPoint + 2);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 1, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	v.cursorPoint = 0;
	v.selection = Region(0, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 5;
	v.cursorPoint = 8;
	v.selection = Region(v.cursorPoint - 2, v.cursorPoint);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 6);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 8);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
}

class CopySelectedAction : Action
{
	this()
	{
		modifying = false;
	}
	
	private bool update(BufferView bv)
	{
		return false; // cannot update this
	}

	override void redo(BufferView bv)
	{
		auto text = bv.selectedText.idup;
		bv.copyBuffer.add(text);
		bv.onCopy.emit(bv, text, bv.selection.a);
	}

	override void undo(BufferView bv)
	{
		// no-op
	}
}

class PasteAction : Action
{
	int copyBufferEntryOffset;
	InsertAction insertAction;
	RemoveSelectedAction removeSelectedAction;

	this(int boffset)
	{
		copyBufferEntryOffset = boffset < 0 ? 0 : boffset;
	}

	private bool update(BufferView bv, int offset)
	{
		if (offset >= 0)
			return false;

		int origOffset = copyBufferEntryOffset;
		if (offset < 0)
			copyBufferEntryOffset -= offset;

		if (copyBufferEntryOffset >= bv.copyBuffer.length || copyBufferEntryOffset < 0)
		{
			// no-op
			copyBufferEntryOffset = origOffset;
			return true;
		}
		
		if (insertAction is null)
		{
			// Previous pastes were done with invalid entry offsets ie. no-op.
			// This is the first actual paste
			redo(bv); 
			return true;
		}

		insertAction.undo(bv);
		auto e = bv.copyBuffer.get(copyBufferEntryOffset);
		insertAction = new InsertAction(e.txt);
		insertAction.redo(bv);
		return true;
	}

	override void redo(BufferView bv)
	{
		if (insertAction is null)
		{
			auto e = bv.copyBuffer.get(copyBufferEntryOffset);
			if (e is null)
				return; // nothing at that entry

			if (!bv.selection.empty)
			{
				removeSelectedAction = new RemoveSelectedAction();			
				removeSelectedAction.redo(bv);
			}
			
			insertAction = new InsertAction(e.txt);
		}
		insertAction.redo(bv);
	}

	override void undo(BufferView bv)
	{
		if (insertAction !is null)
			insertAction.undo(bv);
		if (removeSelectedAction !is null)
			removeSelectedAction.undo(bv);
	}
}

class CursorAction : Action
{
	int offset;
	TextBoundary boundary;
	int count;
	uint preferredColumn; // To set when undoing. Upon updating it will alway be the initial column that is kept.

	this(TextBoundary b, int cnt = 1)
	{
		modifying = false;
		boundary = b;
		count = cnt;
	}

	private bool update(BufferView bv, TextBoundary b, int cnt)
	{
		// Only some boundary moves and direction can be updated
		if (boundary != b || ((cnt < 0) != (count < 0)))
			return false;
		count += cnt;
		perform(bv, b, cnt);
		return true;		
	}

	private void perform(BufferView bv, TextBoundary b, int c)
	{
		bv._cursorPoint = bv.buffer.offsetBy(bv._cursorPoint, c, b);
		bv.setPreferredCursorColumnFromIndex();
	}

	override void redo(BufferView bv)
	{
		preferredColumn = bv.preferredCursorColumn;
		offset = bv.cursorPoint;
		perform(bv, boundary, count);
	}

	override void undo(BufferView bv)
	{
		bv._cursorPoint = offset;
		bv.preferredCursorColumn = preferredColumn;
		// bv.setPreferredCursorColumnFromIndex();
	}
}

unittest
{
	// Test reversibility
	BufferView v = new BufferView("01234\n67\n9ABCDEF\n");
	v.copyBuffer = new CopyBuffer;
	Action i1 = new CursorAction(TextBoundary.word, 1);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 0;
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 5);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 7;
	v.cursorPoint = 2;
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 5);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 2);
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");

	i1 = new CursorAction(TextBoundary.line, 1);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 7;
	v.cursorPoint = 4;
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 5);
	Assert(v.preferredCursorColumn, 5, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 4);
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");

	i1 = new CursorAction(TextBoundary.line, 2);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 7;
	v.cursorPoint = 4;
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 8);
	Assert(v.preferredCursorColumn, 2, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 4);
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");

	i1 = new CursorAction(TextBoundary.line, -2);

	// ""01234\n67\n9ABCDEF\n""
	v.preferredCursorColumn = 7;
	v.cursorPoint = 7;
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
	i1.redo(v);
	Assert(v.cursorPoint, 0);
	Assert(v.preferredCursorColumn, 0, "preferred colum is 0");
	i1.undo(v);
	Assert(v.cursorPoint, 7);
	Assert(v.preferredCursorColumn, 7, "preferred colum is 0");
}

unittest
{
	// Misc. mixed actions on BufferView
	BufferView v = new BufferView("");
	v.copyBuffer = new CopyBuffer;
	Action i1 = new InsertAction("testing");

	// Testing insertion redo and undo
	i1.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	i1.undo(v);
	Assert(v.buffer.toArray(), ""d	);

	i1.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing insertion redo and undo with offset
	Action o1 = new CursorAction(TextBoundary.chr, -5);
	o1.redo(v);
	Action i2 = new InsertAction("foo");
	i2.redo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	i2.undo(v);
	Assert(v.buffer.toArray(), "testing"d);

	i2.redo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	// Testing remove redo/undo with positive length
	Action o2 = new CursorAction(TextBoundary.chr, -3);
	o2.redo(v);
	Action r2 = new RemoveAction(TextBoundary.chr, 3);
	r2.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	r2.undo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	r2.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing remove redo/undo with negative length
	Action o3 = new CursorAction(TextBoundary.chr, 3);
	o3.redo(v);
	Action r3 = new RemoveAction(TextBoundary.chr, -1);
	r3.redo(v);
	Assert(v.buffer.toArray(), "testng"d);

	r3.undo(v);
	Assert(v.buffer.toArray(), "testing"d);
}

class ActionStack
{
	// Stack of all actions. The top one will always be a non-cursor action.
	private static class Item
	{
		this(Action a) { action = a; }
		Action action;
		Item prev;
		Item next;
	}
	///Array!Action actions;
	// int curIdx = 0; // last index of actions + 1 if at top of stack
	Item last;

	// Keep track of all cursor actions (e.g. cursorLeft/toEndOfLine) and
	// insert the on stack before a non-cursor (ie. modifying) action when such one is pushed.
	// This solves the situation where you undo some steps, then move the cursor and the redo some steps.
	// When redoing in that situation you simply throw away topCursorActions and redo actions after that. 
	// If it was not done this way any subsequent cursor actions after an undo would be inserted as 
	// new actions on the undo array immediately and "overwrite" the real undo stack top.
	// Array!Action topCursorActions;
	Action[] topCursorActions;

	// Bundle sequential insert and remove sequences
	Action activeAction;

	this()
	{
		last = new Item(null);
		
		//actions.reserve(10);
		//actions.length = 0;
	}

	void clear()
	{
		while (last.prev !is null)
			last = last.prev;

		if (last.next !is null)
			last.next.prev = null;
		last.next = null;
		topCursorActions.length = 0;
		assumeSafeAppend(topCursorActions);
	}

	uint cursorPointAfterLastAction;

	version (unittest)
	{
	// TODO FIX
	private void offset(BufferView bv, int offset)
	{
		if (offset == 0)
			return;

		CursorAction offsetAction = topCursorActions.empty ? null : cast(CursorAction) topCursorActions.back();
		if (offsetAction is null || offsetAction.boundary != TextBoundary.chr)
		{
			topCursorActions ~= new CursorAction(TextBoundary.chr, offset);
			topCursorActions.back().redo(bv);

		}
		else
		{
			offsetAction.offset += offset;
			bv._cursorPoint += offset;
		}
	}
	}

//    private void offset(int offset)
//    {
//        if (offset == 0)
//            return;
//
//        //CursorRightAction offsetAction = topCursorActions.empty ? null : cast(CursorRightAction) topCursorActions.back();
//    
//        // Merge all offsets into last cursor action if that was a simple move-by-char action. Else create a new cursor action.
//        CursorAction cursorAction = topCursorActions.empty ? null : cast(CursorAction) topCursorActions[$-1];
//        if (cursorAction is null || cursorAction.boundary != TextBoundary.chr)
//        {
////			topCursorActions.insertBack(new CursorRightAction(offset));
//            topCursorActions ~= new CursorRightAction(offset);
//        }
//        else
//        {
//            cursorAction.offset += offset;
//        }
//    }

	private Action createAction(T, Args...)(BufferView bv, Args args)
	{
		// Aggregate inserts and removes if possible
		// TODO: Do this for all other actions that supports the update() method as well.		
		T activeTAction = cast(T) activeAction;
		if (activeTAction is null || !activeTAction.update(bv, args))
		{
			activeAction = new T(args);
			return activeAction;
		}
		return null; // update of top action done and no new action created.
	}

	void push(T, Args...)(BufferView bv, Args args)
	{
		scope (exit)
			cursorPointAfterLastAction = bv.cursorPoint;

		int off = bv.cursorPoint - cursorPointAfterLastAction;
		if (off != 0)
			createAction!CursorAction(bv, TextBoundary.chr, off);

		Action a = createAction!T(bv, args);
		if (a is null)
			return;
	
		// A new action will truncate any redoes above current idx in stack. But only if it is an action that modifies 
		// the buffer.
		if (a.modifying)
		{
			foreach (ac; topCursorActions)
			{
				if (last.next !is null)
					last.next.prev = null; 
				last.next = new Item(ac);
				last.next.prev = last;
				last = last.next;
			}

			topCursorActions.length = 0;
			assumeSafeAppend(topCursorActions);

			a.redo(bv);

			// Put on stack after performed because any embedded action will get
			// push to stack before this actions which is what we want.
			if (last.next !is null)
				last.next.prev = null; 
			last.next = new Item(a);
			last.next.prev = last;
			last = last.next;
		}
		else
		{
			a.redo(bv);
			topCursorActions ~= a;
		}

		
	}

	bool canRepeat()
	{
		return last.action !is null;
	}

	bool canRedo()
	{
		return last.next !is null;
	}

	bool canUndo()
	{
		return last.action !is null;
	}

	private void undoTopCursorActions(BufferView bv)
	{
		foreach (a; topCursorActions.retro)
		{
			a.undo(bv);
		}
		topCursorActions.length = 0;
		assumeSafeAppend(topCursorActions);
	}

	void redo(BufferView bv)
	{
		assert(canRedo());
		
		undoTopCursorActions(bv);

		// Redo all non-modifying actions until and including the next modifying action 
		while (last.next !is null)
		{
			last.next.action.redo(bv);
			bool modifying = last.next.action.modifying;
			last = last.next;
			if (modifying)
				break;
		}

		cursorPointAfterLastAction = bv.cursorPoint;
		activeAction = null;
	}

	void undo(BufferView bv)
	{
		assert(canUndo());

		// First undo any non-modifying actions
		undoTopCursorActions(bv);

		while (last.action !is null)
		{
			last.action.undo(bv);
			auto modifying = last.action.modifying;
			last = last.prev;
			if (modifying)
				break;
		}

		cursorPointAfterLastAction = bv.cursorPoint;
		activeAction = null;
	}
}

version(unittest)
{
	void insert(ActionStack st, BufferView bv, dstring txt)
	{
		st.push!InsertAction(bv, txt);
	}

	void remove(ActionStack st, BufferView bv, int len)
	{
		st.push!RemoveAction(bv, TextBoundary.chr, len);
	}
}

// Testing ActionStack external to viewbuffer
unittest
{
	auto v = new BufferView("");
	v.copyBuffer = new CopyBuffer;
	auto st = new ActionStack();

	st.insert(v, "testing"d);
	Assert(v.buffer.toArray(), "testing"d);

	st.undo(v);
	Assert(v.buffer.toArray(), ""d	);

	st.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing insertion redo and undo with offset
	st.push!CursorAction(v, TextBoundary.chr, -5);
	st.insert(v, "foo"); 
	Assert(v.buffer.toArray(), "tefoosting"d);

	st.undo(v);
	Assert(v.buffer.toArray(), "testing"d);

	st.redo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	// Testing remove redo/undo with positive length
	st.push!CursorAction(v, TextBoundary.chr, -3);
	st.remove(v, 3);
	Assert(v.buffer.toArray(), "testing"d);

	st.undo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	st.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing remove redo/undo with negative length
	st.push!CursorAction(v, TextBoundary.chr, 3);
	st.remove(v, -1);
	Assert(v.buffer.toArray(), "testng"d);

	st.undo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing undo with after moveing cursor
	st.push!CursorAction(v, TextBoundary.chr, -4);
	st.remove(v, -1);
	Assert(v.buffer.toArray(), "esting"d);

	st.offset(v, 1);
	st.undo(v);
	Assert(v.buffer.toArray(), "testing"d);
}

// Testing viewbuffer undo stack
unittest
{
	auto v = new BufferView("");
	v.copyBuffer = new CopyBuffer;
	v.insert("testing"d);
	Assert(v.buffer.toArray(), "testing"d);

	v.undo();
	Assert(v.buffer.toArray(), ""d	);

	v.redo();
	Assert(v.buffer.toArray(), "testing"d);

	// Testing insertion redo and undo with offset
	v.cursorLeft(5);
	v.insert("foo"); 
	Assert(v.buffer.toArray(), "tefoosting"d);

	v.undo();
	Assert(v.buffer.toArray(), "testing"d);

	v.redo();
	Assert(v.buffer.toArray(), "tefoosting"d);

	// Testing remove redo/undo with positive length
	v.cursorLeft(3);
	v.remove(3);
	Assert(v.buffer.toArray(), "testing"d);

	v.undo();
	Assert(v.buffer.toArray(), "tefoosting"d);

	v.redo();
	Assert(v.buffer.toArray(), "testing"d);

	// Testing remove redo/undo with negative length
	v.cursorRight(3);
	v.remove(-1);
	Assert(v.buffer.toArray(), "testng"d);

	v.undo();
	Assert(v.buffer.toArray(), "testing"d);

	// Testing undo with after moveing cursor
	v.cursorLeft(4);
	v.remove(-1);
	Assert(v.buffer.toArray(), "esting"d);

	v.cursorRight(3);
	v.undo();
	Assert(v.buffer.toArray(), "testing"d);
}
