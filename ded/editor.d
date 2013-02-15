module editor;

/+
 + 
import std.range;
import std.conv;
import std.variant;

import font;
import gui;
import text;
import graphics;
import math;
import behavior.emacs;
import command;
import render;

/* API:
View	 		TextView  
RegionSet		RegionSet
Region			Region
Edit			N/A
Window 			Window
Settings		N/A

Base Classes:

EventListener
ApplicationCommand
WindowCommand
TextCommand
*/


	
/// Plugin:

// Application wide command. One instance for the application.
class ApplicationCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}

// Window wide command. One instance per window.
class WindowCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}

// Editor wide command. One instance per editor.
class EditorCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}

/* TODO
 * scrolling
 * saving
 * highlighting
 * building
 * packaging
 * completion
 */

enum UndoStepType
{
	Insert,
	Remove
}

struct UndoStep
{
	UndoStepType type;
	uint index;
	string str;
}

struct BufferInfo
{
	string sourcePath;
	bool dirty;
	UndoStep[] undoStack; // do not use a builtin array for this!
}


/** A SourceCodeEditor contains text and widgets for editing and displaying source code
 *
 * The display of the source code is done through a root widget associated with the
 * SourceCodeEditor. This widget in turn contains widgets for presenting the different
 * part of the source code. That way special purpose widget like message bubbles can
 * easily be used in an editor.
 */

+/


