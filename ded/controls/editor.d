module controls.editor;

import application;
import bufferview;
import graphics._;
import gui.command : CommandManager;
import gui.widget;
import gui.widgetfeature;
import math._;

class Editor
{
	Widget mainWidget;

	Widget[string] bufferWidgets;
	
	this(float h)
	{
		mainWidget = new Widget();
		mainWidget.acceptsKeyboardFocus = true;

		auto renderer = new BoxRenderer();
		renderer.model.material = graphics._.Material.create("bg3.png");
		mainWidget.features ~= renderer;
	}

	void show(BufferView bufferView)
	{
		Widget* bufferWidget = bufferView.name in bufferWidgets;

		if (bufferWidget is null)
		{
			// create a widget for this buffer

			auto newWidget = new Widget();
		
			auto c = new Constraint(mainWidget.id,
		    	                    Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom,
		        	                Constraint.HorizontalAnchor.Right, Constraint.VerticalAnchor.Bottom);
			newWidget.features ~= c;
		
			newWidget.parent = mainWidget;

			newWidget.content = bufferView;
			bufferWidgets[bufferView.name] = newWidget;
			bufferWidget = &newWidget;
		}

		foreach (b; bufferWidgets)
		{
			if (!b.visible && b is *bufferWidget)
				b.visible = true;
			else if (b.visible && b !is *bufferWidget)
				b.visible = false;
		}
	}
}

