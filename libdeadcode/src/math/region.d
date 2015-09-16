module math.region;

//import style; // : Style;
import alg = std.algorithm;
import std.container;
import std.exception;
import std.typecons;
import std.typetuple;

//import core.buffer;

import test;
mixin registerUnittests;

template Iota(size_t i, size_t n)
{
	static if (n == 0) { alias TypeTuple!() Iota; }
	else { alias TypeTuple!(i, Iota!(i + 1, n - 1)) Iota; }
}

/** A range of sequential characters in a text
 */
struct Region
{
	// Region [a:b[
	int a; /// first end of region. A is included.
	int b; /// last end of region. B is not included.
	int id; // ID that can be used by the user to associate this region with something

	static immutable Region zero = Region(0,0);
    static immutable Region invalid = Region(int.min, int.min);

    @property int begin() const pure nothrow @safe
    {
        return a < b ? a : b;
    }

    @property int end() const pure nothrow @safe
    {
        return a < b ? b : a;
    }

	@property bool empty() const pure nothrow @safe
	{
		return a == b;
	}

    @property bool valid() const pure nothrow @safe
    {
        return this != invalid;
    }

	unittest
	{
		Assert(Region.zero.empty);
		Assert(Region(5,5).empty);
		Assert(!Region(0,1).empty);
	}

	@property pure size_t length() const nothrow @safe
	{
		return b - a;
	}

	Region normalized() const pure nothrow @safe
	{
		if (a > b)
			return Region(b, a, id);
		else
			return this;
	}

	/// Clip this region using the clipper
	Region clip(Region clipper) const pure nothrow @safe
	{
		import std.algorithm : min, max;
		auto r = normalized();
		auto c = clipper.normalized();
		auto res = Region(max(a, c.a), min(b, c.b));
		if (res.a > res.b)
			return Region(a, a);
		else
			return res;
	}

	/// ditto
	Region clip(int clipA, int clipB) const pure nothrow @safe
	{
		return clip(Region(clipA, clipB));
	}

	/// Make the region into an empty region
	void clear() pure nothrow @safe
	{
		a = b;
	}

	/** Return a region that contains this region and the given region.
	 *
	 * Note that this is not a union of the regions because there may be
	 * space between the two regions and that space will be included by this
	 * cover method but not by a normal union. The .id of the result is that of this region.
	 */
	Region cover(Region r) const
	{
		if (r.empty) return cast(Region)this; // Bug: need to cast since it tries to return this which is const! even though it is a value type.
		if (empty)
		{
			Region res = r;
			res.id = id;
			return res;
		}
		return Region(alg.min(a,r.a), alg.max(b,r.b), id);
	}

	unittest {
		// Test touching regions
		Assert(Region(0,10).cover(Region(10,20)), Region(0,20));
		Assert(Region(10,20).cover(Region(0,10)), Region(0,20));
		// Test containing regions
		Assert(Region(0,20).cover(Region(5,10)), Region(0,20));
		// Test regions with space between
		Assert(Region(0,10).cover(Region(15,100)), Region(0,100));
	}

	/** Return return this region offset
	*/
	Region offset(int o)
	{
		return Region(a + o, b + o, id);
	}

	/** Return the intersection of the two regions
	 */
	Region intersect(Region r) const pure nothrow @safe
	{
		if (r.b <= a || r.a >= b || r.empty || empty)
			return Region(a, a, id); // an empty region with start at this.a
		return Region(r.a > a ? r.a : a, r.b < b ? r.b : b, r.id);
	}

	/** Return the part before intersection as idx 0, the intersection itself as idx 1 and the part after as idx 2.
		In case of no intersection the before part contains this region and at and after are empty regions.
		The before and after part can only be part of this region and not r ie. the sum of before,at,after will
		always be the same as this.
	*/
	auto intersect3(Region r) const pure nothrow @safe
	{
		struct IntersectResult
		{
			Region before;
			Region at;
			Region after;

			@property int max() const pure nothrow
			{
				return before.b > at.b ? (before.b > after.b ? before.b : after.b) : (at.b > after.b ? at.b : after.b);
			}

			@property size_t length() const pure nothrow
			{
				return (before.empty ? 0 : 1) + (at.empty ? 0 : 1) + (after.empty ? 0 : 1);
			}

			@property bool empty() const pure nothrow
			{
				return before.empty && at.empty && after.empty;
			}

			@property Region front() const
			{
				return before.empty ? (at.empty ? after : at) : before;
			}

			void popFront() pure nothrow
			{
				if (!before.empty)
					before.a = before.b;
				else if (!at.empty)
					at.a = at.b;
				else
					after.a = after.b;
			}
		}

		Region r1 = intersect(r);
		if (r1.empty)
			return IntersectResult(this, zero, zero);
		Region r0 = Region(a, r1.a, id);
		Region r2 = Region(r1.b, b, id);
		return IntersectResult(r0, r1, r2);
	}

	unittest
    {
		// Test touching regions
		Assert(Region(0,10).intersect(Region(10,20)).empty);
		Assert(Region(10,20).intersect(Region(0,10)).empty);
		// Test containing regions
		Assert(Region(0,20).intersect(Region(5,10)), Region(5,10));
		// Test regions with space between
		Assert(Region(0,10).intersect(Region(15,100)).empty);
	}

	/** Returns true if the given region intersects with this region
	 */
	bool intersects(Region r) const
	{
		return !intersect(r).empty;
	}

	/** Returns true if the given region is contained within this region
	 */
	bool contains(Region r) const
	{
		return r.a >= a && r.b <= b && !r.empty && !empty;
	}

	unittest {
		// Test touching regions
		Assert(!Region(0,10).contains(Region(10,20)));
		Assert(!Region(10,20).contains(Region(0,10)));
		// Test containing regions
		Assert(Region(0,20).contains(Region(5,10)));
		Assert(Region(5,10).contains(Region(5,10)));
		// Test regions with space between
		Assert(!Region(0,10).contains(Region(15,100)));
	}

	/** Returns true if the given index is contained within this region
	 */
	bool contains(int p) const
	{
		return p >= a && p < b && !empty;
	}

	unittest
	{
		Assert(!Region.zero.contains(0));
		Assert(Region(0,1).contains(0));
		Assert(!Region(0,1).contains(1));
		Assert(!Region(0,1).contains(2));
	}

	/** Update all affected regions by shifting their endpoints or expanding because of new
	    entries are inserted on what the regions describe

		Params:
			pos = position to remove from
			len = number of entries to remove forward from pos

		Returns: True if this regions was modified
	*/
	bool entriesInserted(int pos, int len)
	{
		// To simplify logic we swap a and b if a > b
		bool swapIt = a > b;

		bool modified = false;
		if (a >= pos)
		{
			// All regions strictly after the text inserted
			// TODO: when array ref bug is fixed then do it proper
			if (swapIt)
			{
				auto tmp = a;
				a = b;
				b = tmp;
			}
			a += len;
			b += len;
			modified = true;
		}
		else if (b >= pos)
		{
			// Text is inserted in the middle of this region
			if (swapIt)
			{
				auto tmp = a;
				a = b;
				b = tmp;
			}
			b += len;
			modified = true;
		}

		if (modified && swapIt)
		{
			auto tmp = a;
			a = b;
			b = tmp;
		}

		return modified;
	}

	/** Update all affected regions by shifting their endpoints or expanding because of
	    entries are removed on what the regions describe

		Params:
			pos = position to remove from
			len = number of entries to remove forward from pos

		Returns: True if this regions was modified
	*/
	bool entriesRemoved(int pos, int len)
	{
		// To simplify logic we swap a and b if a > b
		bool swapIt = a > b;

		bool modified = false;
		if (a >= (pos+len))
		{
			// All regions strictly after the text inserted
			// TODO: when array ref bug is fixed then do it proper
			if (swapIt)
			{
				auto tmp = a;
				a = b;
				b = tmp;
			}
			a -= len;
			b -= len;
			modified = true;
		}
		else if (b >= (pos+len))
		{
			// Text is deleted in the middle of this region with b outside
			if (swapIt)
			{
				auto tmp = a;
				a = b;
				b = tmp;
			}
			a = a > pos ? pos : a;
			b -= len;
			modified = true;
		}
		else if (b >= pos)
		{
			// Text is deleted in the middle of this region with b inside
			if (swapIt)
			{
				auto tmp = a;
				a = b;
				b = tmp;
			}
			a = a > pos ? pos : a;
			b = pos;
			modified = true;
		}
		if (modified && swapIt)
		{
			auto tmp = a;
			a = b;
			b = tmp;
		}
		return modified;
	}

	string toString() const pure nothrow
	{
		import std.conv;
		try
			return text("Region(", a, ",", b, ",", id, ")");
		catch (Exception e)
			return "Region(invalid)";
	}


	/** Returns two regions in a struct called before, after where zero, one or both may be empty.
	    returns this - r;
		If regions are not overlapping
	*/
	auto subtract(Region r)
	{
		// Legend:
		// - this region
		// | r region
		// + overlap of this and r regions


		// case 1: -----||||| or |||||----- or r.empty
		if (this.b <= r.a || this.a >= r.b || r.empty)
			return tuple(this, Region(0,0)); // not overlapping

		if (this.b <= r.b)
		{
			if (this.a <= r.a)
			{
				// case 2: ----+++++||||||
				return tuple(Region(this.a, r.a), Region(0,0));
			}
			else
			{
				// case 3: ||||+++++|||||
				return tuple(Region(this.a, this.a), Region(0,0));
			}
		}
		else
		{
			if (this.a < r.a)
			{
				// case 4: ----++++++-----
				return tuple(Region(this.a, r.a), Region(r.b, this.b));
			}
			else
			{
				// case 5: ||||+++++-----
				return tuple(Region(r.b, this.b), Region(0,0));
			}
		}
	}

	///ditto
	auto subtract(int ra, int rb)
	{
		return subtract(Region(ra, rb));
	}

	unittest
	{
		// case 1
		auto r = Region(0,10).subtract(10,20);
		Assert(r[0], Region(0,10), "Subtract case 1");
		Assert(r[1].empty);

		r = Region(10,20).subtract(0,10);
		Assert(r[0], Region(10,20));
		Assert(r[1].empty);

		// case 2
		r = Region(10,20).subtract(15,25);
		Assert(r[0], Region(10,15), "Subtract case 2");
		Assert(r[1].empty);

		// case 3
		r = Region(10,20).subtract(0,30);
		Assert(r[0].empty, "Subtract case 3");
		Assert(r[1].empty);

		// case 4
		r = Region(0,30).subtract(10,20);
		Assert(r[0], Region(0,10), "Subtract case 4");
		Assert(r[1], Region(20,30));

		// case 5
		r = Region(15,25).subtract(10,20);
		Assert(r[0], Region(20,25), "Subtract case 5");
		Assert(r[1].empty);
	}

	/+
	/** Returns two regions in a struct called before, after where zero, one or both may be empty */
	auto subtract(Region r)
	{
		auto i = intersect3(r);
		struct Result
		{
			Region before;
			Region after;
		}
		Result result;

		if (i.at.empty)
		{
			// no intersection
			result.before = this;
		}
		else if (i.before.empty)
		{
			if (i.after.empty)
				result.before = Region(0,0); // All intersects
			else
				result.after = i.after;
		}

		if (i.empty)
		{
			result.after = this;
			return result;
		}

		// ? - ? --- ? -- ?

		if (r.a < a )
		{
			// r.a - a --- ? -- ?
			if (r.b < a)
			{
				// r.a - r.b --- a -- b
				result.after = this;
			}
			else if (r.b < b)
			{
				// r.a - a --- r.b -- b
				result.after = Region(r.b, b);
			}
			else
			{
				// r.a - a --- b -- r.b
				// empty result
			}
		}
		else
		{
			// a - r.a --- ? -- ?
			if (r.a >= b)
			{
				result.before = this;
				// no in
			}
			else
			{

			}
		}
	}
+/
}

/** A set of regions
 *
 * The regions are not overlapping and adding a region that
 * overlaps existing regions in the set will merge them into one.
 *
 * TODO: Make merge an optional feature
 * TODO: Make operations lazy by returning a Range instead of a new RegionSet
 */
class RegionSet
{
	alias Array!Region Container;
	alias Container.Range Range;
	Container regions;
	// alias regions this;

	bool _mergeIntersectingRegions = true;

	@property
	{
		int a()
		{
			if (regions.empty)
				return 0;
			return regions.front.a;
		}

		int b()
		{
			if (regions.empty)
				return 0;
			return regions.back.b;
		}

        bool empty() const pure nothrow @safe
        {
            return regions.empty;
        }

        size_t length() const pure nothrow @safe
        {
            return regions.length;
        }

        int lastIndex()
        {
            return b;
        }

        ref Region front() pure @safe
        {
            return regions.front;
        }
	}

    void opOpAssign(string op = "~")(Region r)
    {
        regions ~= r;
    }

    void clear()
    {
        regions.clear();
    }

    ref Region opIndex(size_t n) pure @safe
    {
        return regions.opIndex(n);
    }

    size_t insertBack(Region r)
    {
        return regions.insertBack(r);
    }

	this(bool mergeIntersectingRegions = true)
	{
		_mergeIntersectingRegions = mergeIntersectingRegions;
		assert(mergeIntersectingRegions);
	}

	// this(Args...)(Args args) if (is(args[0] : int) && (args.length % 2 == 0) )
    import std.traits;

    this(Args...)(Args args) if (args.length != 0 && isImplicitlyConvertible!(typeof(args[0]), int) && (args.length % 2 == 0) )
	{
		enum len = args.length;
        foreach (i; Iota!(0, len/2))
        {
            set(Region(args[i*2], args[i*2+1]));
        }
	}

	// Update all affected regions by shifting their endpoints or expanding because of new
	// entries are inserted on what the regions describe
	void entriesInserted(int pos, int len)
	{
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			if (cur.entriesInserted(pos, len))
				regions[i] = cur;
/+
			if (cur.a >= pos)
			{
				// All regions strictly after the text inserted
				// TODO: when array ref bug is fixed then do it proper
				cur.a += len;
				cur.b += len;
				regions[i] = cur;
			}
			else if (cur.b >= pos)
			{
				// Text is inserted in the middle of this region
				cur.b += len;
				regions[i] = cur;
			}
			+/
		}
	}

	// Update all affected regions by shifting their endpoints or contracting because of
	// entries are removed on what the regions describe
	void entriesRemoved(int pos, int len)
	{
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			if (cur.entriesRemoved(pos, len))
				regions[i] = cur;
		}
	}

	/*
	// Update all affected regions by shifting their endpoints or contracting because of
	// entries are removed on what the regions describe
	void entriesRemoved(int pos, int len)
	{
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			if (cur.a >= pos)
			{
				// All regions strictly after the text inserted
				// TODO: when array ref bug is fixed then do it proper
				cur.a -= len;
				cur.b -= len;
				regions[i] = cur;
			}
			else if (cur.b >= pos)
			{
				// Text is inserted in the middle of this region
				int posToEndDiff = cur.b - pos;
				cur.b -= posToEndDif < len ? posToEndDiff : len;
				regions[i] = cur;
			}
		}
	}
*/
	void merge(int a, int b, int id = 0)
	{
		merge(Region(a, b, id));
	}

	void addxxx(Region r)
	{
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			if (cur.a < r.a)
			{
				// TODO: regions.insertAfter is broken
				// regions.insertAfter(regions[0..i], r);
				if ((i+1) != regions.length)
				{
					regions.insertBefore(regions[i+1..regions.length], r);
					return;
				}
				break; // insert as last element
			}
		}
		regions.insertBack(r); // no elements already or incoming region is to be the last element
	}

	void set(int a, int b, int id = 0)
	{
		set(Region(a, b, id));
	}

	void set(Region r)
	{
		if (r.empty) return;
		if (regions.empty)
		{
			regions.insertBack(r);
			return;
		}

		size_t len = regions.length;
		size_t i = 0;
		while (i < len)
		{
			auto cur = regions[i];
			if (r.b <= cur.a)
			{
				if (!r.empty)
					regions.insertBefore(regions[i..i+1], r);
				return; // done
			}

			// Maybe part of r is not intersecting and before the cur region
			if (r.a < cur.a)
			{
				regions.insertBefore(regions[i..i+1], Region(r.a, cur.a, r.id));
				++i;
			}

			auto isect = cur.intersect3(r);
			if (isect.at.empty)
			{
				++i;
				continue;
			}


			size_t incr = isect.length;

			// TODO: shouldn't need to call foreach since replace accepts a range but
			//       must have bug since it does not compile
			regions.replace(regions[i..i+1], isect);

			i += incr;

			//foreach (newr; isect)
			//{
			//    if (i == len)
			//    {
			//        regions.insertBack(newr);
			//        len++;
			//    }
			//    else
			//    {
			//        regions.insertA
			//        regions.replace(regions[i..i+1], newr);
			//    }
			//    i++;
			//}
			r.a = isect.max;
			if (r.a > r.b)
				return;
		}
		regions.insertBack(r);
	}

	void merge(Region r, bool adjecentIdMismatchIsSeparate = true)
	{
		if (r.empty) return;

		int mergeStartIdx = -1;

		// Unify this region with all the regions that it
		// intersects
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			bool intersects = cur.intersects(r);
			// bool doMerge = intersects || ( cur.id == r.id && (cur.a == r.b || cur.b == r.a) );
			bool doMerge = intersects || ( (!adjecentIdMismatchIsSeparate || cur.id == r.id) && (cur.a == r.b || cur.b == r.a) );

			if (doMerge)
			{
				// Merge current region and r
				r = cur.cover(r); // ok to use covert because regions intersects or are touching
				if (mergeStartIdx == -1)
                                    mergeStartIdx = cast(int)i; // remember the first merged index into regions
				// Continue to see if any of the next regions is to be merged
			}
			else if (mergeStartIdx != -1)
			{
				// The region has been merged with regions before current one and
				// does not intersect with current one. This means we're done and just need
				// to replace the merged region with the regions that it is overlapping.
				regions.replace(regions[mergeStartIdx..i], r);
				return;
			}
			else if (r.b < cur.a)
			{
				// No intersection and nothing merged so far but the current region is after
				// r ie. we need to insert r before current region.
				regions.insertBefore(regions[i..regions.length], r);
				return;
			}
			// keep looking for a spot to insert r.

		}

		// We've reached the last element in region
		if (mergeStartIdx == -1)
		{
			// Nothing merged so just push back
			regions.insertBack(r);
		}
		else
		{
			// Something to merge until the very end
			regions.replace(regions[mergeStartIdx..regions.length], r); // replace merged
		}
	}

	unittest
	{
		RegionSet s1 = new RegionSet;
		Assert(s1.empty);
		s1.merge(Region(0,10));
		Assert(s1.length, 1);
		s1.merge(Region(20,30));
		Assert(s1.length, 2);
		s1.merge(Region(20,30));
		Assert(s1.length, 2);

		s1.merge(Region(15,35));
		Assert(s1.length, 2);
		s1.merge(Region(22,25));
		Assert(s1.length, 2);
		s1.merge(Region(11,14));
		Assert(s1.length, 3);
		Assert(s1[0], Region(0,10));
		Assert(s1[1], Region(11,14));
		Assert(s1[2], Region(15,35));
		s1.merge(Region(10,14));
		Assert(s1.length, 2);
		Assert(s1[0], Region(0,14));
		Assert(s1[1], Region(15,35));
		s1.merge(Region(10,15));
		Assert(s1.length, 1);
		Assert(s1.front, Region(0,35));

		auto s2 = new RegionSet;
		s2.merge(10, 20);
		s2.merge(3, 7);
		Assert(s2.length, 2);
		Assert(s2[0], Region(3,7));
		Assert(s2[1], Region(10,20));
	}
/*
	void toggle(int a, int b, int id = 0)
	{
		toggle(Region(a, b, id));
	}

	void toggle(Region r)
	{
		if (r.empty) return;

		int mergeStartIdx = -1;

		// Unify this region with all the regions that it
		// intersects
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			auto intersection = cur.intersect(r);

			if (!intersection.empty)
			{
				//
				r = cur.cover(r);
				if (mergeStartIdx == -1)
					mergeStartIdx = i; // remember the first merged index into regions

				// Continue to see if any of the next regions is to be merged
			}
			else if (mergeStartIdx != -1)
			{
				// The region has been merged with regions before current one and
				// does not intersect with current one. This means we're done and just need
				// to replace the merged region with the regions that it is overlapping.
				regions.replace(regions[mergeStartIdx..i], r);
				return;
			}
			else if (r.b < cur.a)
			{
				// No intersection and nothing merged so far but the current region is after
				// r ie. we need to insert r before current region.
				regions.insertBefore(regions[i..regions.length], r);
				return;
			}
			// keep looking for a spot to insert r.

		}

		// We've reached the last element in region
		if (mergeStartIdx == -1)
		{
			// Nothing merged so just push back
			regions.insertBack(r);
		}
		else
		{
			// Something to merge until the very end
			regions.replace(regions[mergeStartIdx..regions.length], r); // replace merged
		}
	}
*/
	void addx(Region r)
	{
		int mergeStartIdx = -1;

		// TODO: Make this into a alias pred as template param
		bool mergeAllowCmp(Region ra, Region rb) { return true; }

		// Unify this region with all the regions that it
		// intersects
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			bool intersects = cur.intersects(r);
			bool mergeAllowed = mergeAllowCmp(cur, r);
			bool mergeCandidate = intersects || ( (cur.a == r.b || cur.b == r.a) && mergeAllowed);

			if (mergeCandidate)
			{
				enforceEx!Exception(mergeAllowed, "Cannot add overlapping and unmergable regions");

				// Merge current region and r
				r = r.cover(regions[i]);
				if (mergeStartIdx == -1)
                                    mergeStartIdx = cast(int)i;
				// Continue to see if any of the next regions is to be merged
				continue;
			}
			else
			{
				// Current regions and r are not ovelapping
				if (r.b <= cur.a) // <= yes
				{
				 	// The current region is after r ie. we can end the add
					if (mergeStartIdx == -1)
						regions.insertBefore(regions[0..1], r);   // push front
					else
						regions.replace(regions[mergeStartIdx..i], r); // replace merged
					return;
				}
				else
				{
					// The current region is before r and not intersecting. Continue until
					// current region is after r.
					continue;
				}
			}
		}
			if (mergeStartIdx == -1)
			{
				regions.insertBack(r);
			}
			else
			{
				regions.replace(regions[mergeStartIdx..regions.length], r); // replace merged
			}
			return;
			/**
			// If they insersects and merging is allowed
			if (intersects)
			{
				enforceEx!Exception(mergeAllowCmp(cur, r), "Cannot add overlapping and unmergable regions");

				if (startIdx == -1)
					startIdx = i;

				r = r.cover(regions[i]);
			}
 			// Next to each other and merging possible
			else if ( (cur.a == r.b || cur.b == r.a) && mergeAllowCmp(cur, r))
			{
				if (startIdx == -1)
					startIdx = i;

				r = r.cover(regions[i]);
			}
			else if (startIdx != -1)
			{
				regions.replace(regions[startIdx..i], r);
				return;
			}
			else if (cur.b < r.a)
			{
				// TODO: regions.insertAfter is broken
				// regions.insertAfter(regions[0..i], r);
				if ((i+1) == regions.length)
				{
					regions.insertBack(r);
				}
				else if (regions[i+1].a > r.b)
				{
					regions.insertBefore(regions[i+1..regions.length], r);
				}
				else
				{
					// At this point the incoming region r is intersecting with the
					// next region.
				}
				return;
				continue;
			} else if (cur.a > r.b)
			{
				regions.insertBefore(regions[0..1], r);
				return;
			}
		}

		enforceEx!Exception(startIdx == -1 && regions.empty, "Trying to add first element to a non empty region");

		regions.insertBack(r);

			 */
	}

	void merge(RegionSet s)
	{
		foreach (r; s)
			merge(r);
	}

	unittest
	{
		auto s1 = new RegionSet;
		auto s2 = new RegionSet;
		s1.merge(Region(0,10));
		s1.merge(Region(20,30));
		s1.merge(Region(40,50));
		s2.merge(s1);
		Assert(s2.length, 3);
		Assert(s2[0], Region(0,10));
		Assert(s2[1], Region(20,30));
		Assert(s2[2], Region(40,50));
	}

	void subtract(Region r)
	{
		int startIdx = -1;
		int endIdx = -1;
		for (int i = 0; i < regions.length; ++i)
		{
			auto cur = regions[i];
			if (cur.b <= r.a)
				continue; // Region is before r

			if (cur.a >= r.b)
				break; // done

			auto subr = cur.subtract(r);

			if (subr[0].empty)
			{
				if (startIdx == -1)
					startIdx = i;
				endIdx = i;
			}
			else
			{
				regions[i] = subr[0];
				if (!subr[1].empty)
				{
					assert(startIdx == -1);
					regions.insertBefore(regions[i+1..regions.length], subr[1]);
				}
			}
		}

		if (startIdx != -1)
			regions.linearRemove(regions[startIdx..endIdx+1]);
	}

	void subtract(int ra, int rb)
	{
		subtract(Region(ra, rb));
	}

	unittest
	{
		RegionSet getSet()
		{
			auto s1 = new RegionSet;
			s1.set(5, 10);
			s1.set(20, 30);
			s1.set(40, 50);
			return s1;
		}

		auto rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(0,5);
		Assert(rs, new RegionSet(5, 10, 20, 30, 40, 50), "Subtract: Region before set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(50,60);
		Assert(rs, new RegionSet(5, 10, 20, 30, 40, 50), "Subtract: Region after set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(20,30);
		Assert(rs, new RegionSet(5, 10, 40, 50), "Subtract: One center region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(15,35);
		Assert(rs, new RegionSet(5, 10, 40, 50), "Subtract: One center region in set (surround)");

		rs = new RegionSet(5, 10, 20, 30, 32, 35, 40 ,50);
		rs.subtract(10,40);
		Assert(rs, new RegionSet(5, 10, 40, 50), "Subtract: Two center regions in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(2, 7);
		Assert(rs, new RegionSet(7, 10, 20, 30, 40, 50), "Subtract: First part of first region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(7, 15);
		Assert(rs, new RegionSet(5, 7, 20, 30, 40, 50), "Subtract: Last part of first region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(30, 45);
		Assert(rs, new RegionSet(5, 10, 20, 30, 45, 50), "Subtract: First part of last region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(25, 45);
		Assert(rs, new RegionSet(5, 10, 20, 25, 45, 50), "Subtract: First part of last region and last part of center region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(45, 55);
		Assert(rs, new RegionSet(5, 10, 20, 30, 40, 45), "Subtract: Last part of last region in set");

		rs = new RegionSet(5, 10, 20, 30, 40, 50);
		rs.subtract(22, 25);
		Assert(rs, new RegionSet(5, 10, 20, 22, 25, 30, 40, 50), "Subtract: Center part of center region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(22, 22);
		Assert(rs, new RegionSet(5, 10, 20, 30, 40, 50), "Subtract: Empty part of center region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(12, 17);
		Assert(rs, new RegionSet(5, 10, 20, 30, 40, 50), "Subtract: Part between first and center region in set");

		rs = new RegionSet(5, 10, 20, 30, 40 ,50);
		rs.subtract(0, 50);
		Assert(rs, new RegionSet(), "Subtract: All regions in set");
	}

	override bool opEquals(Object o) const nothrow
	{
		auto other = cast(RegionSet) o;
		return regions == other.regions;
	}

	bool contains(Region r)
	{
		for (int i = 0; i < regions.length; ++i)
		{
			auto re = regions[i];
			if (r.b <= re.a) break;
			if (r.intersects(re)) return true;
		}
		return false;
	}

	// TODO fix
	RegionSet getInverse()
	{
		RegionSet rs = new RegionSet();
		int lastEnd = 0;
		foreach (r; regions[])
		{
			if (lastEnd == r.a)
				continue;

			// TODO fix
			//rs.insertBack(lastEnd, r.a);
			lastEnd = r.b;
		}

		auto last = regions.back;
		if (last.b != 0xffffffff)
			rs.insertBack(Region(last.b, 0xffffffff));
		return rs;
	}

	// TODO fix
    //RegionSet intersect(Region r)
    //{
    //    auto rs = new RegionSet();
    //
    //    int first = -1;
    //    foreach (i; 0..regions.length)
    //    {
    //        auto cur = regions[i];
    //        if (r.b <= cur.a) break;
    //        bool ins = r.intersects(cur);
    //        if (ins)
    //        {
    //            first = i;
    //            rs.merge(cur);
    //        } else if (first != -1)
    //        {
    //            break;
    //        }
    //    }
    //    return rs;
    //}


    auto opSlice()
    {
        static struct Slice
        {
            private int curIndex;
            private RegionSet rs;

            // The intersect() method of this slice need to be able the mutate the front so we store it here
            private Region curFront;

            this(RegionSet rs)
            {
                this.rs = rs;
                curIndex = 0;

                if (rs.regions.length)
                {
                    curFront = rs.regions[0];
                    curIndex++;
                }
                else
                {
                    curFront = Region.invalid;
                }
            }

            @property Region front() @safe const pure nothrow
            {
                return curFront;
            }

            @property bool empty() @safe const pure nothrow
            {
                return !curFront.valid;
            }

            void popFront() @safe /*pure*/ nothrow
            {
                if (rs.regions.length <= curIndex)
                {
                    curFront = Region.invalid;
                }
                else
                {
                    curFront = rs.regions[curIndex];

                    curIndex++;
                }
            }

            auto intersect(Region r)
            {
                static struct Intersections
                {
                    private
                    {
                        Slice* slice;
                        Region reg;
                        Region currentFront;
                    }

                    this(Slice* sl, Region r)
                    {
                        slice = sl;
                        reg = r;
                        currentFront = Region.invalid;

                        // Skip anything before intersection region
                        while (!slice.empty && slice.front.b <= reg.a)
                        {
                            slice.popFront();
                        }

                        if (!slice.empty)
                            popFront();
                    }

                    @property Region front()
                    {
                        return currentFront;
                    }

                    @property bool empty()
                    {
                        return !currentFront.valid;
                    }

                    void popFront() nothrow @safe
                    {
                        auto i = slice.front.intersect3(reg);
                        if (i.at.empty)
                        {
                            currentFront = Region.invalid;
                            // end of intersections and this.empty should return true now
                        }
                        else
                        {
                            currentFront = i.at;
                            if (i.after.empty)
                                slice.popFront();
                            else
                                slice.curFront = i.after;
                        }
                    }
                }
                return Intersections(&this, r);
            }
        }
        return Slice(this);
    }

    unittest
    {
		auto rs = new RegionSet(5, 10, 20, 30, 40 ,50);

        // Do not use AssertRangesEqual when testing range construction but do it manually
        int    idx = 0;
        foreach (r; rs)
        {
            Assert(r, rs[idx++], "RegionSet.opSlice");
        }

        // Ok Slicing works if the above is ok, so now we can use that for the rest of the tests.

        // TODO: I think a bug in dmd makes this not work and we need the first on the stack
        //AssertRangesEqual(rs[].intersect(Region(0,50)), rq2, "RegionSet.opSlice.intersect with full overlap");
        auto rr = rs[].intersect(Region(0,50));
        AssertRangesEqual(rr, rs[], "RegionSet.opSlice.intersect with full overlap");

        import std.range;

        rr = rs[].intersect(Region(0,35));
        AssertRangesEqual(rr, rs[].take(2), "RegionSet.opSlice.intersect with non-clipping prefix");

        rr = rs[].intersect(Region(0,25));
        AssertRangesEqual(rr, new RegionSet(5, 10, 20, 25)[], "RegionSet.opSlice.intersect with clipping prefix");

        rr = rs[].intersect(Region(15,100));
        AssertRangesEqual(rr, rs[].dropOne(), "RegionSet.opSlice.intersect with non-clipping postfix");

        rr = rs[].intersect(Region(22,100));
        AssertRangesEqual(rr, new RegionSet(22, 30, 40, 50)[], "RegionSet.opSlice.intersect with clipping postfix");

        rr = rs[].intersect(Region(15,33));
        AssertRangesEqual(rr, rs[].dropOne().take(1), "RegionSet.opSlice.intersect with non-clipping center");

        rr = rs[].intersect(Region(23,27));
        AssertRangesEqual(rr, new RegionSet(23, 27)[], "RegionSet.opSlice.intersect with clipping center");

        rr = rs[].intersect(Region(12,12));
        AssertRangesEqual(rr, new RegionSet()[], "RegionSet.opSlice.intersect with empty region");

        auto sl1 = rs[];
        rr = sl1.intersect(Region(7,22));
        AssertRangesEqual(rr, new RegionSet(7, 10, 20, 22)[], "RegionSet.opSlice.intersect first intersection with slice");
        rr = sl1.intersect(Region(23,42));
        AssertRangesEqual(rr, new RegionSet(23, 30, 40, 42)[], "RegionSet.opSlice.intersect second intersection with slice");

        //AssertRangesEqual(rr, new RegionSet(5, 10, 20, 25)[], "RegionSet.opSlice.intersect with no-clipping postfix");

        //Assert(rs, new RegionSet(5, 10, 20, 30, 40, 50), "Subtract: Region before set");

    }

	override string toString()
	{
		string res;
		res ~= "RegionSet[";
        foreach (r; regions[])
		{
			res ~= r.toString();
		}
		return res ~ "]";
	}
}

//unittest {
//    printStats(true);
//}
