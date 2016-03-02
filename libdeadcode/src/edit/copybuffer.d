module edit.copybuffer;

version (unittest)
{
    import test;
    mixin registerUnittests;
}
else
    import derelict.sdl2.functions;

import std.conv;
import std.range;

class CopyBuffer
{

	static class Entry
	{
		this(string t)
		{
			txt = t;
		}
		string txt;
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
		        else if (entries[$-1].txt == SDL_GetClipboardText().to!string())
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

	void add(string t)
	{
		import std.string;
		entries ~= new Entry(t);
        version (unittest)
        {
        }
        else
        {
            SDL_SetClipboardText(t.toStringz());
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
				    return new Entry(to!string(SDL_GetClipboardText()));
			    }
			    else if (entries[$-1].txt == SDL_GetClipboardText().to!string())
			    {
				    return entries[$-offset-1];
			    }
			    else if (offset == 0)
			    {
				    return new Entry(to!string(SDL_GetClipboardText()));
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
