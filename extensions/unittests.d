module extensions.unittests;

import animation.timeline;
import animation.interpolate;

import dccore.buffer;
import application;
import controls.texteditor;
import gui.event;
import gui.window;
import math.rect;

import extensionapi;
mixin registerCommands;

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
			assert(0);
            // writeln("Couldn't look up unittest ", tname);
		}
		else
		{
			(*func)();
		}
	}

	import std.stdio;
    printStats(stdout, true);

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
/*
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
*/
}

import gui.style;

class TestWidget : Widget
{
	this(Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		super(_parent, x, y, width, height);
	}
}

class UnittestAnchor : GenericTextEditorAnchorWidget
{
	Timeline timeline;
	Application app;

	@property TextEditor textEditor()
	{
		return cast(TextEditor) parent;
	}

	this(Timeline timeline, Application app)
	{
		super();
		this.timeline = timeline;
		this.app = app;
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

		version (linux)
        {
            if (rec.file.empty)
		    {
			    writeln("No result");
		    }
		    else
		    {
			    writeln("Result : ", rec.success);
		    }
        }
		return EventUsed.yes;
	}

	override EventUsed onMouseClick(Event ev)
	{
		app.pushCommandCall(CommandCall("dub.runModuleUnittests"));
	    return EventUsed.yes;
    }

    /*override*/ EventUsed ddonMouseClick(Event ev)
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
				version (linux) writeln("Running ", line, " ", testName);
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
class Unittests : Extension, ITextEditorAnchorOwner
{
	import dccore.buffer;

    override @property string name() { return "unittests"; }

	TextEditorAnchorWidget createAnchorWidget(TextBufferAnchor anchor, TextEditor editor)
	{
		return new UnittestAnchor(app.guiRoot.timeline, app);
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
		bv.buffer.lbuffer.onLineModified.connectTo((int l) {
	         onLineModified(l, bv.buffer);
        });
		bv.buffer.lbuffer.onLinesInserted.connectTo((int l, int lc) {
	         onLinesInserted(l, lc, bv.buffer);
        });
	}

	// Next three handler is in charge of detecting unittest lines and adding/removing anchors
	// for them.
	void onLineModified(int lineNumber, TextBuffer buf)
	{
		import std.uni;

		// auto editor = currentTextEditor;
		auto line = buf.lineString(lineNumber).stripLeft;


		if (line.startsWith("unittest") && (line[8..$].empty || line[8..$][0].isWhite() || line[8..$][0] == '{'))
		{
			buf.ensureLineAnchor(lineNumber, this);
		}
		else
		{
			buf.removeLineAnchorByLine(lineNumber, this);
		}
	}

	void onLinesInserted(int lineNumber, int lineCount, TextBuffer buf)
	{
		foreach (i; lineNumber..lineNumber+lineCount)
			onLineModified(i, buf);
	}
}
