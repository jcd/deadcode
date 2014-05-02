module gui.event;

import derelict.sdl2.sdl; 
import gui.keycode;
import math._;

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

	union 
	{
		struct 
		{
			Vec2f mousePos;
			Vec2f mousePosRel;
			Uint32 mouseButtonsActive;
			byte mouseButtonsChanged;
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
		}
		struct 
		{
			string name;
			Variant* argument;
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
