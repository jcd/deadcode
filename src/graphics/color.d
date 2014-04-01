module graphics.color;

import math._;

import std.conv;
import std.exception;
import std.range;
import std.format;
import std.string;
import std.typecons;

struct Color
{
	//static immutable Color black  = Color(0, 0, 0);
	//static immutable Color white = Color(1.0, 1.0, 1.0);
	//static immutable Color red = Color(1.0, 0.0, 0.0);
	//static immutable Color green = Color(0.0, 1.0, 0.0);
	//static immutable Color blue = Color(0.0, 0.0, 1.0);
	//static immutable Color yellow = Color(1.0, 1.0, 0.0);
	//static immutable Color cyan = Color(0.0, 1.0,  1.0);
	//static immutable Color magenta = Color(1.0, 0.0, 1.0);

	uint v;

	@property
	{
		@safe ubyte rByte() const nothrow pure
		{
			return cast(ubyte) ( (v >> 24) & 0xFF );
		}

		@safe ubyte gByte() const nothrow pure
		{
			return cast(ubyte) ( (v >> 16) & 0xFF );
		}

		@safe ubyte bByte() const nothrow pure
		{
			return cast(ubyte) ( (v >> 8) & 0xFF );
		}

		@safe ubyte aByte() const nothrow pure
		{
			return cast(ubyte) ( v & 0xFF );
		}

		@safe float r() const nothrow pure
		{
			return cast(float) rByte / 255f;
		}

		@safe float g() const nothrow pure
		{
			return cast(float) gByte / 255f;
		}

		@safe float b() const nothrow pure
		{
			return cast(float) bByte / 255f;
		}

		@safe float a() const nothrow pure
		{
			return cast(float) aByte / 255f;
		}


	}

	this(uint val)
	{
		v = val;
	}
	
	this(float r, float g, float b, float a = 1.0f) nothrow pure
	{
		// TODO: Clamping?
		uint ur = cast(uint) (r * 255.0f);
		uint ug = cast(uint) (g * 255.0f);
		uint ub = cast(uint) (b * 255.0f);
		uint ua = cast(uint) (a * 255.0f);
		v = (ur << 24) | (ug << 16) | (ub << 8) | ua;
	}
	
	static Color fromUByte(ubyte _r, ubyte _g, ubyte _b, ubyte _a = 0xff) nothrow pure
	{
		Color c;
		c.v = (_r << 24) | (_g << 16) | (_b << 8) | _a;
		return c;
	}
	
	static Color fromRGB(float _r, float _g, float _b) nothrow pure
	{
		return Color(_r, _g, _b);
	}

	static Color fromRGBA(float _r, float _g, float _b, float _a) nothrow pure
	{
		return Color(_r, _g, _b, _a);
	}

	// h s l a are [0:1]
	static Color fromHSLA(float h, float s, float l, float _a) nothrow pure
	{
		// Converted to D from http://axonflux.com/handy-rgb-to-hsl-and-rgb-to-hsv-color-model-c
		if(s == 0)
		{
			return Color(l, l, l, _a); // achromatic
		}
		else
		{
			static float hueToRGB(float p, float q, float t) nothrow pure
			{
				if(t < 0) t += 1;
				if(t > 1) t -= 1;
				if(t < 1.0/6.0) return p + (q - p) * 6.0 * t;
				if(t < 1.0/2.0) return q;
				if(t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
				return p;
			}

			auto q = l < 0.5 ? l * (1 + s) : l + s - l * s;
			auto p = 2.0 * l - q;
			float _r = hueToRGB(p, q, h + 1.0/3.0);
			float _g = hueToRGB(p, q, h);
			float _b = hueToRGB(p, q, h - 1.0/3.0);
			return Color(_r, _g, _b, _a);
		}
	}

	// h s l are [0:1]
	static Color fromHSL(float h, float s, float l) nothrow pure
	{
		return Color.fromHSLA(h, s, l, 1f);
	}

	static auto fromCSSHexString(string str) pure
	{
		// #FFA099 or #FFA09904
		Color res;
		uint v;
		bool hasAlpha = str.length > 7;
		if (formattedRead(str, "#%x", &v) != 1)
			return tuple(res, false);
		if (hasAlpha)
			res.v = v; // alpha
		else
			res.v = v << 8 | 0xFF; // no alpha
		return tuple(res, true);
	}

	static auto fromCSSrgbString(string str)
	{
		import std.regex;
		// rgb(255, 255, 255);
		auto r = ctRegex!(r"\srgb\s?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)","i");
		auto captures = matchFirst(str, r);
		if (captures.empty)
			return tuple(Color.init, false);

		ubyte rr = to!ubyte(captures[0]);
		ubyte gg = to!ubyte(captures[1]);
		ubyte bb = to!ubyte(captures[2]);
		return tuple(Color.fromUByte(rr, gg, bb, 0xff), true);
	}

	static auto fromCSSrgbaString(string str)
	{
		import std.regex;
		// rgba(255, 255, 255, 0.2);
		auto r = ctRegex!(r"\srgba\s?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,(\d(?:.\d+))\s*\)","i");
		auto captures = matchFirst(str, r);
		if (captures.empty)
			return tuple(Color.init, false);

		ubyte rr = to!ubyte(captures[0]);
		ubyte gg = to!ubyte(captures[1]);
		ubyte bb = to!ubyte(captures[2]);
		ubyte aa = to!ubyte(captures[3]);
		return tuple(Color.fromUByte(rr, gg, bb, aa), true);
	}

	static auto fromCSShslString(string str)
	{
		import std.regex;
		// hsl(360, 100%, 100%);
		auto r = ctRegex!(r"\shsl\s?\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*\)","i");
		auto captures = matchFirst(str, r);
		if (captures.empty)
			return tuple(Color.init, false);

		float h = to!float(captures[0]) / 360.0f;
		float s = to!float(captures[1]) / 100.0f;
		float l = to!float(captures[2]) / 100.0f;
		return tuple(Color.fromHSL(h, s, l), true);
	}

	static auto fromCSShslaString(string str)
	{
		import std.regex;
		// hsla(360, 100%, 100%, 0.2);
		auto r = ctRegex!(r"\shsla\s?\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*,(\d(?:.\d+))\s*\)","i");
		auto captures = matchFirst(str, r);
		if (captures.empty)
			return tuple(Color.init, false);

		float h = to!float(captures[0]) / 360.0f;
		float s = to!float(captures[1]) / 100.0f;
		float l = to!float(captures[2]) / 100.0f;
		float a = to!float(captures[3]);
		return tuple(Color.fromHSLA(h, s, l, a), true);
	}


	static auto fromName(string name) pure nothrow
	{
		return colorNameToColor(name);
	}

	static auto fromCSSString(string str)
	{
		auto res = fromCSSHexString(str);
		if (res[1]) return res;

		res = fromCSSrgbString(str);
		if (res[1]) return res;

		res = fromCSSrgbaString(str);
		if (res[1]) return res;

		res = fromCSShslString(str);
		if (res[1]) return res;

		res = fromCSShslaString(str);
		if (res[1]) return res;

		return fromName(str);
	}

	Color scaleColor(float scale) const pure nothrow
	{
		return Color(r * scale, g * scale, b * scale, a);
	}

	static Color opDispatch(string op)() pure nothrow if ( (op in s_NameToColorMap) !is null)
	{
		return fromName(op)[0];
	}

	string toString()
	{
		import std.format;
		return format("Color(%s, %s, %s, %s)", r, g ,b, a);
	}

	uint toUint() const pure nothrow
	{
		uint ur = cast(uint) (r * 255.0f);
		uint ug = cast(uint) (g * 255.0f);
		uint ub = cast(uint) (b * 255.0f);
		uint ua = cast(uint) (b * 255.0f);
		uint res = (ur << 24) + (ug << 16) + (ub << 8) + ua;
		return res;
	}

	Vec3f toVec3f() const pure nothrow
	{
		return Vec3f(r,g,b);
	}

	Vec4f toVec4f() const pure nothrow
	{
		return Vec4f(r,g,b,a);
	}
}

unittest
{
	import test;
	Assert(Color.fromCSSHexString("#8800FF")[0], Color(cast(float)0x88 / 255f, 0.0, 1.0));
	Assert(Color.fromCSSHexString("#8800FF0A")[0], Color(cast(float)0x88 / 255f, 0.0, 1.0, cast(float)0x0A / 255f));
	Assert(Color.fromCSSString("#8800FF")[0], Color(cast(float)0x88 / 255f, 0.0, 1.0));
}


private
{
	enum s_NameToColorMap = [ 
	"snow" : Color.fromUByte(255, 250, 250),
	"ghostwhite" : Color.fromUByte(248, 248, 255),
	"whitesmoke" : Color.fromUByte(245, 245, 245),
	"gainsboro" : Color.fromUByte(220, 220, 220),
	"floralwhite" : Color.fromUByte(255, 250, 240),
	"oldlace" : Color.fromUByte(253, 245, 230),
	"linen" : Color.fromUByte(250, 240, 230),
	"antiquewhite" : Color.fromUByte(250, 235, 215),
	"papayawhip" : Color.fromUByte(255, 239, 213),
	"blanchedalmond" : Color.fromUByte(255, 235, 205),
	"bisque" : Color.fromUByte(255, 228, 196),
	"peachpuff" : Color.fromUByte(255, 218, 185),
	"navajowhite" : Color.fromUByte(255, 222, 173),
	"moccasin" : Color.fromUByte(255, 228, 181),
	"cornsilk" : Color.fromUByte(255, 248, 220),
	"ivory" : Color.fromUByte(255, 255, 240),
	"lemonchiffon" : Color.fromUByte(255, 250, 205),
	"seashell" : Color.fromUByte(255, 245, 238),
	"honeydew" : Color.fromUByte(240, 255, 240),
	"mintcream" : Color.fromUByte(245, 255, 250),
	"azure" : Color.fromUByte(240, 255, 255),
	"aliceblue" : Color.fromUByte(240, 248, 255),
	"lavender" : Color.fromUByte(230, 230, 250),
	"lavenderblush" : Color.fromUByte(255, 240, 245),
	"mistyrose" : Color.fromUByte(255, 228, 225),
	"white" : Color.fromUByte(255, 255, 255),
	"black" : Color.fromUByte(0, 0, 0),
	"darkslategray" : Color.fromUByte(47, 79, 79),
	"darkslategrey" : Color.fromUByte(47, 79, 79),
	"dimgray" : Color.fromUByte(105, 105, 105),
	"dimgrey" : Color.fromUByte(105, 105, 105),
	"slategray" : Color.fromUByte(112, 128, 144),
	"slategrey" : Color.fromUByte(112, 128, 144),
	"lightslategray" : Color.fromUByte(119, 136, 153),
	"lightslategrey" : Color.fromUByte(119, 136, 153),
	"gray" : Color.fromUByte(190, 190, 190),
	"lightgrey" : Color.fromUByte(211, 211, 211),
	"lightgray" : Color.fromUByte(211, 211, 211),
	"midnightblue" : Color.fromUByte(25, 25, 112),
	"navy" : Color.fromUByte(0, 0, 128),
	"navyblue" : Color.fromUByte(0, 0, 128),
	"cornflowerblue" : Color.fromUByte(100, 149, 237),
	"darkslateblue" : Color.fromUByte(72, 61, 139),
	"slateblue" : Color.fromUByte(106, 90, 205),
	"mediumslateblue" : Color.fromUByte(123, 104, 238),
	"lightslateblue" : Color.fromUByte(132, 112, 255),
	"mediumblue" : Color.fromUByte(0, 0, 205),
	"royalblue" : Color.fromUByte(65, 105, 225),
	"blue" : Color.fromUByte(0, 0, 255),
	"dodgerblue" : Color.fromUByte(30, 144, 255),
	"deepskyblue" : Color.fromUByte(0, 191, 255),
	"skyblue" : Color.fromUByte(135, 206, 235),
	"lightskyblue" : Color.fromUByte(135, 206, 250),
	"steelblue" : Color.fromUByte(70, 130, 180),
	"lightsteelblue" : Color.fromUByte(176, 196, 222),
	"lightblue" : Color.fromUByte(173, 216, 230),
	"powderblue" : Color.fromUByte(176, 224, 230),
	"paleturquoise" : Color.fromUByte(175, 238, 238),
	"darkturquoise" : Color.fromUByte(0, 206, 209),
	"mediumturquoise" : Color.fromUByte(72, 209, 204),
	"turquoise" : Color.fromUByte(64, 224, 208),
	"cyan" : Color.fromUByte(0, 255, 255),
	"lightcyan" : Color.fromUByte(224, 255, 255),
	"cadetblue" : Color.fromUByte(95, 158, 160),
	"mediumaquamarine" : Color.fromUByte(102, 205, 170),
	"aquamarine" : Color.fromUByte(127, 255, 212),
	"darkgreen" : Color.fromUByte(0, 100, 0),
	"darkolivegreen" : Color.fromUByte(85, 107, 47),
	"darkseagreen" : Color.fromUByte(143, 188, 143),
	"seagreen" : Color.fromUByte(46, 139, 87),
	"mediumseagreen" : Color.fromUByte(60, 179, 113),
	"lightseagreen" : Color.fromUByte(32, 178, 170),
	"palegreen" : Color.fromUByte(152, 251, 152),
	"springgreen" : Color.fromUByte(0, 255, 127),
	"lawngreen" : Color.fromUByte(124, 252, 0),
	"green" : Color.fromUByte(0, 255, 0),
	"chartreuse" : Color.fromUByte(127, 255, 0),
	"mediumspringgreen" : Color.fromUByte(0, 250, 154),
	"greenyellow" : Color.fromUByte(173, 255, 47),
	"limegreen" : Color.fromUByte(50, 205, 50),
	"yellowgreen" : Color.fromUByte(154, 205, 50),
	"forestgreen" : Color.fromUByte(34, 139, 34),
	"olivedrab" : Color.fromUByte(107, 142, 35),
	"darkkhaki" : Color.fromUByte(189, 183, 107),
	"khaki" : Color.fromUByte(240, 230, 140),
	"palegoldenrod" : Color.fromUByte(238, 232, 170),
	"lightgoldenrodyellow" : Color.fromUByte(250, 250, 210),
	"lightyellow" : Color.fromUByte(255, 255, 224),
	"yellow" : Color.fromUByte(255, 255, 0),
	"gold" : Color.fromUByte(255, 215, 0),
	"lightgoldenrod" : Color.fromUByte(238, 221, 130),
	"goldenrod" : Color.fromUByte(218, 165, 32),
	"darkgoldenrod" : Color.fromUByte(184, 134, 11),
	"rosybrown" : Color.fromUByte(188, 143, 143),
	"indianred" : Color.fromUByte(205, 92, 92),
	"saddlebrown" : Color.fromUByte(139, 69, 19),
	"sienna" : Color.fromUByte(160, 82, 45),
	"peru" : Color.fromUByte(205, 133, 63),
	"burlywood" : Color.fromUByte(222, 184, 135),
	"beige" : Color.fromUByte(245, 245, 220),
	"wheat" : Color.fromUByte(245, 222, 179),
	"sandybrown" : Color.fromUByte(244, 164, 96),
	"tan" : Color.fromUByte(210, 180, 140),
	"chocolate" : Color.fromUByte(210, 105, 30),
	"firebrick" : Color.fromUByte(178, 34, 34),
	"brown" : Color.fromUByte(165, 42, 42),
	"darksalmon" : Color.fromUByte(233, 150, 122),
	"salmon" : Color.fromUByte(250, 128, 114),
	"lightsalmon" : Color.fromUByte(255, 160, 122),
	"orange" : Color.fromUByte(255, 165, 0),
	"darkorange" : Color.fromUByte(255, 140, 0),
	"coral" : Color.fromUByte(255, 127, 80),
	"lightcoral" : Color.fromUByte(240, 128, 128),
	"tomato" : Color.fromUByte(255, 99, 71),
	"orangered" : Color.fromUByte(255, 69, 0),
	"red" : Color.fromUByte(255, 0, 0),
	"hotpink" : Color.fromUByte(255, 105, 180),
	"deeppink" : Color.fromUByte(255, 20, 147),
	"pink" : Color.fromUByte(255, 192, 203),
	"lightpink" : Color.fromUByte(255, 182, 193),
	"palevioletred" : Color.fromUByte(219, 112, 147),
	"maroon" : Color.fromUByte(176, 48, 96),
	"mediumvioletred" : Color.fromUByte(199, 21, 133),
	"violetred" : Color.fromUByte(208, 32, 144),
	"magenta" : Color.fromUByte(255, 0, 255),
	"violet" : Color.fromUByte(238, 130, 238),
	"plum" : Color.fromUByte(221, 160, 221),
	"orchid" : Color.fromUByte(218, 112, 214),
	"mediumorchid" : Color.fromUByte(186, 85, 211),
	"darkorchid" : Color.fromUByte(153, 50, 204),
	"darkviolet" : Color.fromUByte(148, 0, 211),
	"blueviolet" : Color.fromUByte(138, 43, 226),
	"purple" : Color.fromUByte(160, 32, 240),
	"mediumpurple" : Color.fromUByte(147, 112, 219),
	"thistle" : Color.fromUByte(216, 191, 216),
	"darkgrey" : Color.fromUByte(169, 169, 169),
	"darkgray" : Color.fromUByte(169, 169, 169),
	"darkblue" : Color.fromUByte(0, 0, 139),
	"darkcyan" : Color.fromUByte(0, 139, 139),
	"darkmagenta" : Color.fromUByte(139, 0, 139),
	"darkred" : Color.fromUByte(139, 0, 0),
	"lightgreen" : Color.fromUByte(144, 238, 144) ];

	auto colorNameToColor(string name) pure nothrow
	{
		// http://en.wikipedia.org/wiki/X11_color_names
		try 
		{
			if (name.startsWith("grey"))
				name = "gray" ~ name[4..$];
		
			if (name.startsWith("gray"))
			{
				if (name == "gray")
					return tuple(Color.fromUByte(190, 190, 190), true);
				auto val = to!float(name[4..$]) / 255f;
				return tuple(Color(val, val, val), true);
			}

			if ("1234".indexOf(name[$-1]) != -1)
			{
				auto col = name[0..$-1] in s_NameToColorMap;
				if (col !is null)
				{
					auto num = name[$-1];
					switch (num)
					{
						case '1':
							name = name[0..$-1];
							break;
						case '2':
							// color × 93.2%
							return tuple(col.scaleColor(0.932), true);
						case '3':
							// color × 80.4%
							return tuple(col.scaleColor(0.804), true);
						case '4':
							// color × 54.8%
							return tuple(col.scaleColor(0.548), true);
						default:
							return tuple(Color.init, false);
					}
				}
			}

			auto col = name in s_NameToColorMap;
			if (col !is null)
				return tuple(*col, true);			

			return tuple(Color.init, false);
		}
		catch (Exception e)
		{
			return tuple(Color.init, false);
		}		
	}
}
