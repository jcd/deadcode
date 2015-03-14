module core.copybuffer;

version (unittest)
{}
else
    import derelict.sdl2.functions;

import std.conv;
import std.range;

class CopyBuffer
{

	static class Entry
	{
		this(dstring t)
		{
			txt = t;
		}
		dstring txt;
	}
	Entry[] entries;

	@property bool empty() const
	{
	    version (unittest)
            return entries.empty;
        else
            return entries.empty && !SDL_HasClipboardText();

	}

	@property size_t length() const
	{
        version (unittest)
        {
			return entries.length;
        }
        else
        {
            if (SDL_HasClipboardText())
		    {
			    if (entries.empty)
			    {
				    return 1;
			    }
		        else if (entries[$-1].txt.to!string() == SDL_GetClipboardText().to!string())
			    {
				    return entries.length;
			    }
			    else
			    {
				    return entries.length + 1;
			    }
		    }
		    else
		    {
			    return entries.length;
		    }
        }
	}

	void add(dstring t)
	{
		import std.string;
		entries ~= new Entry(t);
        version (unittest)
        {
        }
        else
        {
            SDL_SetClipboardText(to!string(t).toStringz());
        }
	}

	Entry get(int offset)
	{
		auto len =  length;
		if (offset >= len)
			return null;

		version (unittest)
        {
			return entries[$-offset-1];
        }
        else
        {
            if (SDL_HasClipboardText())
		    {
			    if (entries.empty)
			    {
				    return new Entry(to!string(SDL_GetClipboardText()).to!dstring());
			    }
			    else if (entries[$-1].txt.to!string() == SDL_GetClipboardText().to!string())
			    {
				    return entries[$-offset-1];
			    }
			    else if (offset == 0)
			    {
				    return new Entry(to!string(SDL_GetClipboardText()).to!dstring);
			    }
			    else
			    {
				    return entries[$-offset];
			    }
		    }
		    else
		    {
			    return entries[$-offset-1];
		    }
        }
	}
}
