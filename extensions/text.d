module extensions.text;

import extensions;
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
	addTextPrefix(v, "\t"d);
}

@Shortcut("<ctrl> + k <ctrl> + c")
void textCommentSelection(BufferView v)
{
    addTextPrefix(v, "//"d);
}

@Shortcut("<alt> + ;")
void textCommentSelectionToggle(BufferView v)
{
	import std.string;
	auto l = v.getLineAtSelection();

    // TODO: also remove indented comment tokens ie. munch "\t " here.

	if (l.startsWith("//"))
		removeTextPrefix(v, "//"d);
	else
		addTextPrefix(v, "//"d);
}

private void addTextPrefix(BufferView v, dstring text)
{
    auto r = v.getRegion(RegionQuery.selectionOrLine);
	if (r.empty)
		return;

    auto rr = SelectionRestorer(v);

	r = r.normalized();

    int firstLine = v.buffer.lineNumberAt(r.a);
	bool endSelIsStartOfLine = v.buffer[r.b-1] == '\n';
	int endSelIdx = endSelIsStartOfLine ? r.b-1 : r.b;
	int lastLine = v.buffer.lineNumberAt(endSelIdx);
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
	removeTextPrefix(v, "\t"d);
}

@Shortcut("<ctrl> + k <ctrl> + u")
void textUncommentSelection(BufferView v)
{
    // TODO: also remove indented comment tokens
	removeTextPrefix(v, "//"d);
}

private void removeTextPrefix(BufferView v, dstring text)
{
	auto r = v.getRegion(RegionQuery.selectionOrLine);
	if (r.empty)
		return;

    auto rr = SelectionRestorer(v);

	r = r.normalized();

	int firstLine = v.buffer.lineNumberAt(r.a);
	int lastLine = v.buffer.lineNumberAt(r.b);
	int removeLen = text.length;
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



