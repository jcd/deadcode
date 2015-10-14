module extensions.gctracker;

import extensions;

static if (false && HasModule!"extensions.errorlist"):

import gui.event;
import gui.label;
import controls.texteditor;
import core.buffer;
import extensions.errorlist;
import std.stdio;
import std.regex;

class GCAllocAnchor : TextEditorAnchor
{
	Label label;
	GCTracker tracker;
	int id;

	override EventUsed onMouseOver(Event ev)
	{
		if (label is null)
		{
			label = new Label(tracker.getMessageForAnchor(id));
			label.parent = this;
		}
		label.visible = true;
		return EventUsed.yes;
	}

	override EventUsed onMouseOut(Event ev)
	{
		if (label !is null)
			label.visible = false;
		return EventUsed.yes;
	}
}

class GCTracker : BasicExtension!GCTracker, TextEditorAnchorOwner
{
	override @property string name() { return "gctracker"; }

	struct GCAlloc
	{
		int line;
		int column;
		string message;
	}

	struct GCFileAllocs
	{
		string file;
		GCAlloc[] allocs;
	}

	GCFileAllocs[string] allocForFiles;
	string[int] anchorIdToMessage;

	private Regex!char re;

	override void init()
	{
		re = regex(`(.*[\\/]\w+\.d)\((\d+),?(\d*)\):\s*vgc:\s*(.*)`);
		ErrorListWidget.primary.messageAppended.connect(&this.onMessageAppended);
		ErrorListWidget.primary.listCleared.connect(&this.onClear);

		app.bufferViewManager.onBufferViewCreated.connect(&onBufferViewCreated);
		foreach (bv; app.bufferViewManager.buffers)
			onBufferViewCreated(bv);
	}

	private void onBufferViewCreated(BufferView bv)
	{
		auto fa = bv.name in allocForFiles;
		if (fa is null)
			return;

		foreach (ref alloc; fa.allocs)
			addAnchorToBuffer(bv, alloc.line, alloc.message);
	}

	TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
	{
		auto r = new GCAllocAnchor();
		r.tracker = this;
		r.id = anchor.id;
		return r;
	}

	string getMessageForAnchor(int id)
	{
		auto m = id in anchorIdToMessage;
		if (m is null)
			return null;
		return *m;
	}

	void onMessageAppended(ErrorListWidget w, string msg)
	{
		import std.conv;
		import std.path;
		auto m = msg.matchFirst(re);
		if (m)
		{
			string pathName = buildNormalizedPath(m[1]);
			auto a = pathName in allocForFiles;
			if (a is null)
			{
				allocForFiles[pathName] = GCFileAllocs(m[1]);
				a = m[1] in allocForFiles;
			}
			int line = m[2].to!int - 1;
			a.allocs ~= GCAlloc(line, m[3].to!int, m[4]);

			BufferView v = app.bufferViewManager[pathName];
			addAnchorToBuffer(v, line, m[4]);
		}
	}

	void addAnchorToBuffer(BufferView v, int line, string message)
	{
		if (v !is null)
		{
			auto textAnchor = v.buffer.ensureLineAnchor(line, this);
			anchorIdToMessage[textAnchor.id] =  message;
		}
	}

	void onBufferViewFocus(BufferView buf)
	{
		// Mark op bufferview with gc allow places
	}

	void onClear(ErrorListWidget w)
	{
		allocForFiles = null;
		//writeln("FOO: CLEAR");
	}
}

