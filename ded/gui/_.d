module gui._;

import core.time;

import graphics._; // Event;
import gui.event;
public import gui.style;
import gui.widget; // : Widget, NullWidgetID;

// The widget that the mouse left button has been clicked down on
private static uint downButtonWidget = NullWidgetID;

// The widget that has been clicked by the left mouse button
private static uint clickWidget = NullWidgetID;

// The time of the last click on a widget
private static TickDuration clickWidgetTime;

// The max time that can pass when another click 
// is accepted as a double click
enum maxDoubleClickTime = 0.3f;

/** Send an event to the GUI system
 * 
 *  Returns: true if event is still valid ie. hasn't been used by an event handling function.
 */
bool send(Event event)
{
	bool used = false;
	WidgetID lastMouseWidget = Widget.mouseWidget;
	Widget.mouseWidget = NullWidgetID;

/*
	static bool bubbleEvent(Widget* wi, Event ev)
	{
		Widget w = *wi;
		bool valid = true;
		do 
		{
			valid = w.send(ev);
			w = w.parent;
		} 
		while (valid && w !is null); 
		return valid;
	}
*/		
	// Find widget that mouse is over
	foreach (ref w; Widget.widgets)
	{
		if (w.rect.contains(event.mousePos))
		{
			Widget.mouseWidget = w.id;
		}
	}
	if (Widget.mouseGrabbedBy)
		Widget.mouseWidget = Widget.mouseGrabbedBy;
	
	Widget * overWidget = null; 
	if (Widget.mouseWidget)
		overWidget = Widget.mouseWidget in Widget.widgets;
	
	// Send events to the found widget
	std.stdio.writeln(event.type);
	switch (event.type)
	{
	case Event.Type.MouseMove:
		if (lastMouseWidget != Widget.mouseWidget)
		{
			// If a click has been initiated by a mouse down and the mouse 
			// goes away from the widget the click is aborted.
			downButtonWidget = NullWidgetID;
			clickWidget = NullWidgetID;

			// Handle mouse out events
			if (lastMouseWidget != NullWidgetID)
			{
				Widget * outWidget = lastMouseWidget in Widget.widgets;
				
				// Bubbling to parents lets a parent handle all out events for its children 
				// which can be convenient
				if (outWidget)
				{
					event.type = Event.Type.MouseOut;
					outWidget.send(event);
				}
			}
			 
			// Handle mouse over event and mouse move event
			if (overWidget)
			{
				event.type = Event.Type.MouseOver;
				overWidget.send(event);
				event.type = Event.Type.MouseMove;
				used = overWidget.send(event);
			}
		}
		else if (overWidget)
		{
			// Handle mouse move event
			used = overWidget.send(event);
		}
		else
		{
			// If a click has been initiated by a mouse down and the mouse 
			// goes away from the widget the click is aborted.
			downButtonWidget = NullWidgetID;
			clickWidget = NullWidgetID;				
		}
		break;
	case Event.Type.MouseDown:
		if (overWidget)
		{
			downButtonWidget = Widget.mouseWidget;
			used = overWidget.send(event);
		}
		else
		{
			downButtonWidget = NullWidgetID;
			clickWidget = NullWidgetID;
		}
		break;
	case Event.Type.MouseUp:
		if (overWidget)
		{
			used = overWidget.send(event);
			if (downButtonWidget == Widget.mouseWidget)
			{
				TickDuration tdur = TickDuration.currSystemTick;
				float doubleClickTime = tdur.to!("seconds",float)() - clickWidgetTime.to!("seconds",float)();
				if (downButtonWidget == clickWidget && doubleClickTime < maxDoubleClickTime)
				{
					event.type = Event.Type.MouseDoubleClick;
					used = overWidget.send(event) || used;
					clickWidget = 0;
				}
				else
				{
					event.type = Event.Type.MouseClick;
					used = overWidget.send(event) || used;
					clickWidget = downButtonWidget;
					clickWidgetTime = TickDuration.currSystemTick;
					Widget.setKeyboardFocusWidget(clickWidget);
				}
			}
		}
		downButtonWidget = NullWidgetID;
		break;
	case Event.Type.MouseScroll:
	case Event.Type.KeyDown:
	case Event.Type.KeyUp:
	case Event.Type.Text:

			std.stdio.writeln("dxx ", event.type, " ", Widget.keyboardFocusWidget);
		if (Widget.keyboardFocusWidget != NullWidgetID)
		{
			Widget * w = Widget.keyboardFocusWidget in Widget.widgets;

			if (w is null)
				Widget.setKeyboardFocusWidget(NullWidgetID);
			else
				used = w.send(event);
		}
		break;
	case Event.Type.Resize:
		bool cont = false;
		int maxIter = 5;
		// Resize events will let widget do relayouts. 
		do
		{
			cont = false;
			foreach (w; Widget.widgets)
			{
				cont |= w.send(event);
			}
		} while (cont && maxIter--);
	default:
		break;
	}
	
	// TODO: fix
	// FIX: this
	//if (Widget.keyboardFocusWidget == NullWidgetID && Widget.widgets.length != 0 ) {}
		//Widget.setKeyboardFocusWidget(Widget.widgets[Widget.widgets.keys()[0]].id); 
	return used;
}

/** Draw all widgets
 * 
 */
void draw(StyleSet styleSet = null)
{
	if (styleSet is null)
		styleSet = StyleSet.base;
	
	foreach (ref w; Widget.widgets)
	{
		if (w._parentId == NullWidgetID)
			w.draw(styleSet);
	}
}

/** Update all widgets
 * 
 * An update on a widget
 */
void update()
{
	foreach (ref w; Widget.widgets)
	{
		w.update();
	}
}

/*
class WidgetManager
{
	WindowManager singleton;
	static @property WindowManager the()
	{
		if (singleton is null)
			singleton = new WidgetManager();
		return singleton;
	}
	
	Widget[uint] widgets;

	uint mouseFocusWidget = 0;
	
	void update()
	{
		
	}
		
}
*/