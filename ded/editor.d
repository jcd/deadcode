module editor;

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

/* TODO
 * scrolling
 * saving
 * highlighting
 * building
 * packaging
 * completion
 */
class Editor : IWidgetFeature
{
	private
	{
		EditorController controller;
	}
	
	this(TextGapBuffer buffer, SourceCodeView view)
	{
		this.controller = new EditorController(buffer, view);
	}

	bool onEvent(Event event, ref Widget widget)
	{
		if (widget.id != Widget.keyboardFocusWidget)
			return false;

		// TODO: isn't behavior just a event -> edit mapping e.g. command
		EditorBehavior.current.onEvent(event, controller);
		return false;
	}
	
	void onUpdate(ref Widget widget)
	{
	}
	
	void onDraw(ref Widget widget)
	{
		//if (controller.dirty)
		{
			controller.view.onDraw(widget);
			controller.dirty = false;
		}
	}	
}

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

class EditorController
{	
	static EditorController _current;
	static @property {
		EditorController current()
		{
			return _current;
		}
		void current(EditorController c)
		{
			_current = c;
		}
	}	
			
	TextGapBuffer buffer;
	BufferInfo bufferInfo;
	SourceCodeView view;
	bool dirty;
	
	this(TextGapBuffer buffer, SourceCodeView view)
	{
		if (_current is null)
			_current = this;
		this.buffer = buffer;
		this.bufferInfo = BufferInfo( null, false );
		this.view = view;
		view.buffer = buffer; // TODO:
		dirty = true;
	}
				
	/** Step history when doing redo/undo
	 *  
	 * Params:
	 * steps number of steps to walk in history. Negative values will 
	 * undo actions done on this controller.
	 */
	void stepHistory(int steps)
	{
		
	}
	
	private void insertInternal(dchar item, uint index = uint.max)
	{
		buffer.insert(item, index);
		dirty = true;
//		bufferInfo.undoStack ~= UndoStep(fdfdasdf);
	}
	
	private void insertInternal(const(dchar)[] items, uint index = uint.max)
	{
		buffer.insert(items, index);
		dirty = true;
//		bufferInfo.undoStack ~= UndoStep(fdfdasdf);
	}

	private void removeInternal(int count, int index = uint.max)
	{
		dirty = true;
		buffer.remove(count, index);		
	}

	void insert(dchar item, uint index = uint.max)
	{
		if (index == uint.max)
			index = view.cursorPoint;
		insertInternal(item, index);
		view.cursorPoint = buffer.editPoint;
	}

	void insert(const(dchar)[] items, uint index = uint.max)
	{
		if (index == uint.max)
			index = view.cursorPoint;
		insertInternal(items, index);
		view.cursorPoint = buffer.editPoint;
	}

	void remove(int count, int index = uint.max)
	{
		if (index == uint.max)
			index = view.cursorPoint;
		removeInternal(count, index);		
		view.cursorPoint = buffer.editPoint;
	}
	
	void clear()
	{
		buffer.clear();
		view.reset();
		view.cursorPoint = buffer.editPoint;		
	}
	
	void cursorLeft(uint c = 1) 
	{
		view.cursorPoint = buffer.charsOffset(view.cursorPoint, -c);
	}	

	void cursorRight(uint c = 1)
	{
		view.cursorPoint = buffer.charsOffset(view.cursorPoint, c);
	}

	void cursorUp(uint c = 1) 
	{
		view.cursorPoint = buffer.linesOffset(view.cursorPoint, -c, view.preferredColumn);
	}
	
	void cursorDown(uint c = 1)
	{
		view.cursorPoint = buffer.linesOffset(view.cursorPoint, c, view.preferredColumn);
	}
	
	void scrollUp()
	{
		view.bufferOffset = buffer.startOfLine(buffer.endOfPreviousLine(view.bufferOffset));
		if (view.lineOffset > 0)
			view.lineOffset -= 1;
	}

	void scrollDown()
	{
		view.bufferOffset = buffer.startOfNextLine(view.bufferOffset);
		if (view.lineOffset < (buffer.lineCount - view.rectLines))
			view.lineOffset += 1;
	}

	void cursorToBeginningOfLine()
	{
		view.cursorPoint = buffer.startOfLine(view.cursorPoint);
	}
	
	void cursorToEndOfLine()
	{
		view.cursorPoint = buffer.endOfLine(view.cursorPoint);
	}

	private uint indexWordBefore()
	{
		uint endOfWord = buffer.findOneOfReverse(view.cursorPoint - 1, buffer.WORDCHARS);
		uint target = 0;
		if (endOfWord != uint.max)
		{
			target = endOfWord;
			uint startOfWord = buffer.findOneNotOfReverse(endOfWord, buffer.WORDCHARS);
			target = 0;
			if (startOfWord != uint.max)
				target = startOfWord + 1;
		}
		return target;
	}
	
	void cursorToWordBefore()
	{
		view.cursorPoint = indexWordBefore();
	}
	
	void deleteWordBefore()
	{ 
		auto deleteTo = indexWordBefore();
		removeInternal(view.cursorPoint - deleteTo, deleteTo);
		view.cursorPoint = deleteTo;
	}
	
	private uint indexWordAfter()
	{
		uint startOfWord = buffer.findOneOf(view.cursorPoint, buffer.WORDCHARS);
		uint target = buffer.length;
		if (startOfWord != uint.max)
		{
			target = startOfWord;
			uint endOfWord = buffer.findOneNotOf(startOfWord, buffer.WORDCHARS);
			if (endOfWord != uint.max)
				target = endOfWord;
		}
		return target;
	}

	void cursorToWordAfter()
	{
		view.cursorPoint = indexWordAfter();
	}
	
	void deleteWordAfter()
	{
		auto deleteTo = indexWordAfter();
		removeInternal(deleteTo - view.cursorPoint, view.cursorPoint);
	}

	void deleteToEndOfLine()
	{
		uint eol = buffer.endOfLine(view.cursorPoint);
		if (eol == view.cursorPoint)
		{
			eol = buffer.startOfNextLine(view.cursorPoint);
		}
		removeInternal(eol - view.cursorPoint, view.cursorPoint);
	}
}

/** A SourceCodeEditor contains text and widgets for editing and displaying source code
 *
 * The display of the source code is done through a root widget associated with the
 * SourceCodeEditor. This widget in turn contains widgets for presenting the different
 * part of the source code. That way special purpose widget like message bubbles can
 * easily be used in an editor.
 */
class SourceCodeView
{
	TextGapBuffer buffer;
	uint bufferOffset; // char offset into the buffer from where to draw
	uint lineOffset;   // line offset into the buffer from where to draw. Could be derived from bufferOffset.
	uint rectLines;    // Number of lines to draw
	
	private uint _cursorPoint;
	private uint _cursorPreferredColumn;	
	
	Font font;
	Rectf padding;
	bool wordWrap;
	EditorBehavior behavior; // emacs, vi,...	
		
	private
	{
		Model textModel;
		Model cursorModel;
		int xx;
	}	
	
	this(Font font)
	{
		this.font = font;
		behavior = new EmacsBehavior();
		
		// Text model
		Buffer vertexBuf = Buffer.create();
		Buffer colorBuf = Buffer.create();
		Buffer vertColBuf = Buffer.create();
		textModel = new Model();
		textModel.mesh = Mesh.create();
		textModel.mesh.setBuffer(vertexBuf, 3, 0);
		textModel.mesh.setBuffer(colorBuf, 2, 1);	
		textModel.mesh.setBuffer(vertColBuf, 3, 2);	
		
		Material mat = new Material();
		mat.shader = Material.builtIn.shader;
		mat.texture = font.fontMap;
		textModel.material = mat;
		
		// Cursor model
		cursorModel = createWindowQuad(Rectf(0, 0, font.fontWidth * 0.25, font.fontLineSkip), Material.builtIn);
		
		padding = Rectf(Vec2f(20,20), Vec2f(20,20));
		wordWrap = false;
		xx = 0;
	}
	
	void reset()
	{
		bufferOffset = 0;
		lineOffset = 0;
		rectLines = 0;
		_cursorPoint = 0;
		_cursorPreferredColumn = 0;
	}
	
	@property uint cursorPoint() const pure nothrow
	{
		return _cursorPoint;
	}
	
	@property void cursorPoint(uint v) 
	{
		assert(buffer !is null && v >= 0 && v <= buffer.length, "Cursor out of range");
		_cursorPoint = v;
		setPreferredColumnFromIndex(v);
	}

	@property uint preferredColumn() const pure nothrow
	{
		return _cursorPreferredColumn;
	}
	
	void setPreferredColumnFromIndex(uint index = uint.max) 
	{
		if (index == uint.max)
			index = _cursorPoint;
		//assert(buffer !is null && index >= 0 && index < buffer.length, text("Index out of bounds 0 <= ", index , " < ", buffer.length));
		_cursorPreferredColumn = index - buffer.startOfLine(index);
	}

	void onDraw(ref Widget widget)
	{
		if (buffer is null) return;
		
		xx++;
		// Create child widgets for the visible parts of the buffer
		import std.conv;
		import std.array;
		auto texture = widget.activeStyle.model.material.texture;
		//texture.clear();
		
		auto app = appender!string();
		for (int j = 0; j < 45; j++)
		{
			for (int i= 0; i < 15;i++)
				app.put("abcdeXM ");
			app.put('\n');
		}
		
		textModel.transform = widget.activeStyle.model.transform;

		Vec2f ppad = Vec2f(padding.pos.x, -padding.pos.y);
		Vec2f wpad = Vec2f(widget.rect.size.x - padding.pos.x - padding.size.x, padding.pos.y + padding.size.y - widget.rect.size.y);
		Rectf r = Rectf(Window.active.pixelSizeToWorld(ppad), Window.active.pixelSizeToWorld(wpad));
//		setTextMesh(app.data, font, model.mesh, r, false);
		
		rectLines = cast(uint)(widget.rect.h / font.fontLineSkip);
		auto toks = buildKeywordTokens();
					
		//toks ~= Token(0,10,Vec3f(1f,0f,0f));
		Vec2f pointer;
		Vec2f poi = textModel.setTextMesh(buffer[bufferOffset..buffer.length], toks, font, textModel.mesh, r, cursorPoint - bufferOffset, pointer, wordWrap);
		
		textModel.draw();

		cursorModel.transform = widget.activeStyle.model.transform * Mat4f.makeTranslate(Vec3f(poi.x, poi.y + Window.active.pixelHeightToWorld(font.fontLineSkip), 0f));
		cursorModel.draw();
		

		/*
		texture.renderText(Rectf(0,0, widget.rect.w, widget.rect.h), font, 
			text("abcdefghijklmnopq ", xx, app.data));
			//" yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfk kldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfkl yeah fdsa fjdklsa;jfkldsajflk;djafkld;jafkld;jafkl;dsajfk l"));		
	
		 */
	}
	
	Heap buildKeywordTokens()
	{
		Token[dstring] templates;
		// = { 
//			"alias" = Token(0, 0, Vec3f(0,1,0))
		//};
		
		// TODO: use ctRegex
		enum decls = [ "alias"d, "auto", "assert", "class", "const", "enum", "extern", "for", "if", "import", "module", "new", "nothrow"
			"private", "public", "pure", "return", "safe", "scope", "static", "struct", "template", "this", "union", "unittest", "version",
			"while" ];
		enum types = [ "byte"d, "char", "dchar", "int", "long", "short", "ubyte", "uint", "ulong", "ushort", "void", "wchar" ];
		dstring re = "(";
		dstring delim = "";
		foreach (tt; decls)
		{
			re ~= delim;
			re ~= tt;
			delim = "|";
		}
		foreach (tt; types)
		{
			re ~= delim;
			re ~= tt;
		}
		re ~= ")";
		
		import std.regex;		
		auto ctr = regex(re, "mg");
		
		foreach (d; decls)
			templates[d] = Token(0, 0, Vec3f(0.3,0.3,1));
		foreach (t; types)
			templates[t] = Token(0, 0, Vec3f(0.3,1,0.3));
		
		dstring[] names = templates.keys();
		Token[] toks;
		
		auto buf = array(buffer[bufferOffset..buffer.length]);
		
		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			t.begin = m.pre.length;
			t.end = t.begin + m.hit.length;
			toks ~= t;

		}

		Heap h;
		h.acquire(toks);
		return h;
	}
	
	
	/* Update and create sub-widgets as necessary
	 */
	//void onUpdate(ref Widget widget)
	//{
	//}
}


