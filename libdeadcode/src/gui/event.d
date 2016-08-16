module gui.event;

public import dccore.event;
import dccore.commandparameter;

// import derelict.sdl2.sdl;
import gui.keycode;
import gui.widget : Widget;
import math;

//import std.traits;
// import std.variant;

mixin registerEvents!"GUI";

// All event types are assigned ids at runtime ie. we a not using an enum to
// specify an event type. This makes it possible to plug in new event types from
// extensions at runtime. This struct is simply here to register and cache all the
// GUI specific event types.
/*
struct GUIEventTypes
{
	static void initialize(EventManager m)
	{
		MouseMoveEvent.staticType = m.register(EventDescription("GUI", "mouseMove"));
		
		string str;
		foreach (member; __traits(allMembers, GUIEventTypes))
		{
			__traits(getMember, this, member) = m.register(EventDescription(member));
		}
		return str;
	}

	static EventType command;    /// Command possibly with args sent
	static EventType mouseOver;  /// Mouse entering a widget
	static EventType mouseMove;  /// Mouse moving over the widget
	static EventType mouseOut;   /// Mouse exiting a widget
	static EventType mouseDown;  /// Mouse down on a widget
	static EventType mouseUp;    /// Mouse up on a widget
	static EventType mouseClick; /// Mouse click on a widget
	static EventType mouseDoubleClick; /// Mouse double click on a widget
	static EventType mouseTripleClick; /// Mouse triple click on a widget
	static EventType mouseScroll;      /// Mouse scroll wheel
	static EventType keyboardFocus;    /// When keyboard focus is obtained
	static EventType keyboardUnfocus;  /// When keyboard focus is lost
	static EventType text;       /// Key pressed down
	static EventType keyDown;    /// Key pressed down
	static EventType keyUp;      /// Key pressed down
	static EventType resize;     /// The window has been resized
	static EventType focus;      /// The window has been focused
	static EventType layout;     /// Relayout is required
	static EventType styleSheetChanged; // The stylesheet has been changed
	static EventType asyncCompletion;   // An async job has completed
};
*/
//enum EventType
//{
//    Invalid,
//    Default,
//    Command, // Command possibly with args sent
//    //	Update,
//    //	Draw,
//    MouseOver,  /// Mouse entering a widget
//    MouseMove,  /// Mouse moving over the widget
//    MouseOut,   /// Mouse exiting a widget
//    MouseDown,  /// Mouse down on a widget
//    MouseUp,    /// Mouse up on a widget
//    MouseClick, /// Mouse click on a widget
//    MouseDoubleClick, /// Mouse double click on a widget
//    MouseTripleClick, /// Mouse triple click on a widget
//    MouseScroll, // Mouse scroll wheel
//    KeyboardFocus, // When keyboard focus is obtained
//    KeyboardUnfocus, // When keyboard focus is lost
//    Text,       /// Key pressed down
//    KeyDown,    /// Key pressed down
//    KeyUp,      /// Key pressed down
//    Resize,     /// The window has been resized
//    Focus,		/// The window has been focused
//    Layout,     /// Relayout is required
//    StyleSheetChanged, // The stylesheet has been changed
//    AsyncCompletion // An async job has completed
//}

//string ctGenerateEventCallbacks()
//{
//    string str;
//    foreach (t; GUIEvents.EventTypes)
//    {
//        enum typeName = __traits(identifier, t);
//        str ~= "EventUsed on" ~ typeName ~ "(" ~ typeName ~ ") { /*std.stdio.writeln(\"hit2 \", \"" ~ typeName ~ "\", name);*/ return EventUsed.no; }";
//    }
//    return str;
//}

//string ctGenerateEventCallbackSwitch()
//{
//    string str = "if (false) { ";
//    foreach (t; GUIEvents.EventTypes)
//    {
//            enum typeName = __traits(identifier, t);
//            enum n = identifierToEventFieldName(typeName);
//            str ~= "} else if(event.type == GUIEvents." ~ n ~ ") {\n";
//            str ~= "  return on" ~ typeName ~ "(cast(" ~ typeName ~ ")event);";
//    }
//    
//    str ~= "} else { return EventUsed.no; }\n";
//    return str;
//}

@nogc @safe nothrow :

bool isShiftDown(KeyMod m) pure nothrow @safe
{
	return gui.keycode.isPressed(m, KeyMod.shift);
	//return (m & KMOD_SHIFT) != 0;
}

bool isCtrlDown(KeyMod m) pure nothrow @safe
{
	return gui.keycode.isPressed(m, KeyMod.ctrl);
	//return (m & KMOD_CTRL) != 0;
}

bool isAltDown(KeyMod m) pure nothrow @safe @nogc
{
	return gui.keycode.isPressed(m, KeyMod.alt);
	//return (m & KMOD_ALT) != 0;
}

alias WindowID = uint;
alias MouseID = uint;

enum MouseButtonFlag : byte
{
	left = 1,    // Button number 1
	middle = 2,  // Button number 2
	right = 4,   // Button number 3
	x1 = 8,      // Button number 4
	x2 = 16,     // Button number 5
}

bool isPressed(MouseButtonFlag state, MouseButtonFlag isThisDown) pure nothrow @safe 
{
	return (state & isThisDown) != 0;
}

bool isExactlyPressed(MouseButtonFlag state, MouseButtonFlag isThisDown) pure nothrow @safe
{
	return (state & isThisDown) != isThisDown;
}

abstract class GUIEvent : Event
{
	this(WindowID wid) @nogc
	{
		windowID = wid;
	}
	WindowID windowID;
	Widget targetWidget;
}

class StyleSheetChangedEvent : GUIEvent
{
	this(WindowID wid)
	{
		super(wid);
	}
}

// Really should be in AIO system AsyncCompletion event
class CompletedEvent : Event
{
}

abstract class MouseEvent : GUIEvent 
{
	this(WindowID wid, MouseID mid, KeyMod mods) @nogc
	{
		super(wid);
		mouseID = mid;
		modifiers = mods;
	}
	MouseID mouseID;
	KeyMod modifiers;
}

interface IWidgetAware
{
	void setCurrentWidget(Widget w);
}

class MouseMoveEvent : MouseEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, Vec2f rel, MouseButtonFlag btns) @nogc
	{
		super(wid, mid, mods);
		position = pos;
		relative = rel;
		buttons = btns;
	}

	override @property bool allowCombine() pure @safe nothrow const
	{
		return true;
	}

	override bool combineIntoThis(Event ev)
	{
		MouseMoveEvent e = cast(typeof(this))ev;
		if (e !is null && e.type == type && e.windowID == windowID && e.modifiers == modifiers && 
			e.mouseID == mouseID && e.buttons == buttons)
		{
			position = e.position;
			relative += e.relative;
			return true;
		}
		return false;
	}

	Vec2f position;
	Vec2f relative;
	MouseButtonFlag buttons; // Several buttons may be set in this field
	Widget atWidget;
	Widget lastWidget;
}

abstract class MouseButtonEvent : MouseEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, int btnChanged, MouseButtonFlag btns)
	{
		super(wid, mid, mods);
		position = pos;
		buttonChanged = btnChanged;
		buttons = btns;
	}
	Vec2f position;
	int buttonChanged;       // Button number changed (see comment for MouseButtonFlag)
	MouseButtonFlag buttons; // Several buttons may be set in this field
	Widget atWidget;
}

class MouseOverEvent : MouseEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Widget ovrWidget, Widget utWidget)
	{
		super(wid, mid, mods);
		overWidget = ovrWidget;
		outWidget = utWidget;
	}
	Widget overWidget;
	Widget outWidget;
}

class MouseOutEvent : MouseEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Widget ovrWidget, Widget utWidget)
	{
		super(wid, mid, mods);
		overWidget = ovrWidget;
		outWidget = utWidget;
	}
	Widget overWidget;
	Widget outWidget;
}

class MousePressedEvent : MouseButtonEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, int btnChanged, MouseButtonFlag btn)
	{
		super(wid, mid, mods, pos, btnChanged, btn);
	}
}

class MouseReleasedEvent : MouseButtonEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, int btnChanged, MouseButtonFlag btn)
	{
		super(wid, mid, mods, pos, btnChanged, btn);
	}
}

class MouseClickedEvent : MouseButtonEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, int btnChanged, MouseButtonFlag btn, Widget ovrWidget)
	{
		super(wid, mid, mods, pos, btnChanged, btn);
		overWidget = ovrWidget;
	}
	Widget overWidget;
}

class MouseDoubleClickedEvent : MouseButtonEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, int btnChanged, MouseButtonFlag btn, Widget ovrWidget)
	{
		super(wid, mid, mods, pos, btnChanged, btn);
		overWidget = ovrWidget;
	}
	Widget overWidget;
}

class MouseTripleClickedEvent : MouseButtonEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f pos, int btnChanged, MouseButtonFlag btn, Widget ovrWidget)
	{
		super(wid, mid, mods, pos, btnChanged, btn);
		overWidget = ovrWidget;
	}
	Widget overWidget;
}


class MouseWheelEvent : MouseEvent
{
	this(WindowID wid, MouseID mid, KeyMod mods, Vec2f scrl, bool scrollIsFlipped)
	{
		super(wid, mid, mods);
		scroll = scrl;
		isScrollFlipped = scrollIsFlipped;
	}
	Vec2f scroll;
	bool isScrollFlipped;

	override @property bool allowCombine() pure @safe nothrow const
	{
		return true;
	}

	override bool combineIntoThis(Event ev)
	{
		MouseWheelEvent e = cast(typeof(this))ev;
		if (e !is null && e.type == type && e.windowID == windowID && e.modifiers == modifiers && 
			e.mouseID == mouseID && e.isScrollFlipped == isScrollFlipped)
		{
			scroll += e.scroll;
			return true;
		}
		return false;
	}
}

class InputFocusEvent : GUIEvent
{
	this(WindowID wid)
	{
		super(wid);
	}
}

class InputUnfocusEvent : GUIEvent
{
	this(WindowID wid)
	{
		super(wid);
	}
}

// GUIEvent really?
class CommandEvent : GUIEvent
{
	this(string commandName, CommandParameter[] args, WindowID wid)
	{
		super(wid);
		this.commandName = commandName;
		arguments = args;
	}
	
	string commandName;
	CommandParameter[] arguments;
}

abstract class KeyboardEvent : GUIEvent
{
	this(WindowID wid, KeyMod mods)
	{
		super(wid);
		modifiers = mods;
	}

	KeyMod modifiers;
}

abstract class KeyCharEvent : KeyboardEvent
{
	this(WindowID wid, KeyMod mods, KeyCode keycode, dchar c)
	{
		super(wid, mods);
		code = keycode;
		unicodeChar = c;
	}
	KeyCode code;
	dchar unicodeChar;
}

class KeyPressedEvent : KeyCharEvent
{
	this(WindowID wid, KeyMod mods, KeyCode keycode, dchar c)
	{
		super(wid, mods, keycode, c);
	}
}

class KeyReleasedEvent : KeyCharEvent
{
	this(WindowID wid, KeyMod mods, KeyCode keycode, dchar c)
	{
		super(wid, mods, keycode, c);
	}
}

class TextEvent : KeyboardEvent
{
	this(WindowID wid, KeyMod mods, dchar unicodeChr)
	{
		super(wid, mods);
		unicodeChar = unicodeChr;
	}
	dchar unicodeChar;
}

abstract class WindowEvent : GUIEvent
{
	this(uint wid)
	{
		super(wid);
	}
}

class WindowResizedEvent : WindowEvent
{
	this(uint _windowID, Vec2f sz)
	{
		super(_windowID);
		size = sz;
	}
	Vec2f size;
}

class WindowFocussedEvent : WindowEvent
{
	this(uint _windowID)
	{
		super(_windowID);
	}
}

class WindowUnfocussedEvent : WindowEvent
{
	this(uint _windowID)
	{
		super(_windowID);
	}
}

// TODO: move out of here
class DropFile : Event
{
	this (string f, KeyMod mods)
	{
		file = f;
		modifiers = mods;
	}
	string file;
	KeyMod modifiers;
}

//    MouseOver,  /// Mouse entering a widget
//    MouseMove,  /// Mouse moving over the widget
//    MouseOut,   /// Mouse exiting a widget
//    MouseDown,  /// Mouse down on a widget
//    MouseUp,    /// Mouse up on a widget
//    MouseClick, /// Mouse click on a widget
//    MouseDoubleClick, /// Mouse double click on a widget
//    MouseTripleClick, /// Mouse triple click on a widget
//    MouseScroll, // Mouse scroll wheel
//    KeyboardFocus, // When keyboard focus is obtained
//    KeyboardUnfocus, // When keyboard focus is lost
//    Text,       /// Key pressed down
//    KeyDown,    /// Key pressed down
//    KeyUp,      /// Key pressed down
//    Resize,     /// The window has been resized
//    Focus,		/// The window has been focused
//    Layout,     /// Relayout is required
//    StyleSheetChanged, // The stylesheet has been changed
//    AsyncCompletion // An async job has completed


// TODO: add pointer to active widget in here ie. refactor this struct to new file
/*
struct EventX
{
	enum MouseButton : byte
	{
		Left = SDL_BUTTON_LMASK,
		Middle = SDL_BUTTON_MMASK,
		Right = SDL_BUTTON_RMASK,
	}

	EventType type;
	Uint32 windowID;
	Uint32 timestamp;
    bool used = false;

	string toString() const
	{
		import std.conv;
		final switch (type)
		{
			case EventType.Invalid:
				return "Invalid Event";
			case EventType.Default:
				return "Default Event";
			case EventType.Command: // Command possibly with args sent
				//	EventType.Update:
				//	EventType.Draw:
				return text("Event(Command, ", timestamp, ", ", name, ", ", argument, ")");
			case EventType.MouseOver:  /// Mouse entering a widget
				goto case;
			case EventType.MouseMove:  /// Mouse moving over the widget
				goto case;
			case EventType.MouseOut:   /// Mouse exiting a widget
				goto case;
			case EventType.MouseDown:  /// Mouse down on a widget
				goto case;m
			case EventType.MouseUp:    /// Mouse up on a widget
				goto case;
			case EventType.MouseClick: /// Mouse click on a widget
				goto case;
			case EventType.MouseDoubleClick: /// Mouse double click on a widget
				goto case;
			case EventType.MouseTripleClick: /// Mouse triple click on a widget
				return text("Event(", type, ", ", timestamp, ", ", mousePos, ", ", mousePosRel, ", ", mouseButtonsActive, ", ", mouseButtonsChanged, ", ", mouseMod, ")");
			case EventType.MouseScroll: // Mouse scroll wheel
				return text("Event(MouseScroll, ", timestamp, ", ", scroll, ",", msSinceLastScroll, ", ", scrollMod, ")");
			case EventType.KeyboardFocus: // When keyboard focus is obtained
				goto case;
			case EventType.KeyboardUnfocus: // When keyboard focus is lost
				return text("Event(", type, ", ", timestamp, ")");
			case EventType.Text:       /// Key pressed down
				goto case;
			case EventType.KeyDown:    /// Key pressed down
				goto case;
			case EventType.KeyUp:      /// Key pressed down
				return text("Event(", type, ", ", timestamp, ", ", ch, ", ", keyCode, ", ", mod, ")");
			case EventType.Resize:     /// The window has been resized
				return text("Event(Resize, ", timestamp, ", ", width, ", ", height, ")");
			case EventType.Focus:		/// The window has been focused
				return text("Event(Focus, ", timestamp, ", ", windowID, ",", on, ")");
			case EventType.Layout:     /// Relayout is required
				return text("Event(Layout", timestamp, ")");
			case EventType.StyleSheetChanged: // The stylesheet has been changed
				return text("Event(StyleSheetChanged", timestamp, ")");
			case EventType.AsyncCompletion: // An async job has completed
				return text("Event(AsyncCompletion", timestamp, ")");
		}
	}

	ref Event opAssign(Event s)
	{
		 //s.sizeof
		(cast(ubyte*)(&this))[0..s.sizeof][] = (cast(ubyte*)(&s))[0..s.sizeof];       // bitcopy s into this
		return this;
	}

	union
	{
		struct
		{
			uint overWidgetID; // Set by the GUI hit test system
		}
		struct
		{
			Vec2f mousePos;
			Vec2f mousePosRel;
			Uint32 mouseButtonsActive;
			byte mouseButtonsChanged;
			KeyMod mouseMod;
		}
		struct
		{
			dchar ch;
			SDL_Keycode keyCode;
			KeyMod mod;
		}
		struct
		{
			int width;
			int height;
		}
		struct
		{
			Vec2f scroll;
			Uint32 msSinceLastScroll;
			KeyMod scrollMod;
		}
		struct
		{
			string name;
			CommandParameter[] argument;
		}
		struct
		{
			string file;
		}
        struct
        {
            bool on;
        }
	}

	bool opEquals(Event e)
	{
		assert(0);
	}
}

class EventQueueOld
{
	Event event;
	EventQueue next;

	void enqueue(Event e)
	{
		auto qe = this;
		while (qe.next !is null)
			qe = qe.next;
		qe.next = new EventQueue;
		qe.next.event = e;
	}

	Event dequeue()
	{
		if (next is null)
			return Event(EventType.Invalid);
		auto e = next;
		next = e.next;
		return e.event;
	}

	@property bool empty()
	{
		return next is null;
	}
}
*/
