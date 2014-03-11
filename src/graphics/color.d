module graphics.color;

import math._;

import std.exception;
import std.range;
import std.format;

struct Color
{
	static immutable Color black  = Color(0, 0, 0);
	static immutable Color white = Color(1.0, 1.0, 1.0);
	static immutable Color red = Color(1.0, 0.0, 0.0);
	static immutable Color green = Color(0.0, 1.0, 0.0);
	static immutable Color blue = Color(0.0, 0.0, 1.0);
	static immutable Color yellow = Color(1.0, 1.0, 0.0);
	static immutable Color cyan = Color(0.0, 1.0,  1.0);
	static immutable Color magenta = Color(1.0, 0.0, 1.0);

	union 
	{
		float[3] v;
		struct 
		{
			float r, g, b;
		}
	}

	@property
	{
		@safe ubyte rByte() const nothrow
		{
			return cast(ubyte) (r * 255.0f);
		}

		@safe ubyte gByte() const nothrow
		{
			return cast(ubyte) (g * 255.0f);
		}

		@safe ubyte bByte() const nothrow
		{
			return cast(ubyte) (b * 255.0f);
		}
	}

	this(float _r, float _g, float _b)
	{
		r = _r;
		g = _g;
		b = _b;
	}
	
	string toString()
	{
		import std.format;
		return format("Color(%s, %s, %s)", r, g ,b);
	}

	uint toUint()
	{
		uint ur = cast(uint) (r * 255.0f);
		uint ug = cast(uint) (g * 255.0f);
		uint ub = cast(uint) (b * 255.0f);
		uint res = (ur << 24) + (ug << 16) + (ub << 8) + 0xff;
		return res;
	}

	Vec3f toVec3f()
	{
		return Vec3f(v);
	}
}

Color stringToColor(string str)
{
	uint v;
	formattedRead(str, "#%x", &v);
	float r = cast(float)((v >> 16) & 0xFF) / 255.0f;
	float g = cast(float)((v >> 8)  & 0xFF) / 255.0f;
	float b = cast(float)((v >> 0)  & 0xFF) / 255.0f;
	return Color(r, g, b);	
}

unittest
{
	import test;
	Assert(stringToColor("#8800FF"), Color(cast(float)0x88 / 255f, 0.0, 1.0));
}
