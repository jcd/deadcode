module extensions.unittests;

import core.buffer;
import extension;
import guiapplication;
import gui.event;
import gui.window;
import controls.texteditor;
import math.rect;

import std.string;

private bool defaultUnittester()
{
	import test;
	import std.stdio;

	foreach (tname; g_TestOrder)
	{
		auto func = tname.fullName in g_ModuleUnitTests;
		if (func is null)
		{
			writeln("Couldn't look up unittest ", tname);
		}
		else
		{
			(*func)();
		}
	}

	printStats(true);
	
	return true;
}

static this()
{
	import core.runtime;
	import std.stdio;
	//Runtime.moduleUnitTester(&defaultUnittester);

	foreach (m; ModuleInfo)
	{
		//writeln("Found module ", m.name);
		void *mems = m.xgetMembers();
		if (mems is null)
			continue;
		auto mi = cast(MemberInfo[]*) mems;
		auto mii = *mi;
		writeln(mii[0].name);
	}
}

class UnittestAnchor : TextEditorAnchor
{

	override EventUsed onMouseOver(Event ev)
	{
		window.mouseCursor = MouseCursor.arrow;
		return EventUsed.yes;
	}

	override EventUsed onMouseClick(Event ev)
	{

		import std.typetuple;
		import std.stdio;
		import std.conv;

		alias tests = TypeTuple!(__traits(getUnitTests, math.rect));
		import std.string;

		foreach (test; tests)
		{
			// ie. __unittestL235_52
			enum name = __traits(identifier, test)[11..$];
			enum line = name[0.. indexOf(name, "_")];

			if (textAnchor.number+1 == line.to!uint)
			{
				writeln("Running " ~ line);
				test();
			}
		}

		return EventUsed.yes;
	}

	override void update()
	{
		// std.stdio.writefln("anchor %s", rect);
	}
}

/**
	Tools and GUI for the builtin dlang unittests
*/
class Unittests : BasicExtension!Unittests, TextEditorAnchorOwner
{
	override @property string name() { return "unittests"; }
		
	TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor)
	{
		return new UnittestAnchor();
	}

	override void init()
	{
		import core.runtime;
	
		app.bufferViewManager.onBufferViewCreated.connect(&onBufferViewCreated);
		foreach (bv; app.bufferViewManager.buffers)
			onBufferViewCreated(bv);


	}

	private bool runUnittest()
	{
		import std.stdio;
		writefln("Running tests");
		return false;
	}

	private void onBufferViewCreated(BufferView bv)
	{
		// TODO: maybe make a single onLinesChanged that can be used instead of the two below
		bv.buffer.lbuffer.onLineModified.connect(&onLineModified);
		bv.buffer.lbuffer.onLinesInserted.connect(&onLinesInserted);
	}

	// Next three handler is in charge of detecting unittest lines and adding/removing anchors
	// for them.
	void onLineModified(uint lineNumber)
	{
		auto editor = currentTextEditor;
		auto line = editor.bufferView.buffer.lineString(lineNumber);
		
		if (line.startsWith("unittest"))
		{
			editor.bufferView.buffer.ensureLineAnchor(lineNumber, this);
		}
		else
		{
			editor.bufferView.buffer.removeLineAnchorByLine(lineNumber, this);
		}
	}
		
	void onLinesInserted(uint lineNumber, uint lineCount)
	{
		foreach (i; lineNumber..lineNumber+lineCount)
			onLineModified(i);
	}
}
