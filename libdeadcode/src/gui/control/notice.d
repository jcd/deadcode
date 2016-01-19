module gui.control.notice;

import gui.widget;
import gui.gui;

class Notice : Widget
{
    import controls.button;
    import gui.label;
    import gui.layout.gridlayout;

    private Label _label;
    private Widget _icon, _fill, _buttons;
    private Button _button1, _button2;

	GUI.TimeoutHandle timeoutHandle;

    enum Mode : ubyte
    {
        noAction,
        oneAction,
        twoAction,
    }
    private Mode _mode = Mode.noAction;
    bool _isSmall = false;

	private enum _classes = [["default"],["small"], ["one-action"], ["one-action-small"], ["two-action"], ["two-action-small"] ];

    @property void mode(Mode m)
    {
        _mode = m;
    }

    @property void small(bool f)
    {
        _isSmall = f;
    }

    void showBig(string msg = null)
    {
	    if (msg !is null)
	        setMessage(msg);
		timeoutHandle.abort();
        mode = Mode.noAction;
        small = false;
        visible = true;
    }

    void showSmall(string msg = null)
    {
	    if (msg !is null)
	        setMessage(msg);
		timeoutHandle.abort();
        mode = Mode.noAction;
        small = true;
        visible = true;
    }

    void show(string msg, bool asSmall = false)
    {
        setMessage(msg);
		timeoutHandle.abort();
        mode = Mode.noAction;
        small = asSmall;
    }

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes[_mode * 2 + (_isSmall ? 1 : 0)];
	}

    this(WidgetID _parent = NullWidgetID)
	{
		super(_parent);

        name = "noticeDialog";

        auto l = new GridLayout(GridLayout.Direction.row, 2);
        layout = l;

        _icon = new Widget(this);
        _icon.name = "notice-icon";
        _label = new Label("");
        _label.name = "notice-label";
        _label.parent = this;

        _fill = new Widget(this);
        _buttons = new Widget(this);
        _buttons.visible = false;
        _buttons.name = "notice-buttons";
        auto lo = new GridLayout(GridLayout.Direction.row, 1);
        lo.cellHorizontalSpacing = 8;
        _buttons.layout = lo;
        _button1 = new Button("Cancel");
        _button1.parent = _buttons;
        _button2 = new Button("Ok");
        _button2.parent = _buttons;

        visible = false;
    }

    void setMessage(string m)
    {
        _label.text = m;
    }

    void setOkText(string t)
    {
        _button2.text = t;
    }

    void setCancelText(string t)
    {
        _button1.text = t;
    }
}

