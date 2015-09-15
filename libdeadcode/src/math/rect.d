module math.rect;

import animation.mutator;

import math.smallvector;
import std.math : fmin, fmax, isNaN;
import std.string : format;

import test;
mixin registerUnittests;

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

	@property empty() const @safe
	{
		return isNaN(size.x) || isNaN(size.y) || size.x == 0 || size.y == 0 || isNaN(pos.x) || isNaN(pos.y);
	}

    @property isPoint() const @safe
    {
        return size.x == 0 && size.y == 0;
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

	Rect!T offset(RectOffset!T rectOffset) const pure nothrow
	{
		Rect!T r = this;
		r.pos.x += rectOffset.left;
		r.pos.y += rectOffset.top;
		r.size.x -= rectOffset.horizontal;
		r.size.y -= rectOffset.vertical;
		return r;
	}

    Rect!T offset(Vec2!T offset) const pure nothrow
	{
		Rect!T r = this;
		r.pos.x += offset.x;
		r.pos.y += offset.y;
		return r;
	}

	Rect!T clip(Rect!T toBeClipped) const pure nothrow
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

	Rect!T makeUnion(Rect!T other) const pure nothrow
	{
		import std.algorithm;
		Rectf result;
		result.x = min(this.x, other.x, this.x2, other.x2);
		result.y = min(this.y, other.y, this.y2, other.y2);
		result.x2 = max(this.x, other.x, this.x2, other.x2);
		result.y2 = max(this.y, other.y, this.y2, other.y2);
		//if (other.w < 0)
		//    other.size.x = 0f;
		//if (other.h < 0)
		//    other.size.y = 0f;
		return result;
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

	//	Rect!T opBinary(string OP)(Vec2!T v) const
	Rect!T opBinary(string OP)(Rect!T v) const pure nothrow
	{
		Rect!T res = this;
		mixin("res.pos " ~ OP ~ "= v.pos;");
		mixin("res.size " ~ OP ~ "= v.size;");
		return res;
	}

	//	void opOpAssign(string OP)(Vec2!T v) pure nothrow
	void opOpAssign(string OP)(Rect!T v) pure nothrow
	{
		mixin("this.pos" ~ OP ~ "= v.pos;");
		mixin("this.size" ~ OP ~ "= v.size;");
	}

	Rect!T opBinary(string OP)(T v) const pure nothrow if (OP == "*" || OP == "/")
	{
		Rect!T res = this;
		mixin("res.pos " ~ OP ~ "= v;");
		mixin("res.size " ~ OP ~ "= v;");
		return res;
	}

	void opOpAssign(string OP)(T v) pure nothrow if (OP == "*" || OP == "/")
	{
		mixin("this.pos" ~ OP ~ "= v;");
		mixin("this.size" ~ OP ~ "= v;");
	}

	Rect!T scale(float s) const pure nothrow
	{
		Rect!T r = this;
		r.pos *= s;
		r.size *= s;
		return r;
	}

	Rect!T scale(Vec2!T s) const pure nothrow
	{
		Rect!T r = this;
		r.pos *= s;
		r.size *= s;
		return r;
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

    import std.traits;
    static if (isFloatingPoint!T)
    {
        bool isIdentical(Rect!T v) const pure nothrow @safe
        {
            return pos.isIdentical(v.pos) && size.isIdentical(v.size);
        }
    }

	string toString() const
	{
		return std.string.format("Rect(%s,%s,%s,%s)", x, y, w, h);
	}

	unittest
	{
		int a = 0;
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
	Rectf r = Rectf(1, 2, 3, 4);
	Assert(!std.math.isNaN(r.pos.x));
	Assert(stringToRectf("1 2 3 4.5"), Rectf(1,2,3,4.5));
}

unittest
{
	Rectf r = Rectf(1, 2, 3, 4);
	Assert(!std.math.isNaN(r.pos.x));
	Assert(stringToRectf("1 2 3 4.5"), Rectf(1,2,3,4.5));
}

struct RectOffset(T)
{
	T left;
	T top;
	T right;
	T bottom;

	@property T horizontal()
	{
		return left + right;
	}

	@property T vertical()
	{
		return top + bottom;
	}

	RectOffset!T reverse() const pure nothrow
	{
		return RectOffset!T(-left, -top, -right, -bottom);
	}

	RectOffset!T opBinary(string OP)(RectOffset!T v) const pure nothrow
	{
		RectOffset!T res = this;
		mixin("res.left " ~ OP ~ "= v.left;");
		mixin("res.top " ~ OP ~ "= v.top;");
		mixin("res.right " ~ OP ~ "= v.right;");
		mixin("res.bottom " ~ OP ~ "= v.bottom;");
		return res;
	}

	void opOpAssign(string OP)(RectOffset!T v) pure nothrow
	{
		mixin("this.left" ~ OP ~ "= v.left;");
		mixin("this.top" ~ OP ~ "= v.top;");
		mixin("this.right" ~ OP ~ "= v.right;");
		mixin("this.bottom" ~ OP ~ "= v.bottom;");
	}

	RectOffset!T opBinary(string OP)(T v) const pure nothrow if (OP == "*" || OP == "/")
	{
		RectOffset!T res = this;
		mixin("res.left " ~ OP ~ "= v;");
		mixin("res.top " ~ OP ~ "= v;");
		mixin("res.right " ~ OP ~ "= v;");
		mixin("res.bottom " ~ OP ~ "= v;");
		return res;
	}

	void opOpAssign(string OP)(T v) pure nothrow if (OP == "*" || OP == "/")
	{
		mixin("this.left" ~ OP ~ "= v;");
		mixin("this.top" ~ OP ~ "= v;");
		mixin("this.right" ~ OP ~ "= v;");
		mixin("this.bottom" ~ OP ~ "= v;");
	}

	@property bool empty() @safe nothrow
	{
		import std.math;
		return isNaN(top) || isNaN(left) || isNaN(bottom) || isNaN(right) || (top == 0f && left == 0f && bottom == 0f && right == 0f);
	}
}

alias RectOffset!float RectfOffset;
