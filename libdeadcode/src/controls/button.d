module controls.button;

import gui.event;
import gui.label;
import gui.style;
import gui.widget;

import core.signals;

class Button : Label
{
	enum State
	{
		notLoaded,
		loadedWithMouseOver,
		loadedWithNoMouseOver
	}
	private State _state = State.notLoaded;

	//mixin Signal!(Button) onActivated;

	this(string text)
	{
		super(text);
	}

	static Button isover;

	override EventUsed onEvent(Event event)
	{
		EventUsed used;
		switch (event.type)
		{
			case EventType.MouseDown:
				_state = State.loadedWithMouseOver;
				used = EventUsed.no;
				break;
			case EventType.MouseUp:
				if (_state == State.loadedWithMouseOver)
					activate();	
				_state = State.notLoaded;					
				used = EventUsed.no;
				break;
			case EventType.MouseClick:
				used = EventUsed.no;
				break;
			case EventType.MouseDoubleClick:
				used = EventUsed.no;
				break;
			case EventType.MouseTripleClick:
				used = EventUsed.no;
				break;
			case EventType.MouseMove:
				used = EventUsed.no;
				break;
			case EventType.MouseOver:
				if (_state == State.loadedWithNoMouseOver)
					_state = State.loadedWithMouseOver;
				isover = this;
				used = EventUsed.no;
				break;
			case EventType.MouseOut:
				if (_state == State.loadedWithMouseOver)
					_state = State.loadedWithNoMouseOver;
				used = EventUsed.no;
				break;
			default:
				//used = super.onEvent(event);
				break;
		}
		
		//if (!used)
			used = super.onEvent(event);
		return used;
	}

	// TODO: This is a hack because std.signals does not support derived signals
	protected void activate()
	{
	}
}

class ToggleButton : Button
{
	bool isOn = false;
	mixin Signal!(ToggleButton) onToggled;
	
	enum _classes = [["on"],["off"]];

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes[isOn ? 0 : 1];
	}

	this(string text)
	{
		super(text);
		// onActivated.connect(&activate);
	}

	override protected void activate()
	{
		isOn = !isOn;
		onToggled.emit(this);
	}
}

