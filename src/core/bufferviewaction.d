module core.bufferviewaction;

import core.buffer;
import core.bufferview;

import std.algorithm;
import std.array;
import std.container;
import std.range;
import std.typecons;

version(unittest) import test;

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
/*
class SelectToAction : Action
{
	Region r;

	this(Region r)
	{
		modifying = false;
		this.r = r;
	}

	override void redo(BufferView bv)
	{
		_undoStack.push!CursorRightAction(this, v - _cursorPoint);
		bv.selectTo(
	}

	override void undo(BufferView bv)
	{
		bv._cursorPoint = bv.cursorPoint - offset;
	}
}
*/
class CursorRightAction : Action
{
	int offset;

	this(int off)
	{
		modifying = false;
		offset = off;
	}

	override void redo(BufferView bv)
	{
		auto v = bv.cursorPoint + offset;
		if (!bv.isValidCursorPoint(v))
			return;
		bv._cursorPoint = v;
		bv.setPreferredCursorColumnFromIndex();
	}
	
	override void undo(BufferView bv)
	{
		auto v = bv.cursorPoint - offset;
		if (!bv.isValidCursorPoint(v))
			return;
		bv._cursorPoint = v;
		bv.setPreferredCursorColumnFromIndex();
	}
}

class CursorDownAction : Action
{
	int offset;

	this(int off)
	{
		modifying = false;
		offset = off;
	}

	override void redo(BufferView bv)
	{
		auto v = bv.buffer.linesOffset(bv._cursorPoint, offset, bv.preferredCursorColumn);
		if (!bv.isValidCursorPoint(v))
			return;
		bv._cursorPoint = v;
	}

	override void undo(BufferView bv)
	{
		auto v = bv.buffer.linesOffset(bv._cursorPoint, -offset, bv.preferredCursorColumn);
		if (!bv.isValidCursorPoint(v))
			return;
		bv._cursorPoint = v;
	}
}

class InsertAction : Action
{
	immutable(TextGapBuffer.CharType)[] text;

	this(immutable(TextGapBuffer.CharType)[] txt)
	{
		text = txt;
	}

	// Update this insert action by adding txt to existing text and redo action with
	// the concatenated text. Note that a redo() must have been performed on the existings text
	// before calling this as it is assumed that text is already in buffer.
	private void update(BufferView bv, immutable(TextGapBuffer.CharType)[] txt)
	{
		text ~= txt;
		perform(bv, txt);	
	}

	private void perform(BufferView bv, immutable(TextGapBuffer.CharType)[] txt)
	{
		auto insertPoint = bv.cursorPoint;
		bv.buffer.insert(txt, insertPoint);
		bv._cursorPoint = insertPoint + txt.length;
		bv.changed();
		bv.onInsert.emit(bv, txt, insertPoint);
	}

	override void redo(BufferView bv)
	{
		perform(bv, text);
	}

	override void undo(BufferView bv)
	{
		bv._cursorPoint = bv.cursorPoint - text.length;
		bv.buffer.remove(text.length, bv.cursorPoint);
		bv.changed();
		bv.onRemove.emit(bv, text, bv.cursorPoint);
	}
}

class RemoveAction : Action
{
	int length;
	immutable(TextGapBuffer.CharType)[] text; // used to remember what to undo

	this(int len)
	{
		length = len;
	}

	private void update(BufferView bv, int len)
	{
		length += len;
		perform(bv, len);
	}
	
	private void perform(BufferView bv, int len)
	{
		import std.math;
		// record the content for later undoing
		auto l = abs(len);
		auto o = bv.cursorPoint + (len < 0 ? -l : 0);
		auto t = array(bv.buffer[o..o+l]).idup;
		if (len < 0)
			text = t ~ text;
		else
			text ~= t;

		bv.buffer.remove(l, o);
		bv._cursorPoint = o;
		bv.changed();
		bv.onRemove.emit(bv, t, o);
	}

	override void redo(BufferView bv)
	{
		perform(bv, length);
	}

	override void undo(BufferView bv)
	{
		bv.buffer.insert(text, bv.cursorPoint);
		auto origCursorPoint = bv.cursorPoint;
		auto restoredCursorPoint = origCursorPoint;
		if (length < 0)
			restoredCursorPoint -= length; // length is negative here
		bv._cursorPoint = restoredCursorPoint; 
		bv.changed();
		bv.onInsert.emit(bv, text, origCursorPoint);
	}
}

class RemoveSelectedAction : Action
{
	bool cursorAtStartOfSelection;
	immutable(TextGapBuffer.CharType)[] text; // used to remember what to undo

	override void redo(BufferView bv)
	{
		import std.math;
		// record the content for later undoing
		
		auto l = bv.selection.length;
		auto o = bv.selection.a;
		cursorAtStartOfSelection = bv.cursorPoint == o;
		text = array(bv.buffer[bv.selection.a..bv.selection.b]).idup;
		bv.buffer.remove(l, o);
		bv.selection.b = bv.selection.a;
		bv._cursorPoint = o;
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
			bv.selection.a = bv._cursorPoint;
			bv.selection.b = bv._cursorPoint + text.length;
		}
		else
		{
			bv._cursorPoint += text.length; 
			bv.selection.b = bv._cursorPoint;
			bv.selection.a = bv._cursorPoint - text.length;
		}
	}
}

class ClearAction : Action
{
	int offset;
	immutable(TextGapBuffer.CharType)[] text; // used to remember what to undo

	this()
	{
	}

	override void redo(BufferView bv)
	{
		text = array(bv.buffer[0..bv.buffer.length]).idup;
		offset = bv.cursorPoint;
		auto len = bv.length;
		bv.buffer.remove(len, 0);
		bv._cursorPoint = 0;
		bv.changed();
		bv.onRemove.emit(bv, text, 0);
	}

	override void undo(BufferView bv)
	{
		bv.buffer.insert(text, 0);
		bv._cursorPoint = offset; 
		bv.changed();
		bv.onInsert.emit(bv, text, 0);
	}
}

class CursorToStartAction : Action
{
	int offset;
	immutable(TextGapBuffer.CharType)[] text; // used to remember what to undo

	this()
	{
		modifying = false;
	}

	override void redo(BufferView bv)
	{
		offset = bv.cursorPoint;
		bv._cursorPoint = 0;
		bv.setPreferredCursorColumnFromIndex();
	}

	override void undo(BufferView bv)
	{
		bv._cursorPoint = offset;
		bv.setPreferredCursorColumnFromIndex();
	}
}

class CursorToEndAction : Action
{
	int offset;
	immutable(TextGapBuffer.CharType)[] text; // used to remember what to undo

	this()
	{
		modifying = false;
	}

	override void redo(BufferView bv)
	{
		offset = bv.cursorPoint;
		bv._cursorPoint = bv.length;
		bv.setPreferredCursorColumnFromIndex();
	}

	override void undo(BufferView bv)
	{
		bv._cursorPoint = offset;
		bv.setPreferredCursorColumnFromIndex();
	}
}

// Test Actions on BufferView
unittest
{
	BufferView v = new BufferView("");
	Action i1 = new InsertAction("testing");

	// Testing insertion redo and undo
	i1.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	i1.undo(v);
	Assert(v.buffer.toArray(), ""d	);

	i1.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing insertion redo and undo with offset
	Action o1 = new CursorRightAction(-5);
	o1.redo(v);
	Action i2 = new InsertAction("foo");
	i2.redo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	i2.undo(v);
	Assert(v.buffer.toArray(), "testing"d);

	i2.redo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	// Testing remove redo/undo with positive length
	Action o2 = new CursorRightAction(-3);
	o2.redo(v);
	Action r2 = new RemoveAction(3);
	r2.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	r2.undo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	r2.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing remove redo/undo with negative length
	Action o3 = new CursorRightAction(3);
	o3.redo(v);
	Action r3 = new RemoveAction(-1);
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
	// This solved the situation where you undo some steps, the moves the cursor and the redo some steps.
	// When redoing in that situation you simply throw away topCursorActions and redo actions. If it was not
	// done this way any subsequent cursor actions after an undo would be inserted as new actions on the
	// undo array immediately and "overwrite" the real undo stack top.
	//Array!Action topCursorActions;
	Action[] topCursorActions;

	// Bundle sequential insert and remove sequences
	InsertAction activeInsertAction;
	RemoveAction activeRemoveAction;

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
	void offset(BufferView bv, int offset)
	{
		if (offset == 0)
			return;

		CursorRightAction offsetAction = topCursorActions.empty ? null : cast(CursorRightAction) topCursorActions.back();
		if (offsetAction is null)
		{
			topCursorActions.insertBack(new CursorRightAction(offset));
			topCursorActions.back().redo(bv);

		}
		else
		{
			offsetAction.offset += offset;
			bv._cursorPoint += offset;
		}
	}
	}

	private void offset(int offset)
	{
		if (offset == 0)
			return;

		//CursorRightAction offsetAction = topCursorActions.empty ? null : cast(CursorRightAction) topCursorActions.back();
		CursorRightAction offsetAction = topCursorActions.empty ? null : cast(CursorRightAction) topCursorActions[$-1];
		if (offsetAction is null)
		{
//			topCursorActions.insertBack(new CursorRightAction(offset));
			topCursorActions ~= new CursorRightAction(offset);
		}
		else
		{
			offsetAction.offset += offset;
		}
	}

	private Action createAction(T, Args...)(BufferView bv, Args args)
	{
		static if (is (T : InsertAction))
		{
			activeRemoveAction = null;

			if (activeInsertAction is null)
				activeInsertAction = new InsertAction(args);
			else
			{
				activeInsertAction.update(bv, args[0]);
				return null;
			}
			return activeInsertAction;
		}
		else static if (is (T : RemoveAction))
		{
			activeInsertAction = null;
			if (activeRemoveAction is null || (args[0] <= 0) != (activeRemoveAction.length <= 0))
				activeRemoveAction = new RemoveAction(args);
			else
			{
				activeRemoveAction.update(bv, args[0]);
				return null;
			}
			return activeRemoveAction;
		}
		else
		{
			activeRemoveAction = null;
			activeInsertAction = null;
			return new T(args);
		}
	}

	void push(T, Args...)(BufferView bv, Args args)
	{
		scope (exit)
			cursorPointAfterLastAction = bv.cursorPoint;

		int off = bv.cursorPoint - cursorPointAfterLastAction;
		offset(off);

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
		st.push!RemoveAction(bv, len);
	}
}

// Testing ActionStack external to viewbuffer
unittest
{
	auto v = new BufferView("");
	auto st = new ActionStack();

	st.insert(v, "testing"d);
	Assert(v.buffer.toArray(), "testing"d);

	st.undo(v);
	Assert(v.buffer.toArray(), ""d	);

	st.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing insertion redo and undo with offset
	st.push!CursorRightAction(v, -5);
	st.insert(v, "foo"); 
	Assert(v.buffer.toArray(), "tefoosting"d);

	st.undo(v);
	Assert(v.buffer.toArray(), "testing"d);

	st.redo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	// Testing remove redo/undo with positive length
	st.push!CursorRightAction(v, -3);
	st.remove(v, 3);
	Assert(v.buffer.toArray(), "testing"d);

	st.undo(v);
	Assert(v.buffer.toArray(), "tefoosting"d);

	st.redo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing remove redo/undo with negative length
	st.push!CursorRightAction(v, 3);
	st.remove(v, -1);
	Assert(v.buffer.toArray(), "testng"d);

	st.undo(v);
	Assert(v.buffer.toArray(), "testing"d);

	// Testing undo with after moveing cursor
	st.push!CursorRightAction(v, -4);
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
