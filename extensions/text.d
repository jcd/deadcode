module extensions.text;

import extensionapi;
mixin registerCommands;

// RAII struct that records selection and restores it in destructor
struct SelectionRestorer
{
    BufferView bufferView;
    this(BufferView bv)
    {
        bufferView = bv;
        bufferView.pushSelection();
    }

    ~this()
    {
        bufferView.popSelection();
    }

    this(this) @disable
    {
    }
}

@Shortcut("<tab>")
void textIncreaseIndent(BufferView v)
{
	addTextPrefix(v, "\t");
}

@Shortcut("<ctrl> + k <ctrl> + c")
void textCommentSelection(BufferView v)
{
    addTextPrefix(v, "//");
}

@Shortcut("<alt> + ;")
void textCommentSelectionToggle(BufferView v)
{
	import std.string;
	auto l = v.getLineAtSelection();

    // TODO: also remove indented comment tokens ie. munch "\t " here.

	if (l.startsWith("//"))
		removeTextPrefix(v, "//");
	else
		addTextPrefix(v, "//");
}

private void addTextPrefix(BufferView v, string text)
{
    auto r = v.getRegion(RegionQuery.selectionOrLine);

    auto rr = SelectionRestorer(v);

	r = r.normalized();

    int firstLine = v.buffer.lineNumberAt(r.a);
	int lastLine = firstLine;
	if (!r.empty)
	{
	bool endSelIsStartOfLine = v.buffer[r.b-1] == '\n';
	int endSelIdx = endSelIsStartOfLine ? r.b-1 : r.b;
		lastLine = v.buffer.lineNumberAt(endSelIdx);
	}

	foreach (line; firstLine .. lastLine + 1)
	{
		int idx = v.buffer.startAtLineNumber(line);
		v.cursorPoint = idx;
		v.insert(text);
	}
}

@Shortcut("<shift> + <tab>")
void textDecreaseIndent(BufferView v)
{
	removeTextPrefix(v, "\t");
}

@Shortcut("<ctrl> + k <ctrl> + u")
void textUncommentSelection(BufferView v)
{
    // TODO: also remove indented comment tokens
	removeTextPrefix(v, "//");
}

private void removeTextPrefix(BufferView v, string text)
{
	auto r = v.getRegion(RegionQuery.selectionOrLine);
	if (r.empty)
		return;

    auto rr = SelectionRestorer(v);

	r = r.normalized();

	int firstLine = v.buffer.lineNumberAt(r.a);
	int lastLine = v.buffer.lineNumberAt(r.b);
	int removeLen = cast(int)text.length;
	foreach (line; firstLine .. lastLine+1)
	{
		int idx = v.buffer.startAtLineNumber(line);
        v.cursorPoint = idx;
		if (idx == r.b)
			continue;

		if (v.getText(idx, idx+removeLen) == text)
			v.remove(removeLen);
	}
}



