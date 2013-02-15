module graphics;

import std.stdio;
import std.range;
import std.string; 
import std.typecons;
import std.exception;
import std.conv;
import derelict.sdl2.sdl; 
import derelict.sdl2.image; 
import derelict.sdl2.ttf;
import derelict.opengl3.gl3; 

import math;

pragma(lib, "DerelictUtil.lib"); 
pragma(lib, "DerelictSDL2.lib"); 
pragma(lib, "DerelictGL3.lib"); 

Texture defaultTexture;
Shader defaultShader;
Material defaultMaterial;

bool init() 
{  
   try{ 
        DerelictSDL2.load(); 
    }catch(Exception e){ 
        writeln("Error loading SDL2 lib"); 
      return false; 
    } 
    try{ 
        DerelictGL3.load(); 
    }catch(Exception e){ 
        writeln("Error loading GL3 lib"); 
      return false; 
    } 
   try{ 
        DerelictSDL2Image.load(); 
    }catch(Exception e){ 
        writeln("Error loading SDL image lib ", e); 
      return false; 
    } 
   try{  
		DerelictSDL2ttf.load(); 
	}catch(Exception e){ 
        writeln("Error loading TTF lib ", e); 
      return false; 
    } 

		   
	if(SDL_Init(SDL_INIT_VIDEO) < 0){ 
      writefln("Error initializing SDL"); 
      return false;  
   	} 

	if (TTF_WasInit())
	{
		writeln("TTF was initialized");
	}
	else if (TTF_Init() == -1)
	{
		writeln("Error initializing TTF ", TTF_GetError());
		return false;
	}
	
   	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3); 
   	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2); 
   	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1); 
   	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24); 
		
    return true; 
}

void destroy()
{
   SDL_Quit(); 
}

// Directly mapped from SDL keymod
enum KeyMod
{
    NONE = 0x0000,
    LSHIFT = 0x0001,
    RSHIFT = 0x0002,
    LCTRL = 0x0040,
    RCTRL = 0x0080,
    LALT = 0x0100,
    RALT = 0x0200,
    LGUI = 0x0400,
    RGUI = 0x0800,
    NUM = 0x1000,
    CAPS = 0x2000,
    MODE = 0x4000,
    RESERVED = 0x8000,

    CTRL = (KMOD_LCTRL|KMOD_RCTRL),
    SHIFT = (KMOD_LSHIFT|KMOD_RSHIFT),
    ALT = (KMOD_LALT|KMOD_RALT),
    GUI = (KMOD_LGUI|KMOD_RGUI)
}

enum KKTMP
{
    SDLK_UNKNOWN = 0,

    SDLK_RETURN = '\r',
    SDLK_ESCAPE = '\033',
    SDLK_BACKSPACE = '\b',
    SDLK_TAB = '\t',
    SDLK_SPACE = ' ',
    SDLK_EXCLAIM = '!',
    SDLK_QUOTEDBL = '"',
    SDLK_HASH = '#',
    SDLK_PERCENT = '%',
    SDLK_DOLLAR = '$',
    SDLK_AMPERSAND = '&',
    SDLK_QUOTE = '\'',
    SDLK_LEFTPAREN = '(',
    SDLK_RIGHTPAREN = ')',
    SDLK_ASTERISK = '*',
    SDLK_PLUS = '+',
    SDLK_COMMA = ',',
    SDLK_MINUS = '-',
    SDLK_PERIOD = '.',
    SDLK_SLASH = '/',
    SDLK_0 = '0',
    SDLK_1 = '1',
    SDLK_2 = '2',
    SDLK_3 = '3',
    SDLK_4 = '4',
    SDLK_5 = '5',
    SDLK_6 = '6',
    SDLK_7 = '7',
    SDLK_8 = '8',
    SDLK_9 = '9',
    SDLK_COLON = ':',
    SDLK_SEMICOLON = ';',
    SDLK_LESS = '<',
    SDLK_EQUALS = '=',
    SDLK_GREATER = '>',
    SDLK_QUESTION = '?',
    SDLK_AT = '@',

    SDLK_LEFTBRACKET = '[',
    SDLK_BACKSLASH = '\\',
    SDLK_RIGHTBRACKET = ']',
    SDLK_CARET = '^',
    SDLK_UNDERSCORE = '_',
    SDLK_BACKQUOTE = '`',
    SDLK_a = 'a',
    SDLK_b = 'b',
    SDLK_c = 'c',
    SDLK_d = 'd',
    SDLK_e = 'e',
    SDLK_f = 'f',
    SDLK_g = 'g',
    SDLK_h = 'h',
    SDLK_i = 'i',
    SDLK_j = 'j',
    SDLK_k = 'k',
    SDLK_l = 'l',
    SDLK_m = 'm',
    SDLK_n = 'n',
    SDLK_o = 'o',
    SDLK_p = 'p',
    SDLK_q = 'q',
    SDLK_r = 'r',
    SDLK_s = 's',
    SDLK_t = 't',
    SDLK_u = 'u',
    SDLK_v = 'v',
    SDLK_w = 'w',
    SDLK_x = 'x',
    SDLK_y = 'y',
    SDLK_z = 'z',

    SDLK_CAPSLOCK = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CAPSLOCK),

    SDLK_F1 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F1),
    SDLK_F2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F2),
    SDLK_F3 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F3),
    SDLK_F4 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F4),
    SDLK_F5 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F5),
    SDLK_F6 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F6),
    SDLK_F7 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F7),
    SDLK_F8 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F8),
    SDLK_F9 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F9),
    SDLK_F10 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F10),
    SDLK_F11 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F11),
    SDLK_F12 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F12),

    SDLK_PRINTSCREEN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PRINTSCREEN),
    SDLK_SCROLLLOCK = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SCROLLLOCK),
    SDLK_PAUSE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PAUSE),
    SDLK_INSERT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_INSERT),
    SDLK_HOME = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_HOME),
    SDLK_PAGEUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PAGEUP),
    SDLK_DELETE = '\177',
    SDLK_END = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_END),
    SDLK_PAGEDOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PAGEDOWN),
    SDLK_RIGHT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RIGHT),
    SDLK_LEFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LEFT),
    SDLK_DOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DOWN),
    SDLK_UP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_UP),

    SDLK_NUMLOCKCLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_NUMLOCKCLEAR),
    SDLK_KP_DIVIDE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DIVIDE),
    SDLK_KP_MULTIPLY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MULTIPLY),
    SDLK_KP_MINUS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MINUS),
    SDLK_KP_PLUS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PLUS),
    SDLK_KP_ENTER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_ENTER),
    SDLK_KP_1 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_1),
    SDLK_KP_2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_2),
    SDLK_KP_3 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_3),
    SDLK_KP_4 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_4),
    SDLK_KP_5 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_5),
    SDLK_KP_6 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_6),
    SDLK_KP_7 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_7),
    SDLK_KP_8 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_8),
    SDLK_KP_9 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_9),
    SDLK_KP_0 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_0),
    SDLK_KP_PERIOD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PERIOD),

    SDLK_APPLICATION = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_APPLICATION),
    SDLK_POWER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_POWER),
    SDLK_KP_EQUALS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_EQUALS),
    SDLK_F13 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F13),
    SDLK_F14 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F14),
    SDLK_F15 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F15),
    SDLK_F16 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F16),
    SDLK_F17 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F17),
    SDLK_F18 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F18),
    SDLK_F19 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F19),
    SDLK_F20 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F20),
    SDLK_F21 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F21),
    SDLK_F22 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F22),
    SDLK_F23 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F23),
    SDLK_F24 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F24),
    SDLK_EXECUTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_EXECUTE),
    SDLK_HELP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_HELP),
    SDLK_MENU = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MENU),
    SDLK_SELECT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SELECT),
    SDLK_STOP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_STOP),
    SDLK_AGAIN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AGAIN),
    SDLK_UNDO = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_UNDO),
    SDLK_CUT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CUT),
    SDLK_COPY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_COPY),
    SDLK_PASTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PASTE),
    SDLK_FIND = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_FIND),
    SDLK_MUTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MUTE),
    SDLK_VOLUMEUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_VOLUMEUP),
    SDLK_VOLUMEDOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_VOLUMEDOWN),
    SDLK_KP_COMMA = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_COMMA),
    SDLK_KP_EQUALSAS400 =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_EQUALSAS400),

    SDLK_ALTERASE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_ALTERASE),
    SDLK_SYSREQ = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SYSREQ),
    SDLK_CANCEL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CANCEL),
    SDLK_CLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CLEAR),
    SDLK_PRIOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PRIOR),
    SDLK_RETURN2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RETURN2),
    SDLK_SEPARATOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SEPARATOR),
    SDLK_OUT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_OUT),
    SDLK_OPER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_OPER),
    SDLK_CLEARAGAIN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CLEARAGAIN),
    SDLK_CRSEL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CRSEL),
    SDLK_EXSEL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_EXSEL),

    SDLK_KP_00 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_00),
    SDLK_KP_000 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_000),
    SDLK_THOUSANDSSEPARATOR =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_THOUSANDSSEPARATOR),
    SDLK_DECIMALSEPARATOR =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DECIMALSEPARATOR),
    SDLK_CURRENCYUNIT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CURRENCYUNIT),
    SDLK_CURRENCYSUBUNIT =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CURRENCYSUBUNIT),
    SDLK_KP_LEFTPAREN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_LEFTPAREN),
    SDLK_KP_RIGHTPAREN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_RIGHTPAREN),
    SDLK_KP_LEFTBRACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_LEFTBRACE),
    SDLK_KP_RIGHTBRACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_RIGHTBRACE),
    SDLK_KP_TAB = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_TAB),
    SDLK_KP_BACKSPACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_BACKSPACE),
    SDLK_KP_A = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_A),
    SDLK_KP_B = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_B),
    SDLK_KP_C = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_C),
    SDLK_KP_D = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_D),
    SDLK_KP_E = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_E),
    SDLK_KP_F = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_F),
    SDLK_KP_XOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_XOR),
    SDLK_KP_POWER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_POWER),
    SDLK_KP_PERCENT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PERCENT),
    SDLK_KP_LESS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_LESS),
    SDLK_KP_GREATER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_GREATER),
    SDLK_KP_AMPERSAND = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_AMPERSAND),
    SDLK_KP_DBLAMPERSAND =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DBLAMPERSAND),
    SDLK_KP_VERTICALBAR =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_VERTICALBAR),
    SDLK_KP_DBLVERTICALBAR =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DBLVERTICALBAR),
    SDLK_KP_COLON = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_COLON),
    SDLK_KP_HASH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_HASH),
    SDLK_KP_SPACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_SPACE),
    SDLK_KP_AT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_AT),
    SDLK_KP_EXCLAM = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_EXCLAM),
    SDLK_KP_MEMSTORE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMSTORE),
    SDLK_KP_MEMRECALL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMRECALL),
    SDLK_KP_MEMCLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMCLEAR),
    SDLK_KP_MEMADD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMADD),
    SDLK_KP_MEMSUBTRACT =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMSUBTRACT),
    SDLK_KP_MEMMULTIPLY =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMMULTIPLY),
    SDLK_KP_MEMDIVIDE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMDIVIDE),
    SDLK_KP_PLUSMINUS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PLUSMINUS),
    SDLK_KP_CLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_CLEAR),
    SDLK_KP_CLEARENTRY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_CLEARENTRY),
    SDLK_KP_BINARY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_BINARY),
    SDLK_KP_OCTAL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_OCTAL),
    SDLK_KP_DECIMAL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DECIMAL),
    SDLK_KP_HEXADECIMAL =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_HEXADECIMAL),

    SDLK_LCTRL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LCTRL),
    SDLK_LSHIFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LSHIFT),
    SDLK_LALT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LALT),
    SDLK_LGUI = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LGUI),
    SDLK_RCTRL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RCTRL),
    SDLK_RSHIFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RSHIFT),
    SDLK_RALT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RALT),
    SDLK_RGUI = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RGUI),

    SDLK_MODE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MODE),

    SDLK_AUDIONEXT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIONEXT),
    SDLK_AUDIOPREV = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOPREV),
    SDLK_AUDIOSTOP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOSTOP),
    SDLK_AUDIOPLAY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOPLAY),
    SDLK_AUDIOMUTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOMUTE),
    SDLK_MEDIASELECT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MEDIASELECT),
    SDLK_WWW = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_WWW),
    SDLK_MAIL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MAIL),
    SDLK_CALCULATOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CALCULATOR),
    SDLK_COMPUTER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_COMPUTER),
    SDLK_AC_SEARCH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_SEARCH),
    SDLK_AC_HOME = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_HOME),
    SDLK_AC_BACK = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_BACK),
    SDLK_AC_FORWARD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_FORWARD),
    SDLK_AC_STOP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_STOP),
    SDLK_AC_REFRESH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_REFRESH),
    SDLK_AC_BOOKMARKS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_BOOKMARKS),

    SDLK_BRIGHTNESSDOWN =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_BRIGHTNESSDOWN),
    SDLK_BRIGHTNESSUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_BRIGHTNESSUP),
    SDLK_DISPLAYSWITCH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DISPLAYSWITCH),
    SDLK_KBDILLUMTOGGLE =
        SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KBDILLUMTOGGLE),
    SDLK_KBDILLUMDOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KBDILLUMDOWN),
    SDLK_KBDILLUMUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KBDILLUMUP),
    SDLK_EJECT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_EJECT),
    SDLK_SLEEP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SLEEP)
}

string keycodes()
{
	import std.traits;
	string res = "SDL_Keycode[] allKeyCodes = [";
	foreach (m; EnumMembers!KKTMP)
	{
		res ~= m.stringof;
		res ~= ",";
	}
	res ~= "];";
	return res;
}

mixin(keycodes());

private SDL_Keycode[string] stringToKeyCodeMap;
private string[SDL_Keycode] keyCodeToStringMap;

private void primeKeyCodeMaps()
{
	import std.c.string;
	foreach (k; allKeyCodes)
	{
		auto _name = SDL_GetKeyName(k);
		auto name = _name[0..strlen(_name)].toLower().idup;
		if (name !in stringToKeyCodeMap)
		{
			stringToKeyCodeMap[name] = k;
		}
		keyCodeToStringMap[k] = name;
	}
}

SDL_Keycode stringToKeyCode(string name)
{
	if (stringToKeyCodeMap.length == 0)
		primeKeyCodeMaps();
	return stringToKeyCodeMap[name];
}

string keyCodeToString(SDL_Keycode c)
{
	if (keyCodeToStringMap.length == 0)
		primeKeyCodeMaps();
	return keyCodeToStringMap[c];
}

// TODO: add pointer to active widget in here ie. refactor this struct to new file
struct Event
{
	enum Type
	{
		Default,
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

struct Window
{
	alias void delegate(Event) OnEvent;
	alias void delegate() OnUpdate;
	private struct Impl 
	{
		int width;
		int height;
		bool waitForEvents;
		OnEvent onEvent;
		OnUpdate onUpdate;
		SDL_Window *win; 
		SDL_GLContext context; 
		~this()
		{
   			if (context)
				SDL_GL_DeleteContext(context); 
			if (win)
			   	SDL_DestroyWindow(win); 
		}
	}
	RefCounted!(Impl,RefCountedAutoInitialize.no) p;
	
	static Window active;
	
	Mat4f MVP;
	
	@property void waitForEvents(bool v)
	{
		p.waitForEvents = v;
	}
	
	@property void onEvent(OnEvent callback)
	{
		p.onEvent = callback;
	}

	@property void onUpdate(OnUpdate callback)
	{
		p.onUpdate = callback;
	}
	
	this(const(char)[] name, int width, int height)
	{
		p = RefCounted!(Impl,RefCountedAutoInitialize.no)(width, height);
		
		int flags = SDL_WINDOW_OPENGL | SDL_WINDOW_BORDERLESS | SDL_WINDOW_SHOWN;// |
			/*SDL_WINDOW_MAXIMIZED | SDL_WINDOW_RESIZABLE; */
	   	p.win = SDL_CreateWindow(name.ptr, 0, 0, width, height, flags); 
//	   	p.win = SDL_CreateWindow(name.ptr, SDL_WINDOWPOS_CENTERED, 
	   							//SDL_WINDOWPOS_CENTERED, width, height, flags); 
	   	
		if(!p.win)
		{ 
          	writefln("Error creating SDL window"); 
      		SDL_Quit();
     	} 

    	p.context = SDL_GL_CreateContext(p.win); 
    	SDL_GL_SetSwapInterval(1); 
   		glClearColor(0.0, 0.0, 0.0, 1.0); 
   		glViewport(0, 0, width, height); 

		auto aspect = cast(double)width / cast(double)height;
/*
		glMatrixMode( GL_PROJECTION );
		glLoadIdentity(); 
		glFrustum(-near_height * aspect, 
		   near_height * aspect, 
		   -near_height,
		   near_height, zNear, zFar );	
*/	
		   	
    	DerelictGL3.reload(); 
		
		Mat4f proj = Mat4f.orthographic(-1,1,-1,1,1,-1);
		Mat4f view = Mat4f.makeTranslate(Vec3f(0.0,0.0,1.0f));
		MVP = proj * view;
		
		// If there is no active window yet then activate this
		if (!Window.active.p.RefCounted.isInitialized)
			active = this;
		
		SDL_StartTextInput();		
		icon();
	}
	
	void icon()
	{
  		// TODO: read from file
		SDL_Surface *surface;     // Declare an SDL_Surface to be filled in with pixel data from an image file
		ushort pixels[16*16] = [  // ...or with raw pixel data.
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0aab, 0x0789, 0x0bcc, 0x0eee, 0x09aa, 0x099a, 0x0ddd, 
		    0x0fff, 0x0eee, 0x0899, 0x0fff, 0x0fff, 0x1fff, 0x0dde, 0x0dee, 
		    0x0fff, 0xabbc, 0xf779, 0x8cdd, 0x3fff, 0x9bbc, 0xaaab, 0x6fff, 
		    0x0fff, 0x3fff, 0xbaab, 0x0fff, 0x0fff, 0x6689, 0x6fff, 0x0dee, 
		    0xe678, 0xf134, 0x8abb, 0xf235, 0xf678, 0xf013, 0xf568, 0xf001, 
		    0xd889, 0x7abc, 0xf001, 0x0fff, 0x0fff, 0x0bcc, 0x9124, 0x5fff, 
		    0xf124, 0xf356, 0x3eee, 0x0fff, 0x7bbc, 0xf124, 0x0789, 0x2fff, 
		    0xf002, 0xd789, 0xf024, 0x0fff, 0x0fff, 0x0002, 0x0134, 0xd79a, 
		    0x1fff, 0xf023, 0xf000, 0xf124, 0xc99a, 0xf024, 0x0567, 0x0fff, 
		    0xf002, 0xe678, 0xf013, 0x0fff, 0x0ddd, 0x0fff, 0x0fff, 0xb689, 
		    0x8abb, 0x0fff, 0x0fff, 0xf001, 0xf235, 0xf013, 0x0fff, 0xd789, 
		    0xf002, 0x9899, 0xf001, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0xe789, 
		    0xf023, 0xf000, 0xf001, 0xe456, 0x8bcc, 0xf013, 0xf002, 0xf012, 
		    0x1767, 0x5aaa, 0xf013, 0xf001, 0xf000, 0x0fff, 0x7fff, 0xf124, 
		    0x0fff, 0x089a, 0x0578, 0x0fff, 0x089a, 0x0013, 0x0245, 0x0eff, 
		    0x0223, 0x0dde, 0x0135, 0x0789, 0x0ddd, 0xbbbc, 0xf346, 0x0467, 
		    0x0fff, 0x4eee, 0x3ddd, 0x0edd, 0x0dee, 0x0fff, 0x0fff, 0x0dee, 
		    0x0def, 0x08ab, 0x0fff, 0x7fff, 0xfabc, 0xf356, 0x0457, 0x0467, 
		    0x0fff, 0x0bcd, 0x4bde, 0x9bcc, 0x8dee, 0x8eff, 0x8fff, 0x9fff, 
		    0xadee, 0xeccd, 0xf689, 0xc357, 0x2356, 0x0356, 0x0467, 0x0467, 
		    0x0fff, 0x0ccd, 0x0bdd, 0x0cdd, 0x0aaa, 0x2234, 0x4135, 0x4346, 
		    0x5356, 0x2246, 0x0346, 0x0356, 0x0467, 0x0356, 0x0467, 0x0467, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 
		    0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff 
		]; 
		  surface = SDL_CreateRGBSurfaceFrom(pixels.ptr,16,16,16,16*2,0x0f00,0x00f0,0x000f,0xf000);
		  
		  
		  
		  SDL_SetWindowIcon(p.win, surface); 
		  // The icon is attached to the window pointer
		
		  
		  // ...and the surface containing the icon pixel data is no longer required.
		  SDL_FreeSurface(surface);	
	}
	
	bool update()
	{
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); 
      	bool running = true;
		SDL_Event e; 
		if (p.waitForEvents)
			SDL_WaitEvent(&e);
		else
			SDL_PollEvent(&e);
		do { 
			Event ev;
      	   	switch(e.type) { 
			case SDL_MOUSEMOTION:
				ev.type = Event.Type.MouseMove;
				ev.mousePos.x = e.motion.x;
				ev.mousePos.y = e.motion.y;
				ev.mousePosRel.x = e.motion.xrel;
				ev.mousePosRel.y = e.motion.yrel;
				ev.mouseButtonsActive = e.motion.state;
				break;				
			case SDL_MOUSEBUTTONDOWN:
				ev.type = Event.Type.MouseDown;
				ev.mousePos.x = e.motion.x;
				ev.mousePos.y = e.motion.y;
				ev.mouseButtonsActive = e.button.state;
				ev.mouseButtonsChanged = e.button.button;
				break;
			case SDL_MOUSEBUTTONUP:
				ev.type = Event.Type.MouseUp;
				ev.mousePos.x = e.motion.x;
				ev.mousePos.y = e.motion.y;
				ev.mouseButtonsActive = e.button.state;
				ev.mouseButtonsChanged = e.button.button;
				break;
			case SDL_MOUSEWHEEL:
				ev.type = Event.Type.MouseScroll;
				ev.scroll = Vec2f(e.wheel.x, e.wheel.y);
				break;
			case SDL_KEYDOWN:
				if (e.key.keysym.sym == SDLK_ESCAPE)
						running = false;
				ev.type = Event.Type.KeyDown;
				ev.keyCode = e.key.keysym.sym;
				ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
				ev.mod = cast(KeyMod)SDL_GetModState();
				//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
				break;
			case SDL_KEYUP:
				if (e.key.keysym.sym == SDLK_ESCAPE)
						running = false;
				ev.type = Event.Type.KeyUp;
				ev.keyCode = e.key.keysym.sym;
				ev.ch = SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
				ev.mod = cast(KeyMod)SDL_GetModState();
				//std.stdio.writeln("got text " , SDL_GetKeyName(e.key.keysym.sym)[0..std.c.string.strlen(SDL_GetKeyName(e.key.keysym.sym))], " ", e.key.repeat, " ",e.key.state);
				break;
			case SDL_TEXTINPUT:
				//std.stdio.writeln(e.text.text);
				char[] ch = cast(char[])e.text.text;
				//size_t st = std.utf.stride(ch, 0);
				ev.type = Event.Type.Text;
				ev.ch = ch.front;
				ev.mod = cast(KeyMod)SDL_GetModState();
				break;
			case SDL_WINDOWEVENT:
				switch (e.window.event)
				{
				case SDL_WINDOWEVENT_SIZE_CHANGED:
				case SDL_WINDOWEVENT_RESIZED:
					size = Vec2f(e.window.data1, e.window.data2);
					break;
				default:
					break;
				}
				break;
			default:  
            	break; 
	       	}
			
			if (p.onEvent)
				p.onEvent(ev);
			
      	} while (SDL_PollEvent(&e));
		
		if (p.onUpdate)
			p.onUpdate();
		
      	SDL_GL_SwapWindow(p.win); 
		return running;
	}

    void run()
	{
		Event ev;
		ev.type = Event.Type.Resize;
		ev.width = width;
		ev.height = height;
		p.onEvent(ev);
		
		while(update()) { };
	}

	@property 
	{
		Vec2f position() const
		{
			int x, y;
			SDL_GetWindowPosition(cast(SDL_Window*)p.win, &x, &y);
			return Vec2f(x, y);
		}
		
		void position(Vec2f pos)
		{
			int x = cast(int)pos.x;
			int y = cast(int)pos.y;
			SDL_SetWindowPosition(p.win, x, y);
		}
	}	
	
	@property 
	{
		Vec2f size() const
		{
			int x, y;
			SDL_GetWindowSize(cast(SDL_Window*)p.win, &x, &y);
			return Vec2f(x, y);
		}
		
		void size(Vec2f s)
		{			
			int x = cast(int)s.x;
			int y = cast(int)s.y;
			if (p.width != x || p.height != y)
			{				
				p.width = x;
				p.height = y;
				glViewport(0, 0, x, y);

				Event ev;
				ev.type = Event.Type.Resize;
				ev.width = x;
				ev.height = y;
				p.onEvent(ev);	

				SDL_SetWindowSize(p.win, x, y);
			}
		}
	}
	
	@property int width() const 
	{
		return p.width;
	}
	
	@property int height() const 
	{
		return p.height;
	}

	@property 
	{
		bool maximized() const
		{
			auto v = SDL_GetWindowFlags(cast(SDL_Window*)p.win);
			return (v & SDL_WINDOW_MAXIMIZED) != 0;
		}
		
		void maximized(bool v)
		{
			if (v)
			{
				SDL_MaximizeWindow(p.win);
			}
			//SDL_MinimizeWindow(p.win);
		}
	}
	
	/** Convert a size in pixels to a size in world coordinate at z = 0
	 */
	import smallvector;
	Vec2f pixelSizeToWorld(SmallVector!(2u,float) pixels)
	{
		pixels.x /= width * 0.5f;
		pixels.y /= height * 0.5f;
		return pixels;
	}
	
	/// ditto
	float pixelWidthToWorld(float x)
	{
		x /= width * 0.5f; 
		return x;
	}

	/// ditto
	float pixelHeightToWorld(float y)
	{
		y /= height * 0.5f;
		return y;
	}

	/** Window pixel coordinate to world coordinate at z = 0
	 */
	Vec3f windowToWorld(float x, float y)
	{
		// world goes from (-1,-1) to (1,1)
		return Vec3f(2f * x / width - 1f, -2f * y / height + 1f, 0f);
	}
	
	/// ditto
	Vec3f windowToWorld(Vec2f src)
	{
		return windowToWorld(src.x, src.y);
	}
	
	/** Window pixel coordinate to world coordinate at z = 0
	 */
	Rectf windowToWorld(float x1, float y1, float x2, float y2)
	{
		// world goes from (-1,-1) to (1,1)
		Vec3f pTopLeft = windowToWorld(x1, y1);
		Vec3f pLowRight = windowToWorld(x2, y2); 
		return Rectf(pTopLeft.x, pTopLeft.y, pLowRight.x, pLowRight.y);
	}

	Rectf windowToWorld(Rectf r)
	{
		return windowToWorld(r.x, r.y, r.x2, r.y2);
	}

	/** World coordinate (ignoring z) to window pixel coordinate
	 */ 
	Vec2f worldToWindow(Vec3f src)
	{
		// world goes from (-1,-1) to (1,1)
		return Vec2f(( 0.5f * src.x + 0.5f) * width, ( 0.5f * src.y - 0.5f) * height);
	}
}

final class Shader 
{
	enum builtInVertexShaderSource = " 
   	#version 330 
   	layout(location = 0) in vec3 pos; 
   	layout(location = 1) in vec2 texCoords; 
   	layout(location = 2) in vec3 col; 

   	out vec2 coords; 
	out vec3 cols;
	uniform mat4 MVP;
	
   	void main(void) 
   	{ 

       gl_Position = MVP * vec4(pos, 1.0); 
 //      gl_Position = vec4(pos, 1.0); 
      coords = texCoords.st; 
	  cols = col;
   	} 
   	"; 
	
	enum builtInFragmentShaderSource = " 
   	#version 330 
	
   	uniform sampler2D colMap; 
	
	in vec2 coords; 
	in vec3 cols; 
	out vec3 color;

   	void main(void) 
   	{ 
      vec3 col = texture2D(colMap, coords.st).xyz; 

//      color = vec3(coords.yyx + col); 
      color = vec3(col) * cols; 
      // color = vec3(1.0, 0.0,0.0);
	} 
   	"; 

	private static Shader builtInVertexShader_;
	private static Shader builtInFragmentShader_;
	
	static @property Shader builtInVertexShader()
	{
		if (builtInVertexShader_ is null)
			builtInVertexShader_ = new Shader(builtInVertexShaderSource, Shader.Type.Vertex);
		return builtInVertexShader_;
	}

	static @property Shader builtInFragmentShader()
	{
		if (builtInFragmentShader_ is null)
			builtInFragmentShader_ = new Shader(builtInFragmentShaderSource, Shader.Type.Fragment);
		return builtInFragmentShader_;
	}
	
	enum Type
	{
		Vertex,
		Fragment
	}
	
	private uint glShaderID = 0;

	this(const(char)[] source, Shader.Type type)
	{
		compileString(source, type);
	}

	bool compileString(const(char)[] source, Shader.Type type)
	{
		int shaderType = 0;
		final switch (type)
		{
		case Type.Vertex:
			shaderType = GL_VERTEX_SHADER;
			break;
		case Type.Fragment:
			shaderType = GL_FRAGMENT_SHADER;
			break;
		}
		int fshad = glCreateShader(shaderType); 
   		const char * fptr = toStringz(source); 
   		glShaderSource(fshad, 1, &fptr, null); 
   		glCompileShader(fshad);
   		
		int len, status;
		glGetShaderiv(fshad, GL_COMPILE_STATUS, &status); 
   		
		if(status == GL_FALSE)
		{ 
      		glGetShaderiv(fshad, GL_INFO_LOG_LENGTH, &len); 
      		char[] error=new char[len]; 
      		glGetShaderInfoLog(fshad, len, null, cast(char*)error); 

      		writeln(error); 
      		return false; 
   		}
		glShaderID = fshad;
		return true; 
	}
}

const string fshader2 = "
   #version 330 

in vec2 coords; 
out vec3 color;
		 
void main(void){
    color = vec3(1.0 * coords.x, 0 , 0);
}
				";

final class ShaderProgram
{
	private static ShaderProgram builtIn_;
	static @property ShaderProgram builtIn()
	{
		if (builtIn_ is null)
		{
			builtIn_ = create();
			builtIn_.attach(Shader.builtInVertexShader);
			builtIn_.attach(Shader.builtInFragmentShader);
			builtIn_.link();
			builtIn.setUniform("colMap", 0);
		}
		return builtIn_;
	}
	
	uint glProgramID = 0;
	
	static ShaderProgram create(const(char)[] vertexSource = null, const(char)[] fragmentSource = null)
	{
		ShaderProgram pr = new ShaderProgram();
		uint p = glCreateProgram(); 
   		if(p == 0){ 
      		writeln("Error: GL did not assign main shader program id"); 
      		return pr; 
   		} 
		
		pr.glProgramID = p;

		if (!vertexSource.empty)
		{
			pr.attach(new Shader(vertexSource, Shader.Type.Vertex));
		}

		if (!fragmentSource.empty)
		{
			pr.attach(new Shader(fragmentSource, Shader.Type.Fragment));
		}
		
		return pr;
	}
		
	void attach(Shader shader)
	{
	   	assert(glProgramID > 0);
	   	assert(shader.glShaderID > 0);
		glAttachShader(glProgramID, shader.glShaderID); 
	}
	
	bool link()
	{
	   	assert(glProgramID > 0);
		glLinkProgram(glProgramID); 
	   	int status, len;
		glGetShaderiv(glProgramID, GL_LINK_STATUS, &status); 
	   	
		if(status == GL_FALSE)
		{ 
	      	glGetShaderiv(glProgramID, GL_INFO_LOG_LENGTH, &len); 
	      	char[] error=new char[len]; 
	      	glGetShaderInfoLog(glProgramID, len, null, cast(char*)error); 
		  	writeln(error); 
      		return false; 
   		}
		return true;
	} 

	private int getUniformLocation(const(char)[] name)
	{
		auto n = toStringz(name);
		int colLoc = glGetUniformLocation(glProgramID, n); 
	   	enforceEx!Exception(colLoc != -1, text("Error: main shader did not assign id to uniform ", name , " prg ", glProgramID)); 
		return colLoc;
	}
	
	void setUniform(const(char)[] name, int location)
	{ 
      	glUseProgram(glProgramID);
		scope (exit) glUseProgram(0);
		glUniform1i(getUniformLocation(name), location); 
	} 
	
	void setUniform(const(char)[] name, in Mat4f m)
	{ 
      	glUseProgram(glProgramID);
		scope (exit) glUseProgram(0);
		glUniformMatrix4fv(getUniformLocation(name), 1, GL_TRUE, m.v.ptr); 
	} 

	void bind()
	{
      	glUseProgram(glProgramID);
	}
}

final class Texture 
{
	private static Texture builtIn_;
	 
	static @property Texture builtIn()
	{
		if (builtIn_ is null)
			builtIn_ = create("bg2.png");
		return builtIn_;
	}
	
	uint glTextureID = 0;
	float width; // Todo: readonly?
	float height;
	
	enum Wrap
	{
		Repeat,
		RepeatMirrored,
		Clamp
	}
	@property void wrap(Wrap r)
	{
		glBindTexture(GL_TEXTURE_2D, glTextureID); 
		int wrap;
		final switch (r)
		{
		case Wrap.Repeat:
			wrap = GL_REPEAT;
			break;
		case Wrap.RepeatMirrored:
			wrap = GL_MIRRORED_REPEAT;
			break;
		case Wrap.Clamp:
			wrap = GL_CLAMP_TO_BORDER;
			break;
		}
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap); 
		glBindTexture(GL_TEXTURE_2D, 0); 
	}
	
	void release()
	{
		glDeleteTextures(1, &glTextureID);
	}
	
	@property bool valid() const
	{
		return glTextureID != 0;
	}
	
	private static Texture[string] managedTextures;
	
	static Texture create(float width, float height)
	{
		return create(cast(size_t)width, cast(size_t)height);
	}
	
	static Texture create(size_t width, size_t height)
	{
		SDL_Surface * s = SDL_CreateRGBSurface(0, width, height, 32,0,0,0,0);
		assert(s); 
		auto texture = createFromSDLSurface(s);
		SDL_FreeSurface(s);
		return texture;
	}
	
	static Texture create(const(char)[] path)
	{
		Texture * t = path in managedTextures;
		if (t) return *t;
		
		import std.file; 
		assert(exists(path)); 
		SDL_Surface * s = IMG_Load(path.ptr); 
		assert(s); 
		auto texture = createFromSDLSurface(s);
		SDL_FreeSurface(s);
		return texture;
	}
	
	private static Texture createFromSDLSurface(SDL_Surface * s)
	{
		Texture texture = new Texture();
		glPixelStorei(GL_UNPACK_ALIGNMENT, 4); 
		glGenTextures(1, &(texture.glTextureID)); 
		assert(texture.glTextureID > 0); 
		glBindTexture(GL_TEXTURE_2D, texture.glTextureID); 

		int mode = GL_RGB; 
		if(s.format.BytesPerPixel == 4) mode=GL_RGBA; 
    
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);    
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT); 

		SDL_Surface * px =  flip(s);
		glTexImage2D(GL_TEXTURE_2D, 0, mode, s.w, s.h, 0, mode, GL_UNSIGNED_BYTE, px.pixels); 
		SDL_FreeSurface(px);
		texture.width = s.w;
		texture.height = s.h;
		return texture;
	}
	
	void blitSDLSurface(Rectf rect, SDL_Surface * s, bool flipY = true)
	{
		glPixelStorei(GL_UNPACK_ALIGNMENT, 4); 
		glBindTexture(GL_TEXTURE_2D, glTextureID); 
		
		int mode = GL_RGB; 
		if(s.format.BytesPerPixel == 4) mode=GL_RGBA; 
    
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);    
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT); 

//		glTexSubImage2D(GL_TEXTURE_2D, 0, cast(int)rect.x, cast(int)rect.y, cast(int)rect.w, cast(int)rect.h, mode, GL_UNSIGNED_BYTE, flip(s).pixels); 	
		rect = Rectf(0, 0, width, height).clip(rect);
		SDL_Surface * px =  flip(s);
		if (flipY)
			glTexSubImage2D(GL_TEXTURE_2D, 0, cast(int)(rect.x), cast(int)(height - rect.y2), cast(int)rect.w, cast(int)rect.h, mode, GL_UNSIGNED_BYTE, px.pixels); 	
		else
			glTexSubImage2D(GL_TEXTURE_2D, 0, cast(int)(rect.x), cast(int)(rect.y), cast(int)rect.w, cast(int)rect.h, mode, GL_UNSIGNED_BYTE, px.pixels); 	
		SDL_FreeSurface(px);
	}
	
	private static SDL_Surface * clearSurface = null;
	void clear()
	{
		if (clearSurface !is null && (clearSurface.w < width || clearSurface.h < height))
		{
			SDL_FreeSurface(clearSurface);
			clearSurface = null;
		}
			
		if (clearSurface is null)
		{
			clearSurface = SDL_CreateRGBSurface(0, cast(int)width, cast(int)height, 32,0,0,0,0);
			writeln("new clear");
		}
		assert(clearSurface); 
		blitSDLSurface(Rectf(0, 750, width, height), clearSurface);
	}
	
//thanks to tito http://stackoverflow.com/questions/5862097/sdl-opengl-screenshot-is-black 
private static SDL_Surface* flip(SDL_Surface* sfc) 
{ 
     SDL_Surface* result = SDL_CreateRGBSurface(sfc.flags, sfc.w, sfc.h, 
         sfc.format.BytesPerPixel * 8, sfc.format.Rmask, sfc.format.Gmask, 
         sfc.format.Bmask, sfc.format.Amask); 
     ubyte* pixels = cast(ubyte*) sfc.pixels; 
     ubyte* rpixels = cast(ubyte*) result.pixels; 
     uint pitch = sfc.pitch; 
     uint pxlength = pitch*sfc.h; 
     assert(result != null); 

     for(uint line = 0; line < sfc.h; ++line) { 
         uint pos = line * pitch; 
         rpixels[pos..pos+pitch] = 
             pixels[(pxlength-pos)-pitch..pxlength-pos]; 
     } 

     return result; 
}
	void bind(int asIndex)
	{
	    if (asIndex == 0)  
			glActiveTexture(GL_TEXTURE0); 
	    else if (asIndex == 1)
			glActiveTexture(GL_TEXTURE1); 
	    else if (asIndex == 2)
			glActiveTexture(GL_TEXTURE2); 
	    
		glBindTexture(GL_TEXTURE_2D, glTextureID); 
	}
	
} 

final class Buffer
{
	uint glBufferID = 0;
	size_t length;
	
	static Buffer create(float[] data = null)
	{
		Buffer b = new Buffer();
		glGenBuffers(1, &(b.glBufferID));
		if (!data.empty)
			b.setData(data);
		return b;
	}

	void setData(float[] data)
	{
		length = data.length;
		glBindBuffer(GL_ARRAY_BUFFER, glBufferID);
		// Copy the data to gl buffer. Static draw: modify once, use many
		glBufferData(GL_ARRAY_BUFFER, data.length * GL_FLOAT.sizeof, data.ptr, GL_STATIC_DRAW);       
   		glBindBuffer(GL_ARRAY_BUFFER, 0); 	
	}
}

final class Mesh
{
	uint glVertexArrayID = 0;
	Buffer[] buffers;
	
	static Mesh create()
	{
		Mesh m = new Mesh();
   		glGenVertexArrays(1, &(m.glVertexArrayID)); 
   		assert(m.glVertexArrayID > 0); 
		return m;
	}
	
	void setBuffer(Buffer buf, int size, int location)
	{
   		glBindVertexArray(glVertexArrayID); 
	    glBindBuffer(GL_ARRAY_BUFFER, buf.glBufferID); 
   		glEnableVertexAttribArray(location); 
   		glVertexAttribPointer(location, size, GL_FLOAT, GL_FALSE, 0, null);          
	    glBindBuffer(GL_ARRAY_BUFFER, 0); 
		glBindVertexArray(0);  	
		if (buffers.length < (location+1))
			buffers.length = location + 1;
		buffers[location] = buf;
	} 

	void bind()
	{
		glBindVertexArray(glVertexArrayID);
	}

	
	void draw()
	{
     	glDrawArrays(GL_TRIANGLES, 0, buffers[0].length / 3); 
	}	
}

final class Material
{
	private static Material builtIn_;

	static @property Material builtIn()
	{
		if (builtIn_ is null)
		{
			builtIn_ = new Material();
			builtIn_.shader = ShaderProgram.builtIn;
			builtIn_.texture = Texture.builtIn;
		}
		return builtIn_;
	}
		
	ShaderProgram shader;
	Texture texture;
		
	Material create(const(char)[] imagePath)
	{
		Texture tex = Texture.create(imagePath);
		
		Material mat = new Material();
		mat.texture = tex;
		mat.shader = ShaderProgram.builtIn;
		return mat;
	}

	void bind()
	{
		shader.bind();
		texture.bind(0);
	}
	
	void unbind()
	{
		glBindTexture(GL_TEXTURE_2D, 0); 
	}
}

final class Model(SubModelKey)
{
	final static class SubModel
	{
		Mesh mesh;
		Material material;
		
		@property valid() const
		{
			return material.texture !is null;
		}
		void draw(Mat4f transform)
		{
			//material.shader.setUniform("colMap", 0);
			glEnable (GL_BLEND);
			glBlendFunc (GL_ONE, GL_ONE);
			material.shader.setUniform("MVP", Window.active.MVP * transform);
			material.bind();
			mesh.bind();
	//		material.shader.setUniform("MVP", Window.active.MVP * transform);
			mesh.draw();
	      	material.unbind();
	      	glBindVertexArray(0);
	      	glUseProgram(0);
		}
	}

	SubModel subModels[SubModelKey];
			
	SubModel addSubModel(SubModelKey key)
	{
		auto sm = new SubModel();
		subModels[key] = sm;
		return sm;
	}
	
	// Mesh of the first SubModel 
	@property 
	{
		Mesh mesh()
		{
			return subModels.values().front.mesh; 
		}

		void mesh(Mesh m)
		{
			subModels[subModels.keys().front].mesh = m;
		}
	
		Material material()
		{
			return subModels.values().front.material; 
		}

		void material(Material m)
		{
			subModels[subModels.keys().front].material = m;
		}
		
		@property valid() const
		{
			return subModels.values().front.valid;
		}
	}
	
	void draw(Mat4f transform)
	{
		foreach (m; subModels)
		{
			m.draw(transform);
		}
	}
}


/**
 Generate UV coord array from a vertex array on such a way that if
 a face is put in z == 0 then the mapped texture is displayed pixel
 perfect.
*/
void generateUVsPixelScale(Vec2f texSize)
{
	
}

final class GFont
{
	private TTF_Font * font;
	
	this(const(char)[] path, size_t size)
	{
		SDL_ClearError();
		
		font = TTF_OpenFont(cast(char*)path, size);
		enforceEx!Exception(font !is null, text("Error loading font ", path));
	}
	
	void calcSize(const(char)[] msg, out int w, out int h)
	{
		enforceEx!Exception(TTF_SizeUTF8(font, msg.ptr, &w, &h) > 0,
						text("Error measuring text size: ", TTF_GetError()));
	}
}

struct FontMap
{
	
}


private int nextPowerOfTwo(int i) nothrow
{
    int v = i - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    //assert(isPowerOf2(v));
    return v;
}

Texture createTextTexture(const(char)[] path, size_t size)
{
	SDL_ClearError();
	TTF_Font * font = TTF_OpenFont(cast(char*)path, size);
	if (font is null)
	{
		writeln("Error loading font ", path);
	}
	
	SDL_Color col = SDL_Color(255,255,255);
	SDL_Surface * surface = TTF_RenderUTF8_Blended(font, "hello Morld", col);
	if (surface is null)
	{
		writeln("Error creating text surface"); 
	}
	//SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE);
	
	int widthInNearestPowOf2 = nextPowerOfTwo(surface.w);
	int heightInNearestPowOf2 = nextPowerOfTwo(surface.h);
	
	// Create a surface with pow two size as appropriate for opengl convertion
	SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, widthInNearestPowOf2, heightInNearestPowOf2, 32,
											0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
	
	// This is the only line relating to blending and alpha that seems to do anything I could notice.
	SDL_Rect area;
	area.x = 0;
	area.y = 0;
	area.w = surface.w;
	area.h = surface.h;

	SDL_BlitSurface(surface, null, pow2surface, &area);
	
	auto texture = Texture.createFromSDLSurface(pow2surface);
	SDL_FreeSurface(surface);
	SDL_FreeSurface(pow2surface);
	return texture;
}

void renderText(Texture target, Rectf rect, GFont font, const(char)[] msg)
{
//	SDL_Surface * surface = SDL_CreateRGBSurface(0, cast(int)rect.w, cast(int)rect.h, 32,
//													0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
	static if (true)
	{
	auto tr = Rectf(0,0,rect.w, rect.h);
	for (int i = 0; i < 50; i++)
	{
		renderText(target, tr.pos, font, "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");	
//		renderText(target, tr.pos, font, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");	
		tr.pos.y += 14;
	}
	
	//target.blitSDLSurface(rect, surface);
	//SDL_FreeSurface(surface);
	
	return;
	SDL_Surface * surface;
	}
	
	int w, h;
	Rectf targetRect = rect;
	size_t msgIdx = 1;
	
	immutable(char)* str = null;
	immutable(char)* strtmp = null;
	
	while (!msg.empty)
	{
		msgIdx = 1;		
		do
		{
			str = strtmp;
			strtmp = toStringz(msg[0..msgIdx]);
			TTF_SizeUTF8(font.font, strtmp, &w, &h);
			//font.calcSize(msg[0..msgIdx], w, h);	
			msgIdx++;
//			writeln("idx is ", msgIdx, " ", msg.length, " ", msg[0..msgIdx], " ");
		} while (w < targetRect.w && msg.length >= msgIdx);
		
		msgIdx--;

		//writeln("info ", w, " ", h, " ", rect, " ", msgIdx, " ", strtmp, " ", str);
		
		if (h > targetRect.h)
		{
			writeln("Rect not heigh enough to render glyphs ", w, " ", h, " ", targetRect, msgIdx);
			return;
		}
		
		if (msgIdx == 1 && w > targetRect.w)
		{
			writeln("Rect not wide enough to render a glyph ", w, " ", h, " ", targetRect, " ", msgIdx, " ", msg[0..msgIdx]);
			return;
		}
		
		//writeln("aaa ", msg[0..msgIdx], " ", strtmp[0..msgIdx], " ", msgIdx);

		
		surface.renderText(targetRect.pos, font, strtmp[0..msgIdx+1]);
		msg = msg[msgIdx..$];
		targetRect.pos.y += h;
		targetRect.size.y -= h;
	}
	target.blitSDLSurface(rect, surface);
	SDL_FreeSurface(surface);
}

void renderText(SDL_Surface * target, Vec2f pos, GFont font, const(char)[] msg)
{
	SDL_ClearError();
	
	SDL_Color col = SDL_Color(255,255,255);
	SDL_Surface * surface = TTF_RenderUTF8_Blended(font.font, msg.ptr, col);
	enforceEx!Exception(surface !is null, "Error creating text surface"); 

	// Create a surface with pow two size as appropriate for opengl convertion
	//int width = cast(int)fmin(surface.w, target.width);
	//int height = cast(int)fmin(surface.h, target.height);
	
	//SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, width, height, 32,
													//0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
	
	// This is the only line relating to blending and alpha that seems to do anything I could notice.
	SDL_Rect area;
	area.x = cast(int)pos.x;
	area.y = cast(int)pos.y;
	area.w = cast(int)(target.w >= pos.x + surface.w ? surface.w : target.w - pos.x);
	area.h = cast(int)(target.h >= pos.y + surface.h ? surface.h : target.h - pos.y);
//	area.h = surface.h;

	SDL_BlitSurface(surface, null, target, &area);
	
	//Rectf rect = Rectf(pos.x, pos.y, pos.x +  width, pos.y + height);
	//target.blitSDLSurface(rect, pow2surface);
	SDL_FreeSurface(surface);
	//SDL_FreeSurface(pow2surface);
}

void renderText(Texture target, Vec2f pos, GFont font, const(char)[] msg)
{
	SDL_ClearError();
	
	SDL_Color col = SDL_Color(255,255,255);
	SDL_Surface * surface = TTF_RenderUTF8_Blended(font.font, msg.ptr, col);
	enforceEx!Exception(surface !is null, "Error creating text surface"); 

	// Create a surface with pow two size as appropriate for opengl convertion
	int width = cast(int)fmin(surface.w, target.width);
	int height = cast(int)fmin(surface.h, target.height);
	
	SDL_Surface * pow2surface = SDL_CreateRGBSurface(0, width, height, 32,
													0, 0, 0, 0);
											//0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
	
	// This is the only line relating to blending and alpha that seems to do anything I could notice.
	SDL_Rect area;
	area.x = 0;
	area.y = 0;
	area.w = width;
	area.h = height;

	SDL_BlitSurface(surface, null, pow2surface, &area);
	
	Rectf rect = Rectf(pos.x, pos.y, pos.x +  width, pos.y + height);
	target.blitSDLSurface(rect, pow2surface);
	SDL_FreeSurface(surface);
	SDL_FreeSurface(pow2surface);
}