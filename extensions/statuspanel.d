module extensions.statuspanel;
import extensionapi;
mixin registerCommands;

import gui.layout.stacklayout;

@Shortcut("<ctrl> + m")
class StatusTogglePanelCommand : Command
{
	void run(Application app)
	{
		auto w = app.guiRoot.activeWindow.getWidget("statuspanel");
		auto p = cast(StatusPanel)(w);
		p.mode = p.mode == StatusPanel.Mode.hidden ? StatusPanel.Mode.normal : StatusPanel.Mode.hidden;
	}
}

class StatusPanel : BasicWidget
{
	static WidgetID widgetID;

	enum Mode
	{
		hidden,
		discrete,
		normal
	}
	private Mode _mode = Mode.hidden;

	enum _classes = [["hidden"],["discrete"],[]];

	@property void mode(Mode m)
	{
		if (_mode != m)
		{
			_mode = m;
			recalculateStyle();
		}
	}

	@property Mode mode() const
	{
		return _mode;
	}

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes[_mode];
	}

	override void init()
	{
		name = "statuspanel";

		layout = new StackLayout();

		app.scheduleWidgetPlacement(this, "main", RelativeLocation.bottomOf);
		_mode = Mode.hidden;

		// loadSession();
	}

	override void update()
	{
		super.update();
	}

	override void fini()
	{
		//saveSession();
	}

	static class SessionData
	{
		string messages;
	}

	private void loadSession()
	{
		//auto s = loadSessionData!SessionData();
		//if (s !is null)
		//    append(s.messages);
	}

	private void saveSession()
	{
		//auto s = new SessionData();
		//s.messages = textRenderer.text.buffer.toArray().to!string;
		//saveSessionData(s);
	}
}
