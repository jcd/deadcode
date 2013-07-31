module o;

import std.stdio;

void o(T...)(T args)
{
	foreach (a; args)
	{
		std.stdio.write(a, " ");
	}
	std.stdio.write("\n");
}