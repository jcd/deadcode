module behavior.behavior;

public import buffer;
import bufferview;
public import graphics._;
import gui.event;

class EditorBehavior
{
	static EditorBehavior[string] editorBehaviors;
	
	private static EditorBehavior _current;
	static @property EditorBehavior current()
	{
		if (_current is null)
		{
			import std.stdio;
			writeln("Falling back to the null editor behavior");
			_current = editorBehaviors["null"];
		}
		return _current;
	}

	static @property current(EditorBehavior b) nothrow @safe
	{
		_current = b;
	}
		
	static @property current(string name) 
	{
		_current = editorBehaviors[name];
	}

	abstract void onEvent(Event event, BufferView view);
}

class NullBehavior : EditorBehavior
{
	static this()
	{
		// Register
		EditorBehavior.editorBehaviors["null"] = new NullBehavior();
	}
	
	override void onEvent(Event event, BufferView controller)
	{
		std.stdio.writeln("NullBehavior ", event);
	}
}