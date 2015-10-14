module controls.popup;

import controls.button;

import gui.event;
import gui.widget;
import gui.layout.gridlayout;

import core.signals;

class PopupList : Widget
{
    private int usedItems;

    // Widget to give focus to when this popup looses focus and there is no other focus set.
    private WidgetID _unfocusWidgetID;

    @property int unfocusWidgetID()
    {
        return _unfocusWidgetID;
    }

    @property unfocusWidgetID(int i)
    {
        if (i != id)
            _unfocusWidgetID = i;
    }

	override @property void visible(bool v)
	{
        if (visible == v)
            return;
        super.visible = v;

        // If this widget has keyboard focus then release it.
        if (!visible)
        {
            if (childOrThisHasFocus())
                window.setKeyboardFocusWidget(_unfocusWidgetID);
            _unfocusWidgetID = NullWidgetID;
        }
	}

    private bool childOrThisHasFocus() nothrow
    {
        auto aid = window.getKeyboardFocusWidgetID();
        if (aid == id)
            return true;

        foreach (c; children)
        {
            if (c.id == aid)
                return true;
        }
        return false;
    }

    alias visible = Widget.visible;

    mixin Signal!(PopupList, int) onItemActivated;

    int _focusItemIndex = 0;

    this()
    {
        acceptsKeyboardFocus = true;
        onKeyboardUnfocusSignal.connect(&keyboardUnfocussed);
        layout = new GridLayout(GridLayout.Direction.column, 1);
    }

    void addItem(string name)
    {
        Button b;
        if (children.length > usedItems)
        {
            b = cast(Button)children[usedItems];
            usedItems++;
            b.text = name;
        }
        else
        {
            b = new Button(name);
            b.connect(&itemActivated);
            b.parent = this;
            b.acceptsKeyboardFocus = true;
            usedItems++;
        }
        if (usedItems == 1)
            setFocusChild(0);
    }

    void removeItem(int idx)
    {
        assert(idx < children.length);

        auto child = children[idx];
        bool hasFocus = child.hasKeyboardFocus();
        child.parent = null;
        // Deleting item holding focus
        if (_focusItemIndex == idx)
        {
            // When deleting the last child and it has focus then shift focus to next to last child
            if (_focusItemIndex + 1 == children.length)
            {
                _focusItemIndex--;
            }
            else
            {
                // Just keep focus index which means shifting focus the the item after the item that is deleted
            }

            if (hasFocus)
            {
                if (_focusItemIndex >= children.length || _focusItemIndex < 0)
                    window.setKeyboardFocusWidget(this);
                else
                    window.setKeyboardFocusWidget(children[_focusItemIndex]);
            }
        }
        else if (idx < _focusItemIndex)
        {
            // Correct focus index when deleting a child before a child that have focus
            _focusItemIndex--;
        }

		usedItems--;
    }

    void setFocusChild(int idx)
    {
        if (idx >= children.length || idx < 0)
        {
            window.setKeyboardFocusWidget(this);
        }
        else
		{
           _focusItemIndex = idx;
            if (childOrThisHasFocus())
                window.setKeyboardFocusWidget(children[idx]);
		}
    }

    string getItem(int idx)
    {
        if (idx >= children.length)
            return null;
        return (cast(Button)children[idx]).text;
    }

    string getFocusItem()
    {
        return getItem(_focusItemIndex);
    }

    void clearItems()
    {
        while (children.length)
            removeItem(0);
    }

    void cycleFocus(int step)
    {
        int idx = children.length == 0 ? 0 : (_focusItemIndex + step) % cast(int)children.length;
        setFocusChild(idx);
    }

    //EventUsed onEvent(Event event)
    //{
    //    if (!visible)
    //        EventUsed.no;
    //
    //    switch (EventType.
    //
    //}

    private void keyboardUnfocussed(Event ev)
    {
		if (!childOrThisHasFocus())
            visible = false;
	}

    private void itemActivated(Button b)
    {
        foreach (idx, c; children)
        {
            if (b is c)
            {
                onItemActivated.emit(this, cast(int)idx);
                return;
            }
        }
        assert(0);
    }
}
