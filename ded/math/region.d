module math.region;

//import style; // : Style;
import alg = std.algorithm;
import std.container;
import std.exception;

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

	unittest 
	{
		assert(Region.zero.empty);
		assert(Region(5,5).empty);
		assert(!Region(0,1).empty);
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
		assert(Region(0,10).cover(Region(10,20)) == Region(0,20));
		assert(Region(10,20).cover(Region(0,10)) == Region(0,20));
		// Test containing regions
		assert(Region(0,20).cover(Region(5,10)) == Region(0,20));
		// Test regions with space between
		assert(Region(0,10).cover(Region(15,100)) == Region(0,100));
	}
	
	/** Return the intersection of the two regions
	 */
	Region intersect(Region r) const
	{ 
		if (r.b <= a || r.a >= b || r.empty || empty) 
			return Region(a, a, id); // an empty region with start at this.a
		return Region(r.a > a ? r.a : a, r.b < b ? r.b : b, id);
	}
	
	unittest {
		// Test touching regions
		assert(Region(0,10).intersect(Region(10,20)).empty);
		assert(Region(10,20).intersect(Region(0,10)).empty);
		// Test containing regions
		assert(Region(0,20).intersect(Region(5,10)) == Region(5,10));
		// Test regions with space between
		assert(Region(0,10).intersect(Region(15,100)).empty);
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
		assert(!Region(0,10).contains(Region(10,20)));
		assert(!Region(10,20).contains(Region(0,10)));
		// Test containing regions
		assert(Region(0,20).contains(Region(5,10)));
		assert(Region(5,10).contains(Region(5,10)));
		// Test regions with space between
		assert(!Region(0,10).contains(Region(15,100)));
	}
	
	/** Returns true if the given index is contained within this region
	 */
	bool contains(uint p) const
	{ 
		return p >= a && p < b && !empty;
	}
	
	unittest
	{
		assert(!Region.zero.contains(0));
		assert(Region(0,1).contains(0));
		assert(!Region(0,1).contains(1));
		assert(!Region(0,1).contains(2));
	}
}

/** A set of regions
 * 
 * The regions is not overlapping and adding a region that
 * overlaps existing regions in the set will merge them into one.
 * 
 * TODO: Make operations lazy by returning a Range instead of a new RegionSet
 */
class RegionSet
{
	alias Array!Region Container;
	alias Container.Range Range;
	Container regions;
	alias regions this;

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
		assert(s1.empty);
		s1.add(Region(0,10));
		assert(s1.length == 1);
		s1.add(Region(20,30));
		assert(s1.length == 2);
		s1.add(Region(20,30));
		assert(s1.length == 2);

		s1.add(Region(15,35));
		assert(s1.length == 2);
		s1.add(Region(22,25));
		assert(s1.length == 2);
		s1.add(Region(11,14));
		assert(s1.length == 3);
		assert(s1[0] == Region(0,10));
		assert(s1[1] == Region(11,14));
		assert(s1[2] == Region(15,35));
		s1.add(Region(10,14));
		assert(s1.length == 2);
		assert(s1[0] == Region(0,14));
		assert(s1[1] == Region(15,35));
		s1.add(Region(10,15));
		assert(s1.length == 1);
		assert(s1.front == Region(0,35));
	}

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
		assert(s2.length == 3);
		assert(s2[0] == Region(0,10));
		assert(s2[1] == Region(20,30));
		assert(s2[2] == Region(40,50));
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

