module dccore.undo;

version(OFF):

import std.container;

class CommandExecution
{
	void execute() {}
	void undo() {}
}

class Undo
{
	private Array!CommandExecution stack;

	// In order not to pop entries when undoing (because we might wanna redo later)
	// we simple change the variable below to reflect next entry that can be undone.
	// When a new CommandExecution is pushed the everything from this point to the
	// top of the stack is removed before the actual push.
	int firstUndoIndex;

	void register(CommandExecution c)
	{
		// Remove redo candidates
		int toRemove = stack.length - firstUndoIndex;
		stack.removeBack(toRemove);

		stack.insertBack(c);
	}

	void undo(int steps)
	{
		if (firstUndoIndex == 0)
			return; // nothing to undo
		firstUndoIndex--;
		stack[firstUndoIndex].undo();
	}

	void redo(int steps)
	{
		if (stack.length == firstUndoIndex)
			return; // nothing to undo
		stack[firstUndoIndex].execute();
		firstUndoIndex++;
	}
}
