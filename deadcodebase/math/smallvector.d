module math.smallvector;

//import animation.mutator;

import std.math;
import std.traits;
import std.string : format;
import std.conv;

// Part of GFM: https://github.com/d-gamedev-team/gfm

// generic 1D small vector
// N is the element count, T the contained type
// intended for 3D
// TODO: - generic way to build a SmallVector from a variadic constructor of scalars, tuples, arrays and smaller vectors
//       - find a way to enable swizzling assignment
// TBD:  - do we need support for slice assignment and opSliceOpAsssign? meh.

align(1) struct SmallVector(size_t N, T)
{
nothrow:
    public
    {
        static assert(N >= 1u);

        // fields definition
        union
        {
            T[N] v;

			//@Bindable()
			struct
            {
                static if (N >= 1) T x;
                static if (N >= 2) T y;
                static if (N >= 3) T z;
                static if (N >= 4) T w;
            }
        }

        static if (N == 2u)
        {
            this(X : T, Y : T)(X x_, Y y_) pure nothrow
            {
                x = x_;
                y = y_;
            }
        }
        else static if (N == 3u)
        {
            this(X : T, Y : T, Z : T)(X x_, Y y_, Z z_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
            }

            this(X : T, Y : T)(SmallVector!(2, X) xy_, Y z_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
            }
        }
        else static if (N == 4u)
        {
            this(X : T, Y : T, Z : T, W : T)(X x_, Y y_, Z z_, W w_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
                w = w_;
            }

            this(X : T, Y : T)(SmallVector!(2, X) xy_, SmallVector!(2, Y)zwy_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = zw_.x;
                w = zw_.y;
            }

            this(X : T, Y : T, Z : T)(SmallVector!(2, X) xy_, Y z_, Z w_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
                w = w_;
            }

            this(X : T, Y : T)(SmallVector!(3, X) xyz_, Y w_) pure nothrow
            {
                x = xyz_.x;
                y = xyz_.y;
                z = zwz_.z;
                w = w_;
            }

            this(X : T, Y : T)(X x_, SmallVector!(3, X) yzw_) pure nothrow
            {
                x = x_;
                y = yzw_.x;
                z = yzw_.y;
                w = yzw_.z;
            }
        }

        this(U)(U u) pure nothrow
        {
            opAssign!U(u);
        }

        // assign with compatible type
        void opAssign(U)(U u) pure nothrow if (is(U: T))
        {
            v[] = u; // copy to each component
        }

        // assign with a static array type
        void opAssign(U)(U u) pure nothrow if ((isStaticArray!(U) && is(typeof(u[0]) : T) && (u.length == N)))
        {
            for (size_t i = 0; i < N; ++i)
            {
                v[i] = u[i];
            }
        }

        // assign with a dynamic array (check size)
        void opAssign(U)(U u) pure nothrow if (isDynamicArray!(U) && is(typeof(u[0]) : T))
        {
            assert(u.length == N);
            for (size_t i = 0; i < N; ++i)
            {
                v[i] = u[i];
            }
        }

        // same small vectors
        void opAssign(U)(U u) pure nothrow if (is(U : SmallVector))
        {
            static if (N <= 4u)
            {
                x = u.x;
                static if(N >= 2u) y = u.y;
                static if(N >= 3u) z = u.z;
                static if(N >= 4u) w = u.w;
            }
            else
            {
                for (size_t i = 0; i < N; ++i)
                {
                    v[i] = u.v[i];
                }
            }
        }

        // other small vectors (same size, compatible type)
        void opAssign(U)(U u) pure nothrow if (is(typeof(U._isSmallVector))
                                            && is(U._T : T)
                                             && (!is(U: SmallVector))
                                             && (U._N == _N))
        {
            for (size_t i = 0; i < N; ++i)
            {
                v[i] = u.v[i];
            }
        }

        bool opEquals(U)(U other) pure const nothrow
            if (is(U : SmallVector))
        {
            for (size_t i = 0; i < N; ++i)
            {
                if (v[i] != other.v[i])
                {
                    return false;
                }
            }
            return true;
        }

        bool opEquals(U)(U other) pure const nothrow
            if (isConvertible!U)
        {
            SmallVector conv = other;
            return opEquals(conv);
        }

        SmallVector opUnary(string op)() pure const nothrow
            if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            SmallVector res = void;
            for (size_t i = 0; i < N; ++i)
            {
                mixin("res.v[i] = " ~ op ~ "v[i];");
            }
            return res;
        }

        ref SmallVector opOpAssign(string op, U)(U operand) pure nothrow
            if (is(U : SmallVector))
        {
            for (size_t i = 0; i < N; ++i)
            {
                mixin("v[i] " ~ op ~ "= operand.v[i];");
            }
            return this;
        }

        ref SmallVector opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            SmallVector conv = operand;
            return opOpAssign!op(conv);
        }

        SmallVector opBinary(string op, U)(U operand) pure const nothrow
            if (is(U: SmallVector) || (isConvertible!U))
        {
            SmallVector temp = this;
            return temp.opOpAssign!op(operand);
        }

        SmallVector opBinaryRight(string op, U)(U operand) pure const nothrow if (isConvertible!U)
        {
            SmallVector temp = operand;
            return temp.opOpAssign!op(this);
        }

        ref T opIndex(size_t i) pure nothrow
        {
            return v[i];
        }

        ref const(T) opIndex(size_t i) pure const nothrow
        {
            return v[i];
        }

        /*
        T opIndex(size_t i) pure const nothrow
        {
            return v[i];
        }*/

        T opIndexAssign(U : T)(U u, size_t i) pure nothrow
        {
            return v[i] = u;
        }
    /+
        T opIndexOpAssign(string op, U)(size_t i, U x) if (is(U : T))
        {
            mixin("v[i] " ~ op ~ "= x;");
            return v[i];
        }

         T opIndexUnary(string op, U)(size_t i) if (op == "+" || op == "-" || op == "~")
        {
            mixin("return " ~ op ~ "v[i];");
        }

        ref T opIndexUnary(string op, U, I)(I i) if (op == "++" || op == "--")
        {
            mixin(op ~ "v[i];");
            return v[i];
        }
    +/

        // implement swizzling
        @property auto opDispatch(string op, U = void)() pure const nothrow
            if (isValidSwizzle!(op))
        {
            alias SmallVector!(op.length, T) returnType;
            returnType res = void;
            enum indexTuple = swizzleTuple!(op, op.length).result;
            foreach(i, index; indexTuple)
            {
                res.v[i] = v[index];
            }
            return res;
        }

        /+
        // Support swizzling assignment like in shader languages.
        // eg: eg: vec.yz = vec.zx;
        void opDispatch(string op, U)(U x) pure
            if ((op.length >= 2)
                && (isValidSwizzleUnique!op)                  // v.xyy will be rejected
                && is(typeof(SmallVector!(op.length, T)(x)))) // can be converted to a small vector of the right size
        {
            SmallVector!(op.length, T) conv = x;
            enum indexTuple = swizzleTuple!(op, op.length).result;
            foreach(i, index; indexTuple)
            {
                v[index] = conv[i];
            }
            return res;
        }
        +/

        // casting to small vectors of the same size
        U opCast(U)() pure const nothrow if (is(typeof(U._isSmallVector)) && (U._N == _N))
        {
            U res = void;
            for (size_t i = 0; i < N; ++i)
            {
                res.v[i] = cast(U._T)v[i];
            }
            return res;
        }

        // implement slices operator overloading
        // allows to go back to slice world
        size_t opDollar() pure const nothrow
        {
            return N;
        }

        // vec[]
        T[] opSlice() pure nothrow
        {
            return v[];
        }

        // vec[a..b]
        T[] opSlice(int a, int b) pure nothrow
        {
            return v[a..b];
        }

        // Squared length
        T squaredLength() pure const nothrow
        {
            T sumSquares = 0;
            for (size_t i = 0; i < N; ++i)
            {
                sumSquares += v[i] * v[i];
            }
            return sumSquares;
        }

        // Euclidean distance
        T squaredDistanceTo(SmallVector v) pure const nothrow
        {
            return (v - this).squaredLength();
        }

        static if (isFloatingPoint!T)
        {
            bool isIdentical(SmallVector w) const pure nothrow @safe
            {
                bool res = true;
                for (size_t i = 0; i < N; ++i)
                {
                    res = res && std.math.isIdentical(w[i], v[i]);
                }
                return res;
            }

            // Euclidean length
            T length() pure const nothrow
            {
                return sqrt(squaredLength());
            }

            // Euclidean distance
            T distanceTo(SmallVector v) pure const nothrow
            {
                return (v - this).length();
            }

            // normalization
            void normalize() pure nothrow
            {
                auto invLength = 1 / length();
                for (size_t i = 0; i < N; ++i)
                {
                    v[i] *= invLength;
                }
            }

            SmallVector normalized() pure const nothrow
            {
                SmallVector res = this;
                res.normalize();
                return res;
            }
        }

		string toString() const
		{
			string res;
			try
			{
				static if (N == 1)
					res =  format("Vec1(%s)", x);
				else static if (N == 2)
					res =  format("Vec2(%s,%s)", x, y);
				else static if (N == 3)
					res =  format("Vec3(%s,%s,%s)", x, y, z);
				else static if (N == 4)
					res =  format("Vec4(%s,%s,%s,%s)", x, y, z, w);
				else
					res =  text(v);
			}
			catch
			{
				res = "<invalid>";
			}
			return res;
		}

    }

    private
    {
        enum _isSmallVector = true; // do we really need this? I don't know.

        enum _N = N;
        alias T _T;

        // define types that can be converted to this, but are not the same type
        // TODO: don't use assignment...
        template isConvertible(T)
        {
            enum bool isConvertible = (!is(T : SmallVector))
            && is(typeof(
                {
                    T x;
                    SmallVector v = x;
                }()));
        }

        // define types that can't be converted to this
        template isForeign(T)
        {
            enum bool isForeign = (!isConvertible!T) && (!is(T: SmallVector));
        }

        template isValidSwizzle(string op)
        {
            static if (op.length == 0)
            {
                enum bool isValidSwizzle = false;
            }
            else
            {
                enum bool isValidSwizzle = isValidSwizzleImpl!(op, op.length).result;
            }
        }

        template searchElement(char c, string s)
        {
            static if (s.length == 0)
            {
                enum bool result = false;
            }
            else
            {
                enum string tail = s[1..s.length];
                enum bool result = (s[0] == c) || searchElement!(c, tail).result;
            }
        }

        template hasNoDuplicates(string s)
        {
            static if (s.length == 1)
            {
                enum bool result = true;
            }
            else
            {
                enum tail = s[1..s.length];
                enum bool result = !(searchElement!(s[0], tail).result) && hasNoDuplicates!(tail).result;
            }
        }

        template isValidSwizzleUnique(string op)
        {
            static if (isValidSwizzle!op)
            {
                enum isValidSwizzleUnique = hasNoDuplicates!op.result;
            }
            else
            {
                enum bool isValidSwizzleUnique = false;
            }
        }

        template isValidSwizzleImpl(string op, size_t opLength)
        {
            static if (opLength == 0)
            {
                enum bool result = true;
            }
            else
            {
                enum len = op.length;
                enum bool result = (swizzleIndex!(op[0]) != -1)
                                   && isValidSwizzleImpl!(op[1..len], opLength - 1).result;
            }
        }

        template swizzleIndex(char c)
        {
            static if(c == 'x' && N >= 1)
            {
                enum size_t swizzleIndex = 0u;
            }
            else static if(c == 'y' && N >= 2)
            {
                enum size_t swizzleIndex = 1u;
            }
            else static if(c == 'z' && N >= 3)
            {
                enum size_t swizzleIndex = 2u;
            }
            else static if (c == 'w' && N >= 4)
            {
                enum size_t swizzleIndex = 3u;
            }
            else
                enum size_t swizzleIndex = cast(size_t)(-1);
        }

        template swizzleTuple(string op, size_t opLength)
        {
            static assert(opLength > 0);
            enum c = op[0];
            static if (opLength == 1)
            {
                enum result = [swizzleIndex!c];
            }
            else
            {
                enum string rest = op[1..opLength];
                enum recurse = swizzleTuple!(rest, opLength - 1).result;
                enum result = [swizzleIndex!c] ~ recurse;
            }

        }
    }
}

private string definePostfixAliases(string type)
{
    return "alias " ~ type ~ "!byte "   ~ type ~ "b;\n"
         ~ "alias " ~ type ~ "!ubyte "  ~ type ~ "ub;\n"
         ~ "alias " ~ type ~ "!short "  ~ type ~ "s;\n"
         ~ "alias " ~ type ~ "!ushort " ~ type ~ "us;\n"
         ~ "alias " ~ type ~ "!int "    ~ type ~ "i;\n"
         ~ "alias " ~ type ~ "!uint "   ~ type ~ "ui;\n"
         ~ "alias " ~ type ~ "!long "   ~ type ~ "l;\n"
         ~ "alias " ~ type ~ "!ulong "  ~ type ~ "ul;\n"
         ~ "alias " ~ type ~ "!float "  ~ type ~ "f;\n"
         ~ "alias " ~ type ~ "!double " ~ type ~ "d;\n"
         ~ "alias " ~ type ~ "!real "   ~ type ~ "L;\n";
}

template vec2(T) { alias SmallVector!(2u, T) vec2; }
template vec3(T) { alias SmallVector!(3u, T) vec3; }
template vec4(T) { alias SmallVector!(4u, T) vec4; }

mixin(definePostfixAliases("vec2"));
mixin(definePostfixAliases("vec3"));
mixin(definePostfixAliases("vec4"));

// min and max

SmallVector!(N, T) min(size_t N, T)(const SmallVector!(N, T) a, const SmallVector!(N, T) b) pure nothrow
{
    SmallVector!(N, T) res = void;
    for(size_t i = 0; i < N; ++i)
        res[i] = std.algorithm.min(a[i], b[i]);
    return res;
}

SmallVector!(N, T) max(size_t N, T)(const SmallVector!(N, T) a, const SmallVector!(N, T) b) pure nothrow
{
    SmallVector!(N, T) res = void;
    for(size_t i = 0; i < N; ++i)
        res[i] = std.algorithm.max(a[i], b[i]);
    return res;
}

// dot product
T dot(size_t N, T)(const SmallVector!(N, T) a, const SmallVector!(N, T) b) pure nothrow
{
    T sum = 0;
    for(size_t i = 0; i < N; ++i)
    {
        sum += a[i] * b[i];
    }
    return sum;
}

// 3D cross product
SmallVector!(3u, T) cross(T)(const SmallVector!(3u, T) a, const SmallVector!(3u, T) b) pure nothrow
{
    return SmallVector!(3u, T)(a.y * b.z - b.z * a.y,
                               a.z * b.x - b.x * a.z,
                               a.x * b.y - b.y * a.x);
}

unittest
{
    static assert(vec2i.isValidSwizzle!"xyx");
    static assert(!vec2i.isValidSwizzle!"xyz");
    static assert(vec2i.isValidSwizzleUnique!"xy");
    static assert(vec2i.isValidSwizzleUnique!"yx");
    static assert(!vec2i.isValidSwizzleUnique!"xx");

    assert(vec2l(0, 1) == vec2i(0, 1));

    int[2] arr = [0, 1];
    int[] arr2 = new int[2];
    arr2[] = arr[];
    vec2i a = vec2i([0, 1]);
    vec2i a2 = vec2i(0, 1);
    immutable vec2i b = vec2i(0);
    assert(b[0] == 0 && b[1] == 0);
    vec2i c = arr;
    vec2l d = arr2;
    assert(a == a2);
    assert(a == c);
    assert(vec2l(a) == vec2l(a));
    assert(vec2l(a) == d);

    vec4i x = [4, 5, 6, 7];
    assert(x == x);
    --x[0];
    assert(x[0] == 3);
    ++x[0];
    assert(x[0] == 4);
    x[1] &= 1;
    x[2] = 77 + x[2];
    x[3] += 3;
    assert(x == [4, 1, 83, 10]);
    assert(x.xxywz == [4, 4, 1, 10, 83]);
    assert(x.xxxxxxx == [4, 4, 4, 4, 4, 4, 4]);
    assert(a != b);

    vec2l e = a;
    vec2l f = a + b;
    assert(f == vec2l(a));

    vec3ui g = vec3i(78,9,4);
    g ^= vec3i(78,9,4);
    assert(g == vec3ui(0));
    //g[0..2] = 1u;
    //assert(g == [2, 1, 0]);

    assert(vec2i(4, 5) + 1 == vec2i(5,6));
    assert(vec2i(4, 5) - 1 == vec2i(3,4));
    assert(1 + vec2i(4, 5) == vec2i(5,6));
    assert(vec3f(1,1,1) * 0 == 0);
    assert(1.0 * vec3d(4,5,6) == vec3f(4,5.0f,6.0));

    auto dx = vec2i(1,2);
    auto dy = vec2i(4,5);
    auto dp = dot(dx, dy);
    assert(dp == 14 );

    vec3i h = cast(vec3i)(vec3d(0.5, 1.1, -2.2));
    assert(h == [0, 1, -2]);
    assert(h[] == [0, 1, -2]);
    assert(h[1..3] == [1, -2]);
    assert(h.zyx == [-2, 1, 0]);
//    h.xy = vec2i(0, 1);
    assert(h.xy == [0, 1]);
    //assert(h == [-2, 1, 0]);
    //assert(!__traits(compiles, h.xx = h.yy));
    vec4ub j;
}

template Vec2(T) { alias SmallVector!(2u, T) Vec2; }
template Vec3(T) { alias SmallVector!(3u, T) Vec3; }

alias vec2f Vec2f;
alias vec2i Vec2i;
alias vec3f Vec3f;
alias vec4f Vec4f;

