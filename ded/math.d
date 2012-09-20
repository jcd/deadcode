module math;

import std.math : fmin, fmax;

import smallvector;
import smallmatrix;

template Vec2(T) { alias SmallVector!(2u, T) Vec2; }
template Vec3(T) { alias SmallVector!(3u, T) Vec3; }

alias vec2f Vec2f;
alias vec3f Vec3f;
alias mat4f Mat4f;

/+

struct Vec2(T)
{
	union
	{
		struct 
		{
			T x;
			T y;
		}
		struct 
		{
			T w;
			T h;
		}
		T[2] data;
	}
			/*
	T opIndex(uint i) const
	{
		assert(i < 2);
		return (cast(T[])(this))[i];
	}

	 */
	
	@property T lengthSquared()
	{
		return x*x + y*y;
	}

	import std.stdio;
	
	Vec2!T opBinary(string OP)(Vec2!T v) const pure nothrow
	{
		return Vec2!T(mixin("x " ~ OP ~ " v.x"), mixin("y " ~ OP ~ " v.y"));
	}
	
	void opOpAssign(string OP)(Vec2!(T) v) pure nothrow
	{
		mixin("this.x" ~ OP ~ "= v.x;"); 
		mixin("this.y" ~ OP ~ "= v.y;");
	} 

	void opOpAssign(string OP)(T v) pure nothrow
	{
		mixin("this.x" ~ OP ~ "= v;"); 
		mixin("this.y" ~ OP ~ "= v;");
	} 
	
	Vec2!T opUnary(string OP)() pure nothrow
	{
		Vec2 r;
		mixin("r.x = " ~ OP ~ "x;"); 
		mixin("r.y = " ~ OP ~ "y;"); 
		return r;
	}
}

alias Vec2!(float) Vec2f;

struct Vec3(T)
{
	union
	{
		struct 
		{
			T x;
			T y;
			T z;
		}
		struct 
		{
			T w;
			T h;
			T d;
		}
		struct 
		{
			T r;
			T g;
			T b;
		}
		T[3] data;
	}
		
/*
	T opIndex(uint i) const
	{
		assert(i < 3);
		return (cast(T[])(this))[i];
	}
 */
}

alias Vec3!(float) Vec3f;
+/

struct Rect(T)
{
	static immutable Rectf unit = Rectf(0,0,1,1);
	
	Vec2!T pos; 
	Vec2!T size;		

	this(T x, T y, T x2, T y2)
	{
		pos.x = x;
		pos.y = y;
		size.x = x2 - x;
		size.y = y2 - y;
	}
	
	this(Vec2!T pos, Vec2!T size)
	{
		this.pos = pos;
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

	@property T h() const
	{
		return size.y; /* height */
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
