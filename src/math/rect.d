module math.rect;

import math.smallvector;
import std.math : fmin, fmax;
import std.string : format;

struct Rect(T)
{
	Vec2!T pos; 
	Vec2!T size;
	
	this(Rect!T r)
	{
		pos.x = r.pos.x;
		pos.y = r.pos.y;
		size.x = r.size.x;
		size.y = r.size.y;
	}

	this(T x, T y, T w, T h)
	{
		pos.x = x; 
		pos.y = y;
		size.x = w;
		size.y = h;
	}
	
	this(Vec2!T pos, Vec2!T size)
	{
		this.pos = pos;
		this.size = size;
	}
	
	this(Vec2!T pos, T w, T h)
	{
		this.pos = pos;
		size.x = w;
		size.y = h;
	}
	
	this(T x, T y, Vec2!T size)
	{
		pos.x = x;
		pos.y = y;
		this.size = size;
	}

	@property ref T x()  
	{
		return pos.x; 
	}

	@property const(T) x() const
	{
		return pos.x; 
	}

	@property ref T y()  
	{
		return pos.y; 
	}
	
	@property const(T) y() const
	{
		return pos.y; 
	}

	@property  const(T) x2() const
	{
		return pos.x + size.x; /* width */
	}
	
	@property void x2(T v)
	{
		size.x = v - pos.x;
	}
	
	@property const(T) y2() const
	{
		return pos.y + size.y; /* height */
	}
	
	@property void y2(T v)
	{
		size.y = v - pos.y;
	}

	@property const(Vec2!T) posMax() const
	{
		return pos + size;
	}

	@property void posMax(Vec2!T v)
	{
		x2 = v.x;
		y2 = v.y;
	}

	@property ref T w()  
	{
		return size.x; 
	}
	
	@property const(T) w() const
	{
		return size.x; 
	}

	
	@property ref T h()  
	{
		return size.y; 
	}
	
	@property const(T) h() const
	{
		return size.y; 
	}
	
	Rect!T clip(Rect!T toBeClipped)
	{
		toBeClipped.x = fmax(this.x, toBeClipped.x);
		toBeClipped.y = fmax(this.y, toBeClipped.y);
		toBeClipped.x2 = fmin(this.x2, toBeClipped.x2);
		toBeClipped.y2 = fmin(this.y2, toBeClipped.y2);
		if (toBeClipped.w < 0)
			toBeClipped.size.x = 0f;
		if (toBeClipped.h < 0)
			toBeClipped.size.y = 0f;
		return toBeClipped;
	}
	
	//	Rect!T opBinary(string OP)(Vec2!T v) const
	Rect!T opBinary(string OP)(SmallVector!(2u,T) v) const pure nothrow
	{
		Rect!T res = this;
		mixin("res " ~ OP ~ "= v;");
		return res;
	}
	
	//	void opOpAssign(string OP)(Vec2!T v) pure nothrow
	void opOpAssign(string OP)(SmallVector!(2u,T) v) pure nothrow
	{
		mixin("this.pos.x" ~ OP ~ "= v.x;");
		mixin("this.pos.y" ~ OP ~ "= v.y;");
	}
	
	bool contains(const(Vec2!T) point) const
	{	
		// Since size can be negative we need two paths
		bool contained = void;
		if (size.x < 0)
		{
			contained = point.x >= x2 && point.x <= x;
		}
		else
		{
			contained = point.x <= x2 && point.x >= x;
		}

		if (size.y < 0)
		{
			contained = contained && (point.y >= y2 && point.y <= y);
		}
		else
		{
			contained = contained && (point.y <= y2 && point.y >= y);
		}

		return contained;
	}

	string toString() const
	{
		return std.string.format("Rect(%s,%s,%s,%s)", x, y, w, h);
	}
}

alias Rect!(float) Rectf;

Rectf stringToRectf(string str)
{
	import std.format;
	float x, y, w, h;
	formattedRead(str, "%f %f %f %f", &x, &y, &w, &h);
	return Rectf(x, y, w, h);
}

unittest 
{
	import test;
	Rectf r = Rectf(1, 2, 3, 4);
	Assert(!std.math.isNaN(r.pos.x));
	Assert(stringToRectf("1 2 3 4.5"), Rectf(1,2,3,4.5));
}
