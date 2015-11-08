module extensions.search;

import extensions;
mixin registerCommands;

@MenuItem("Edit/Search")
@Shortcut("<ctrl> + i")
@(Hints.off)
class SearchCommand : BasicCommand
{
	import std.string;

    struct BufferSearchInfo
    {
        private int cursorPointAtStart;
        string lastNeedle;
        int cursorAtRegionIndex = int.min;  // which region to place the cursor at ie. for jumps to next search result.
        int completionSessionID = -1;
    }

    final private BufferSearchInfo getBufferInfo()
    {
        return buffer.userData.get("search", Variant(BufferSearchInfo(currentTextEditor.bufferView.cursorPoint, null,  int.min, false))).get!BufferSearchInfo;
    }

    final private void setBufferInfo(BufferSearchInfo info)
    {
        buffer.userData["search"] = info;
    }

	void run(string needle)
	{
        BufferSearchInfo info = getBufferInfo();

        with (info)
        {
            lastNeedle = needle;
		    needle = needle.toLower();

            int idx = 0;
            if (cursorAtRegionIndex == int.min)
            {
		        idx = search(needle, cursorPointAtStart == -1 ? currentTextEditor.bufferView.cursorPoint : cursorPointAtStart);
            }
            else
            {
                idx = currentTextEditor.getOrCreateHighlighter("search").regions[cursorAtRegionIndex].a;
                cursorPointAtStart = 0;
            }

		    if (idx != -1)
		    {
			    auto at = cursorPointAtStart + idx;
			    currentTextEditor.bufferView.selection = Region(at, at + cast(int)needle.length);
			    currentTextEditor.bufferView.cursorPoint = at + cast(int)needle.length;
		    }
		    currentTextEditor.getOrCreateHighlighter("search").regions.clear();
		    cursorPointAtStart = -1;
            cursorAtRegionIndex = int.min;
        }
        setBufferInfo(info);
	}

    override bool executeWithMissingArguments(ref CommandParameter[] data)
    {
         BufferSearchInfo info = getBufferInfo();
        if (info.lastNeedle is null || info.completionSessionID == -1)
            return false; // Cannot search again using the old needle;

        // When in a completion session and we have missing arguments we simply reuse the old needle.
        // So when the search command is first called with no args it is not in a session and this function
        // will not handle that case and that will in turn start a completion session by the fallback mechanism (and if
        // it doesn't that is ok too).
        // Then when the search command is issued again we are now in a completion session and just reuse the old needle
        // if there is one.
        data.length = 1;
        data[0] = CommandParameter(info.lastNeedle);
        return false;
    }

	private int search(string needle, int startIdx)
	{
		auto b = currentTextEditor.bufferView.buffer;
        auto len = b.length;
        if (needle.length == 0 || startIdx >= len)
            return -1;

		// auto str = v[0].get!string;
		auto r = b[startIdx..len];
		int idx = -1;
		for (int i = 0; i < r.length; ++i)
		{
			int j = i;
			foreach (s; needle)
			{
				if (r[j].toLower() != s)
					break;
				++j;
			}
			if (j - i == needle.length)
			{
				idx = i;
				break;
			}
		}
		return idx;
	}

    override bool beginCompletionSession(int sessionID)
    {
        BufferSearchInfo info = getBufferInfo();
        if (info.completionSessionID > 0)
        {
            assert(info.completionSessionID > 0);
            return false; // do not allow multi sessions on same buffer
        }
        info.completionSessionID = sessionID;
        info.cursorAtRegionIndex = int.min;
        setBufferInfo(info);
        return true;
    }

    override void endCompletionSession()
    {
        BufferSearchInfo info = getBufferInfo();
		currentTextEditor.getOrCreateHighlighter("search").regions.clear();
		info.cursorPointAtStart = -1;
        info.completionSessionID = -1;
        info.cursorAtRegionIndex = int.min;
        setBufferInfo(info);
    }

    override int getCompletionSessionID()
    {
        BufferSearchInfo info = getBufferInfo();
        return info.completionSessionID;
    }

    protected int nextRegionIndex(int currentIndex, int baseIndex)
    {
        return currentIndex == int.min ? baseIndex : currentIndex + 1;
    }

	CompletionEntry[] complete(string needle)
	{
        CompletionEntry[] results;
        if (needle.length == 0)
            return results;

        BufferSearchInfo info = getBufferInfo();

        with (info)
        {
            if (lastNeedle != needle) // handle incr. search and needle change
                cursorAtRegionIndex = int.min;

            lastNeedle = needle;

		    if (cursorPointAtStart == -1)
			    cursorPointAtStart = currentTextEditor.bufferView.cursorPoint;
		    auto highlighter = currentTextEditor.getOrCreateHighlighter("search");

		    needle = needle.toLower();

            // TODO: do not search again if the needle is the same since we know the regions already.
            highlighter.regions.clear();
            int idx = search(needle, 0);
            if (idx != -1)
            {
                auto at = idx;
                highlighter.regions.set(at, at + cast(int)needle.length);

                // The region index that is right after the cursor position.
                int cursorRegionIndexOffset = -1;
                if (at >= cursorPointAtStart)
                    cursorRegionIndexOffset = 0;

                idx = at + 1;
                int nextIdx;
                int count = 0;
                while ((nextIdx = search(needle, idx)) != -1)
                {
                    count++;
                    at = idx + nextIdx;
                    if (cursorRegionIndexOffset == -1 && at >= cursorPointAtStart)
                        cursorRegionIndexOffset = count;
                    highlighter.regions.set(at, at + cast(int)needle.length);
                    idx = at + 1;
                }
                cursorAtRegionIndex = nextRegionIndex(cursorAtRegionIndex, cursorRegionIndexOffset);
            }

            // Place cursor at search result index
            if (cursorAtRegionIndex != int.min)
            {
                import std.algorithm : min, max;
                cursorAtRegionIndex = (cast(int)highlighter.regions.length + cursorAtRegionIndex) % cast(int)highlighter.regions.length;
                Region activeRegion = highlighter.regions[cursorAtRegionIndex];
                currentTextEditor.bufferView.viewOnCharPaged(activeRegion.a);
                currentTextEditor.bufferView.selection = activeRegion;
                currentTextEditor.bufferView.cursorPoint = activeRegion.b;
            }
        }

        setBufferInfo(info);

		app.repaintAll();
		return results;
	}
}

@MenuItem("Edit/Search Reverse")
@Shortcut("<ctrl> + <shift> + i")
@(Hints.off)
class SearchReverseCommand : SearchCommand
{
    override protected int nextRegionIndex(int currentIndex, int baseIndex)
    {
        return currentIndex == int.min ? baseIndex - 1 : currentIndex - 1;
    }
}

//@MenuItem("Edit/Search2")
@Shortcut("<ctrl> + j")
@Shortcut("<alt> + j", "Lin")
void search2(Application app, string needle)
{
	import std.string;
	auto str = needle;
	auto b = app.currentBuffer.buffer;
	auto r = b[app.currentBuffer.cursorPoint..b.length];
	int idx = -1;
	for (int i = 0; i < r.length; ++i)
	{
		int j = i;
		foreach (s; str)
		{
			if (r[j] != s)
				break;
			++j;
		}
		if (j - i == str.length)
		{
			idx = i;
			break;
		}
	}
	if (idx != -1)
		app.currentBuffer.cursorPoint = app.currentBuffer.cursorPoint + idx;
}

//@MenuItem("Edit/Uppercase")
@Shortcut("<ctrl> + u")
void wordUppercase(Application app, string dummy)
{
	import std.uni;
	auto b = app.currentBuffer;
	auto origPoint = b.cursorPoint;
	Region r = b.selection;

	if (r.empty)
	{
		// Get word on cursor
		b.cursorToBeginningOfWord();
		r.a = b.cursorPoint;
		b.selectToEndOfWord();
		r.b = b.cursorPoint;
	}

	if (!r.empty)
	{
		auto txt = b.getText(r);
		toUpperInPlace(txt);
		b.replace(txt.idup, r);
	}
	b.cursorPoint = origPoint;
}

//@MenuItem("Text/Uppercase")
@Shortcut("<ctrl> + o")
void textUppercase(Application app, string dummy)
{
    static import std.uni;
	auto b = app.currentBuffer;
	auto r = b.getRegion(RegionQuery.selectionOrWord);
	if (!r.empty)
		b.replace(cast(immutable)std.uni.toUpper(b.getText(r)), r);
}

//@MenuItem("Dub/Uppercase2")
@Shortcut("<ctrl> + r")
void textUppercase2(BufferView buf)
{
    static import std.uni;
	buf.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}

/*
@MenuItem("Dub/Uppercase3")
@Shortcut("<ctrl> + R")
void textUppercase3(BufferView buf)
{
	import std.uni;
	auto r = buf[RegionQuery.selectionOrWord];

		// auto r = buf.getRegionView(RegionQuery.selectionOrWord);
	r.replace(r.toUpper);

	r.toUpper.copy(r);

	r = toUpper(r);
}
*/
