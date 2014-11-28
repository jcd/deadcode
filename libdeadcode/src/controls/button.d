module controls.button;

import gui.event;
import gui.label;
import gui.style;
import gui.widget;

class Button : Label
{
	this(string text)
	{
		super(text);
	}

	override EventUsed onEvent(Event event)
	{
		EventUsed used = void;
		switch (event.type)
		{
			case EventType.MouseDown:
				used = EventUsed.yes;
				break;
			case EventType.MouseUp:
				used = EventUsed.yes;
				break;
			case EventType.MouseClick:
				used = EventUsed.yes;
				break;
			case EventType.MouseDoubleClick:
				used = EventUsed.yes;
				break;
			case EventType.MouseTripleClick:
				used = EventUsed.yes;
				break;
			case EventType.MouseMove:
				used = EventUsed.yes;
				break;
			case EventType.MouseOver:
				used = EventUsed.yes;
				break;
			case EventType.MouseOut:
				used = EventUsed.yes;
				break;
			default:
				used = super.onEvent(event);
				break;
		}
		return used;
	}
}
