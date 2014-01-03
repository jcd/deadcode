module math._;

public import math.rect;
public import math.region;
public import math.smallmatrix;
public import math.smallvector;

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
