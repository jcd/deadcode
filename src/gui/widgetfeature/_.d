module gui.widgetfeature._;

import gui.event;
import gui.widget;
import gui.style;

class WidgetFeature
{
	EventUsed send(Event event, Widget widget) { return EventUsed.no; }
	void update(Widget widget) {}
	void draw(Widget widget, StyleSet styleSet) {}
}

public import gui.widgetfeature.boxrenderer;
public import gui.widgetfeature.constraintlayout;
public import gui.widgetfeature.directionallayout;
public import gui.widgetfeature.dragger;
public import gui.widgetfeature.textrenderer;
public import gui.widgetfeature.windowdragger;
public import gui.widgetfeature.windowresizer;

