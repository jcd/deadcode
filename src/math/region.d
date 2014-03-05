module math.region;

//import style; // : Style;
import alg = std.algorithm;
import std.container;
import std.exception;
import std.typecons;

import core.buffer;

version(unittest) import test;


/** A range of sequential characters in a text
 */
struct Region
{
	// Region [a:b[
	uint a; /// first end of region. A is included.
	uint b; /// last end of region. B is not included.
	int id; // ID that can be used by the user to associate this region with something
	
	static immutable Region zero = Region(0,0);
		
	@property bool empty() const
	{ 
		return a == b; 
	}

	@property pure size_t length() const nothrow
	{
		return b - a;
	}

	unittest 
	{
		Assert(Region.zero.empty);
		Assert(Region(5,5).empty);
		Assert(!Region(0,1).empty);
	}
		
	/** Return a region that contains this region and the given region. 
	 * 
	 * Note that this is not a union of the regions because there may be
	 * space between the two regions and that space will be included by this
	 * cover method but not by a normal union.
	 */
	Region cover(Region r) const
	{
		if (r.empty) return cast(Region)this; // Bug: need to cast since it tries to return this which is const! even though it is a value type.
		if (empty) return r;
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
	Region intersect(Region r) const
	{ 
		if (r.b <= a || r.a >= b || r.empty || empty) 
			return Region(a, a, id); // an empty region with start at this.a
		return Region(r.a > a ? r.a : a, r.b < b ? r.b : b, id);
	}

	/** Return the part before intersection as idx 0, the intersection itself as idx 1 and the part after as idx 2.
		In case of no intersection the before part contains this region and at and after are empty regions.
	*/
	Tuple!(Region, "before", Region, "at", Region, "after") intersect3(Region r) const
	{
		Region r1 = intersect(r);
		if (r1.empty)
			return Tuple!(Region, "before", Region, "at", Region, "after")(this, zero, zero);
		Region r0 = Region(a, r1.a);
		Region r2 = Region(r1.b, b);
		return Tuple!(Region, "before", Region, "at", Region, "after")(r0, r1, r2);
	}
	
	unittest {
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
	bool contains(uint p) const
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
	bool entriesInserted(uint pos, uint len)
	{
		bool modified = false;
		if (a >= pos)
		{
			// All regions strictly after the text inserted
			// TODO: when array ref bug is fixed then do it proper
			a += len;
			b += len;
			modified = true;
		} 
		else if (b >= pos)
		{
			// Text is inserted in the middle of this region
			b += len;
			modified = true;
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
	bool entriesRemoved(uint pos, uint len)
	{
		bool modified = false;
		if (a >= (pos+len))
		{
			// All regions strictly after the text inserted
			// TODO: when array ref bug is fixed then do it proper
			a -= len;
			b -= len;
			modified = true;
		} 
		else if (b >= (pos+len))
		{
			// Text is deleted in the middle of this region with b outside
			a = a > pos ? pos : a;
			b -= len;
			modified = true;
		}
		else if (b >= pos)
		{
			// Text is deleted in the middle of this region with b inside
			a = a > pos ? pos : a;
			b = pos;
			modified = true;
		}
		return modified;
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
	alias regions this;

	bool _mergeIntersectingRegions = true;

	@property 
	{
		uint a() 
		{
			if (regions.empty)
				return 0;
			return regions.front.a;
		}

		uint b() 
		{
			if (regions.empty)
				return 0;
			return regions.back.b;
		}
	}

	this(bool mergeIntersectingRegions = true)
	{
		_mergeIntersectingRegions = mergeIntersectingRegions;
		assert(mergeIntersectingRegions);
	}

	// Update all affected regions by shifting their endpoints or expanding because of new 
	// entries are inserted on what the regions describe
	void entriesInserted(uint pos, uint len)
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
	void entriesRemoved(uint pos, uint len)
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
	void entriesRemoved(uint pos, uint len)
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
	void add(uint a, uint b, int id = 0)
	{
		add(Region(a, b, id));
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
	
	void add(Region r)
	{ 
		if (r.empty) return;
		
		int mergeStartIdx = -1;
		
		// Unify this region with all the regions that it
		// intersects
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			bool intersects = cur.intersects(r);
			bool doMerge = intersects || (cur.id == r.id && (cur.a == r.b || cur.b == r.a));

			if (doMerge)
			{									
				// Merge current region and r
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

	unittest
	{
		RegionSet s1 = new RegionSet;
		Assert(s1.empty);
		s1.add(Region(0,10));
		Assert(s1.length, 1);
		s1.add(Region(20,30));
		Assert(s1.length, 2);
		s1.add(Region(20,30));
		Assert(s1.length, 2);

		s1.add(Region(15,35));
		Assert(s1.length, 2);
		s1.add(Region(22,25));
		Assert(s1.length, 2);
		s1.add(Region(11,14));
		Assert(s1.length, 3);
		Assert(s1[0], Region(0,10));
		Assert(s1[1], Region(11,14));
		Assert(s1[2], Region(15,35));
		s1.add(Region(10,14));
		Assert(s1.length, 2);
		Assert(s1[0], Region(0,14));
		Assert(s1[1], Region(15,35));
		s1.add(Region(10,15));
		Assert(s1.length, 1);
		Assert(s1.front, Region(0,35));

		auto s2 = new RegionSet;
		s2.add(10, 20);
		s2.add(3, 7);
		Assert(s2.length, 2);
		Assert(s2[0], Region(3,7));
		Assert(s2[1], Region(10,20));
	}
/*
	void toggle(uint a, uint b, int id = 0)
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
					mergeStartIdx = i;
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
	
	void add(RegionSet s) 
	{ 
		foreach (r; s)
			add(r);
	}
	
	unittest
	{
		auto s1 = new RegionSet;
		auto s2 = new RegionSet;
		s1.add(Region(0,10));
		s1.add(Region(20,30));
		s1.add(Region(40,50));
		s2.add(s1);
		Assert(s2.length, 3);
		Assert(s2[0], Region(0,10));
		Assert(s2[1], Region(20,30));
		Assert(s2[2], Region(40,50));
	}
	
	// TODO fix
	void substract(Region r) 
	{ 
		int startIdx = -1;
		for (int i = 0; i < regions.length; ++i)
		{
			auto cur = regions[i];
			Region ins = cur.intersect(r);
			if (!ins.empty)
			{
				if (startIdx == -1)
				{
					regions[i].b = ins.a;
					if (regions[i].empty)
						startIdx = i;
					else
						startIdx = i+1;
				}
			} else if (startIdx != -1)
			{
				regions.linearRemove(regions[startIdx..i]);
				break;
			}
		}
	}
	
	// TODO fix
	bool contains(Region r) 
	{ 
		for (int i = 0; i < regions.length; ++i)
		{
			auto re = regions[i];
			if (r.b <= re.a) break;
			if (r.contains(re)) return true;
		}
		return false;
	}
	
	// TODO fix
	RegionSet getInverse()
	{ 
		RegionSet rs = new RegionSet();
		uint lastEnd = 0;
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
	RegionSet intersect(Region r) 
	{ 
		auto rs = new RegionSet();

		int first = -1;
		foreach (i; 0..regions.length)
		{
			auto cur = regions[i];
			if (r.b <= cur.a) break;
			bool ins = r.intersects(cur);
			if (ins)
			{
				first = i;
				rs.add(cur);
			} else if (first != -1)
			{
				break;
			}
		}
		return rs; 
	}
}

