module gui.event;

import derelict.sdl2.sdl; 
import gui.keycode;
import math._;

// TODO: add pointer to active widget in here ie. refactor this struct to new file
struct Event
{
	enum Type
	{
		Default,
		Update,
		Draw,
		MouseOver,  /// Mouse entering a widget 
		MouseMove,  /// Mouse moving over the widget
		MouseOut,   /// Mouse exiting a widget
		MouseDown,  /// Mouse down on a widget
		MouseUp,    /// Mouse up on a widget
		MouseClick, /// Mouse click on a widget
		MouseDoubleClick, /// Mouse double click on a widget
		MouseScroll, // Mouse scroll wheel
		KeyboardFocus, // When keyboard focus is obtained
		KeyboardUnfocus, // When keyboard focus is lost
		Text,       /// Key pressed down
		KeyDown,    /// Key pressed down
		KeyUp,      /// Key pressed down
		Resize,     /// The window has been resized
	}
	
	enum MouseButton : byte
	{
		Left = SDL_BUTTON_LMASK,
		Middle = SDL_BUTTON_MMASK,
		Right = SDL_BUTTON_RMASK,
	}
	
	Type type;
	
	union 
	{
		struct 
		{
			Vec2f mousePos;
			Vec2f mousePosRel;
			byte mouseButtonsActive;
			byte mouseButtonsChanged;
		}
		struct 
		{
			dchar ch;
			SDL_Keycode keyCode;
			KeyMod  mod;
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
	}
}
