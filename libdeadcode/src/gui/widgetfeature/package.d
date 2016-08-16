module gui.widgetfeature;

import gui.event : Event;
import gui.widget : Widget;
import gui.style;

class WidgetFeature
{
	EventUsed send(Event event, Widget widget) { return EventUsed.no; }
	void update(Widget widget) {}
	void draw(Widget widget) {}
}

public import gui.widgetfeature.boxrenderer;
public import gui.widgetfeature.dragger;
public import gui.widgetfeature.textrenderer;
public import gui.widgetfeature.windowdragger;
public import gui.widgetfeature.windowresizer;
public import gui.widgetfeature.ninegridrenderer;

