module graphics.color;

import math._;

struct Color
{
	union 
	{
		float[3] v;
		struct 
		{
			float r, g, b;
		}
	}
	
	this(float r, float g, float b)
	{
		this.r = r;
		this.g = g;
		this.b = b;
	}
	
	//static Color black = Color(0.0, 0.0, 0.0);
	//static Color white = Color(1.0, 1.0, 1.0);
}