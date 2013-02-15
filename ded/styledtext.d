module styledtext;
import region;
import style;

class StyledText(Text)
{
	public RegionSet regionSet;
	StyleSet styleSet;
	public Text text;
	
	this(Text text, RegionSet regionSet, StyleSet styleSet = StyleSet.base)
	{
		this.text = text;
		this.styleSet = styleSet;
		this.regionSet = regionSet;
	}
	
	// A Region specifying the composed style of several styles 
	static struct StyledRegion
	{
		Region _reg;
		alias _reg this;
		StyleFields styleFields;
		this(uint a, uint b, StyleFields styleFields)
		{
			this.a = a;
			this.b = b;
			this.styleFields = styleFields;
		}
	}
	
	// This slice can be used to iterate over composed style regions lazyly. 
	auto opSlice(uint from, uint to)
	{
		struct Range
		{
			// The regionSet must be non-partial overlapping ie. like xml markup is since this
			// makes it possible to keep the style state in stack form with the top item being the
			// current active styled region.
			private
			{
				RegionSet.Range regionSetRange;
				Array!StyledRegion stack_;
				StyledRegion curRegion_;
				uint to_;
						
			}
				
			this(uint f, uint t)
			{
				curRegion_.a = f;
				curRegion_.b = t;
				stack.insertBack(curRegion_);
				
				regionSetRange = regionSet[];
				
				while (!regionSetRange.empty)
				{
					auto r = regionSetRange.front;
					
					if (r.a >= f)
					{
						// Reached or exceeded the start point
						if (!stack_.empty)
						{
							// f is not within a region and the upcoming region is the current one
							curRegion_.b = r.a;
							popFront(); // prime
							
							//stack_.insertBack(StyledRegion(r.a, r.b, curRegion_.styleFields));
							//curRegion_.a = r.a;
							//curRegion_.b = r.b;
							//curRegion_.styleFields = styleSet[r.id].computedFields;
						}
						break;
					}
					else if (r.b > f) // implicit r.a < f 
					{
						// Region r overlaps f 
						StyleFields sf = curRegion_.styleFields.overlay(styleSet[region.id].computedFields);
						stack_.insertBack(StyledRegion(r.a, r.b, sf));
						curRegion_.styleFields = sf;
						curRegion_.b = r.b;
					}
					
					regionsSetRange.popFront();						
				}
				
				if (_curRegion.b >= t)
				{
					// No regions
					stack_.clear();
				}
			}
			
			void popFront()
			{
				assert(!empty);
				
				uint curEnd = curRegion_.b;	
				curRegion_.a = curEnd;
					
				while (!stack.empty && stack_.back().b == curEnd)
					stack.popBack();
				
				if (stack.empty) return; // reached the end since the bottom stack Region ends at destination
					
				// Now the next region is either from the end of curRegion to the
				// end of the region of the top of the stack. Or from the curRegion to
				// the next item in the range.

				if (regionSetRange.empty || stack.back().b <= regionSetRange.front.a)
				{
					// Definitely the stack that should be used for the next region
					curRegion_.styleFields = stack_.back().styleFields;
					curRegion_.b = stack_.back().b;
					return;
				}
				

				auto r = regionSetRange.front;
				if (r.a == curEnd)
				{
					// The last region is right next to the next region
					regionSetRange.popFront();
					StyleFields sf = curRegion_.styleFields.overlay(styleSet[r.id].computedFields);
					stack.insertBack(StyledRegion(r.a, r.b, sf));
					curRegion_.b = regionSetRange.empty || regionSetRange.front.a > r.b ? r.b : regionSetRange.front.a;
				}
				else
				{
					curRegion_.b =  r.a;
				}
				curRegion_.styleFields = stack_.back().styleFields;
			}
						
			@property 
			{
				@safe bool empty() const nothrow
				{
					return stack_.empty;
				}
				
				@safe StyledRegion front() const nothrow
				{
					assert(!empty);
					return curRegion_;
				}
			}
		}
			
		return Range(from, to);
	}
	
	void update(StyleSet styleSet)
	{
		if (styledRegionSets.length != 0) return; // TODO: fix
		
		// TODO: parse text and set styles
		auto regionSet = new RegionSet();
		auto r = Region(0, uint.max);
		regionSet.add(r);
		styledRegionSets[StyleSet.base[""]] = regionSet;
	}
}

unittest
{
	std.stdio.writeln("Styles white %x, black %x, yellow %x", &white, &black, &yellow); 
	
	auto text = new StyledText!dchar("yellow white      black yellow"d);
	auto rs = new RegionSet();
	
	uint yellow = 1;
	uint white = 2;
	uint black = 3;	
	
	rs.add(0, 6, yellow); 
	rs.add(7, 12, white);
	rs.add(18, 23, black);
	rs.add(24, 100, yellow); 

	auto r = text[1..text.text.length];
	
	// Print out the styles
	foreach (sr; r)
	{
		std.stdio.writeln("Range %i %i: %s", sr.a, sr.b, sr.styleFields);
	}			
}
	