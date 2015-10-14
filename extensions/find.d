module extensions.find;

import extensions;
mixin registerCommands;

@Shortcut("<ctrl> + <shift> + f")
void findInFiles(string needle)
{
	import std.file;
	import std.algorithm;
	import std.string;
	import std.utf;

	struct FoundItem
	{
		string filePath;
		ptrdiff_t index;
	}
	FoundItem[] foundItems;
	import std.stdio;

	// Iterate over all *.d files in current directory and all its subdirectories
	auto dFiles = filter!`endsWith(a.name,".d")`(dirEntries(".",SpanMode.depth));
	foreach(d; dFiles)
	{
		string haystack;
		try
		{
			haystack = readText(d.name);
		}
		catch (UTFException)
		{
			// TODO: Remember these files and skip on next find
			version (linux)
                writeln("Cannot find in file ", d.name);
			continue;
		}
		ptrdiff_t idx = haystack.indexOf(needle);

		while (idx >= 0)
		{
			foundItems ~= FoundItem(d.name, idx);
			if (idx != haystack.length-1)
				idx = haystack.indexOf(needle, idx+1);
			else
				idx = -1;
		}
	}

	version (linux)
    {
        foreach (i; foundItems)
	        writeln(i.filePath, " ", i.index);
    }
}
