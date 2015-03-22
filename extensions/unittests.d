module extensions.unittests;

import animation.timeline;
import animation.interpolate;

import core.buffer;
import extensions;
import guiapplication;
import controls.texteditor;
import gui.event;
import gui.window;
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

private bool noopUnittester()
{
	return true;
}

shared static this()
{
	import core.runtime;
	import std.stdio;
//	Runtime.moduleUnitTester(&defaultUnittester);
	return;
	Runtime.moduleUnitTester(&noopUnittester);

	foreach (m; ModuleInfo)
	{
		//writeln("Found module ", m.name, " ", m.unitTest.stringof);
		void *mems = m.xgetMembers;
		if (mems is null)
			continue;
		auto mi = cast(MemberInfo[]*) mems;
		auto mii = *mi;
		writeln(mii[0].name);
	}
}

import gui.style;

class TestWidget : Widget
{
	this(Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		super(_parent, x, y, width, height);
	}
}

class UnittestAnchor : TextEditorAnchor
{
	Timeline timeline;

	@property TextEditor textEditor()
	{
		return cast(TextEditor) parent;
	}

	this(Timeline timeline)
	{
		super();
		this.timeline = timeline;
	}

	override EventUsed onMouseOver(Event ev)
	{
		window.mouseCursor = MouseCursor.hand;
		return EventUsed.yes;
	}

	override EventUsed onMouseDown(Event ev)
	{
		return EventUsed.yes;
	}

	EventUsed eonMouseClick(Event ev)
	{
		import std.stdio;
		import test;
        import std.array : empty;

		auto bufferName = textEditor.bufferView.name;
		TestRecord rec = getTestResult(bufferName, textAnchor.number+1);

		if (rec.file.empty)
		{
			writeln("No result");
		}
		else
		{
			writeln("Result : ", rec.success);
		}
		return EventUsed.yes;
	}

	override EventUsed onMouseClick(Event ev)
	{
		import std.typetuple;
		import std.stdio;
		import std.conv;
		import test;

		alias tests = TypeTuple!(__traits(getUnitTests, math.rect));
		import std.string;

		foreach (atest; tests)
		{
			// ie. __unittestL235_52
			enum testName = __traits(identifier, atest)[11..$];
			enum line = testName[0.. indexOf(testName, "_")];
			string tn = testName;

			if (textAnchor.number+1 == line.to!int)
			{
				writeln("Running ", line, " ", testName);
				atest();

				//TestRecord rec = getTestResult(textAnchor.number+1);
				//if (rec.file.empty)
				//    writeln("No result");
				//else
				//{
				//    writeln("Result : ", rec.success);
				//}
			}
		}

		auto wi = window.createWidget!TestWidget(window, 0, 0, 100, 100);
		return EventUsed.yes;
	}
}

/**
	Tools and GUI for the builtin dlang unittests
*/
class Unittests : BasicExtension!Unittests, TextEditorAnchorOwner
{
	override @property string name() { return "unittests"; }

	TextEditorAnchor createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
	{
		return new UnittestAnchor(app.guiRoot.timeline);
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
	void onLineModified(int lineNumber)
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

	void onLinesInserted(int lineNumber, int lineCount)
	{
		foreach (i; lineNumber..lineNumber+lineCount)
			onLineModified(i);
	}
}
