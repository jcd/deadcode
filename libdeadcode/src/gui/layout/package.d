module gui.layout;

import gui.widget;

interface ILayout
{
	void layout(Widget w, bool fit);
}

public import gui.layout.constraintlayout;
public import gui.layout.directionallayout;
public import gui.layout.gridlayout;
public import gui.layout.stacklayout;
