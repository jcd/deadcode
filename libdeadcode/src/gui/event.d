module gui.event;

import core.commandparameter;

import derelict.sdl2.sdl;
import gui.keycode;
import math;

import std.traits;
import std.variant;

enum EventType
{
	Invalid,
	Default,
	Command, // Command possibly with args sent
	//	Update,
	//	Draw,
	MouseOver,  /// Mouse entering a widget
	MouseMove,  /// Mouse moving over the widget
	MouseOut,   /// Mouse exiting a widget
	MouseDown,  /// Mouse down on a widget
	MouseUp,    /// Mouse up on a widget
	MouseClick, /// Mouse click on a widget
	MouseDoubleClick, /// Mouse double click on a widget
	MouseTripleClick, /// Mouse triple click on a widget
	MouseScroll, // Mouse scroll wheel
	KeyboardFocus, // When keyboard focus is obtained
	KeyboardUnfocus, // When keyboard focus is lost
	Text,       /// Key pressed down
	KeyDown,    /// Key pressed down
	KeyUp,      /// Key pressed down
	Resize,     /// The window has been resized
	Focus,		/// The window has been focused
	Layout,     /// Relayout is required
	StyleSheetChanged, // The stylesheet has been changed
}

string ctGenerateEventCallbacks()
{
	string str;
	foreach (member; __traits(allMembers, EventType))
	{
		if (member != "Invalid" && member != "Default")
		{
			str ~= "EventUsed on" ~ member ~ "(Event event) { /*std.stdio.writeln(\"hit2 \", \"" ~ member ~ "\", name);*/ return EventUsed.no; }";
		}
	}
	return str;
}

string ctGenerateEventCallbackSwitch()
{
	string str = "final switch (event.type) { ";
	foreach (member; __traits(allMembers, EventType))
	{
		if (member == "Invalid" || member == "Default")
			str ~= "case EventType." ~ member ~ ": return EventUsed.no;";
		else
			str ~= "case EventType." ~ member ~ ": return on" ~ member ~ "(event);";
	}
	str ~= "}";
	return str;
}

enum EventUsed
{
	no = 0,
	yes = 1
}

bool isShiftDown(KeyMod m) pure nothrow @safe
{
	return (m & KMOD_SHIFT) != 0;
}

bool isCTRLDown(KeyMod m) pure nothrow @safe
{
	return (m & KMOD_CTRL) != 0;
}

bool isALTDown(KeyMod m) pure nothrow @safe
{
	return (m & KMOD_ALT) != 0;
}

// TODO: add pointer to active widget in here ie. refactor this struct to new file
struct Event
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
				goto case;
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
				return text("Event(Focus, ", timestamp, ", ", windowID, ")");
			case EventType.Layout:     /// Relayout is required
				return text("Event(Layout", timestamp, ")");
			case EventType.StyleSheetChanged: // The stylesheet has been changed
				return text("Event(StyleSheetChanged", timestamp, ")");
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
	}

	bool opEquals(Event e)
	{
		assert(0);
	}
}

class EventQueue
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
