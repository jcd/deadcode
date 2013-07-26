module math.rect;

import math.smallvector;
import std.math : fmin, fmax;

struct Rect(T)
{
	Vec2!T pos; 
	Vec2!T size;
	
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
	
	@property T x() const 
	{
		return pos.x;
	}
	
	@property void x(T v)
	{
		pos.x = v;
	}
	
	@property T y() const
	{ 
		return pos.y;
	}
	
	@property void y(T v)
	{
		pos.y = v;
	}
	
	@property T x2() const
	{
		return pos.x + size.x; /* width */
	}
	
	@property void x2(T v)
	{
		size.x = v - pos.x;
	}
	
	@property T y2() const
	{
		return pos.y + size.y; /* height */
	}
	
	@property void y2(T v)
	{
		size.y = v - pos.y;
	}
	
	@property T w() const
	{
		return size.x; /* width */
	}
	
	@property void w(T v)
	{
		size.x = v;
	}
	
	@property T h() const
	{
		return size.y; /* height */
	}
	
	@property void h(T v)
	{
		size.y = v;
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
	
	bool contains(Vec2!T point)
	{
		return point.x <= x2 && point.x >= x && point.y <= y2 && point.y >= y;
	}
}

alias Rect!(float) Rectf;


unittest 
{
	Rectf r = Rectf(1, 2, 3, 4);
	assert(!std.math.isNaN(r.pos.x));
}