module behavior.behavior;

public import editor;
public import graphics;
public import text;

class EditorBehavior
{
	static EditorBehavior[string] editorBehaviors;
	
	private static EditorBehavior _current;
	static @property EditorBehavior current()
	{
		if (_current is null)
			_current = editorBehaviors["null"];
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

	abstract void onEvent(Event event, EditorController controller);
}

class NullBehavior : EditorBehavior
{
	static this()
	{
		// Register
		EditorBehavior.editorBehaviors["null"] = new NullBehavior();
	}
	
	void onEvent(Event event, EditorController controller)
	{
		std.stdio.writeln("NullBehavior ", event);
	}
}