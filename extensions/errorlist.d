module extensions.errorlist;

import extension;

import controls.button;
import gui.event;
import gui.widgetfeature.constraintlayout;
import gui.widgetfeature.gridlayout;
import gui.widgetfeature.ninegridrenderer;
import gui.widgetfeature.textrenderer;
import gui.styledtext;
import gui.style;
import math.rect;
import math.region;
import math.smallvector;

import std.algorithm;
import std.conv;
import std.regex;
import core.signals;
import std.typecons;

class ErrorListWidget : BasicWidget!ErrorListWidget
{
	static WidgetID widgetID;
	
	private TextRenderer!BufferView textRenderer;
	private BufferView messagesBuffer;

	private int lines = 0;
	private int preferredEmptyBottomLines = 1;
	
	private enum MessageType : ubyte
	{
		messages = 1,
		warnings = 2,
		errors   = 4,
		all = ubyte.max
	}
	private ubyte _shownMessageTypes = 6;
	
	ToggleButton _messageToggle;
	private int _messageCount = 0;
	ToggleButton _errorToggle;
	private int _errorCount = 0;
	ToggleButton _warningToggle;
	private int _warningCount = 0;
	private Widget _progressWidget;

	private void enable(MessageType t)
	{
		_shownMessageTypes = _shownMessageTypes | t;
		rebuildMessages();
	}

	private void disable(MessageType t)
	{
		_shownMessageTypes = _shownMessageTypes & ~t;
		rebuildMessages();
	}

	private void set(MessageType t, bool isOn)
	{
		if (isOn)
			enable(t);
		else
			disable(t);
	}

	void showProgress(bool f)
	{
		_progressWidget.visible = f;
	}

	//enum Mode
	//{
	//    Hidden,
	//    Oneline,
	//    Compiling,
	//}

	//enum _classes = [["hidden"],["oneline"], ["twoline"], ["multiline"]];
	//
	//override protected @property const(string[]) classes() const pure nothrow @safe
	//{
	//    return _classes[mode];
	//}

	//override const(string[]) classes() const pure nothrow @safe { return null; }

	void append(string msg)
	{
		import std.conv;
		auto r = parseLine(msg.to!dstring);
		messagesBuffer.insert(r.lineText);
		adjustMessageTypeCounts(r);
		appendVisible(r);
	}

	private void adjustMessageTypeCounts(T)(T r)
	{
		final switch (r.type) with (MessageType)
		{
			case messages: 
				_messageToggle.text = text(++_messageCount, " messages");
				break;
			case warnings: 
				_warningToggle.text = text(++_warningCount, " warnings");
				break;
			case errors: 
				_errorToggle.text = text(++_errorCount, " errors");
				break;
			case all:
				break;
		}
	}

	private void appendVisible(T)(T r)
	{
		if (r.type & _shownMessageTypes)
			textRenderer.text.insert(r.lineText);
		lines++;
		if ((textRenderer.text.visibleLineCount - preferredEmptyBottomLines) < lines)
			textRenderer.text.scrollDown(); 
	}

	private void rebuildMessages(bool adjustCounts = false)
	{
		clearVisible();
		auto lc = messagesBuffer.lineCount;
		foreach (lineIdx; 0..lc)
		{
			auto txt = messagesBuffer.buffer.lineString(lineIdx);
			auto r = parseLine(txt.idup);
			if (adjustCounts)
				adjustMessageTypeCounts(r);
			appendVisible(r);
		}
	}

	void clear()
	{
		messagesBuffer.clear();
		clearVisible();
		_messageCount = 0;
		_messageToggle.text = text(_messageCount, " messages");
		_warningCount = 0;
		_warningToggle.text = text(_warningCount, " warnings");
		_errorCount = 0;
		_errorToggle.text = text(_errorCount, " errors");
		import extensions.statuspanel;
		auto p = cast(StatusPanel)getBasicWidget("statuspanel");
		if (p is null)
			return;

		p.mode = StatusPanel.Mode.hidden;
	}

	private void clearVisible()
	{
		textRenderer.text.clear();
		textRenderer.text.lineOffset = 0;
		lines = 0;
	}

	override void init()
	{
		name = "errorlist";
		//auto n = new NineGridRenderer("box");
		//n.color = Vec3f(0.25, 0.25, 0.25);
		//features ~= n;

		auto v = app.bufferViewManager.create();
		messagesBuffer = app.bufferViewManager.create();
		
		textRenderer = new TextRenderer!BufferView(v);
		auto styler = new ErrorListStyler(v);
		textRenderer.textStyler = styler;
		features ~= textRenderer;
		
		auto box = new Widget(this);
		box.name = "toggles";
		box.features ~= new GridLayout(GridLayout.Direction.row, 1);

		_progressWidget = new Widget();
		_progressWidget.name = "progress";
		_progressWidget.parent = box;
		_progressWidget.visible = false;

		auto b = new ToggleButton(text(0, " errors"));
		b.name = "toggleErrors";
		b.parent = box;
		b.zOrder = 99;
		_errorToggle = b;
		b.onToggled.connect(&toggleErrors);
		b = new ToggleButton(text(0, " warnings"));
		b.name = "toggleWarnings";
		b.parent = box;
		b.zOrder = 99;
		_warningToggle = b;
		b.onToggled.connect(&toggleWarnings);
		b = new ToggleButton(text(0, " messages"));
		b.name = "toggleMessages";
		b.parent = box;
		b.zOrder = 99;
		_messageToggle = b;
		b.onToggled.connect(&toggleMessages);

		// textRenderer = content(this, v);
		size = Vec2f(-1, 200);
		// size = Vec2f(10, 200);
		// alignToWindow(this, Anchor.BottomRight, rect.size);
		acceptsKeyboardFocus = true;
		lines = 0;
		zOrder = 50;
		app.scheduleWidgetPlacement(this, "statuspanel", RelativeLocation.inside);
		// TODO: Remove line below to enable errorlist
		//visible = false;
		loadSession();
		append("Console initialized");
		v.centerOnLine(v.lineCount-3);
	}

	private void toggleErrors(ToggleButton b)
	{
		set(MessageType.errors, b.isOn);
	}
	private void toggleWarnings(ToggleButton b)
	{
		set(MessageType.warnings, b.isOn);
	}
	private void toggleMessages(ToggleButton b)
	{
		set(MessageType.messages, b.isOn);
	}

	override void fini()
	{
		saveSession();
	}
	
	static class SessionData
	{
		string messages;
		ubyte shownMessageTypes;
	}
	
	private void loadSession()
	{
		auto s = loadSessionData!SessionData();
		if (s !is null)
		{
			_shownMessageTypes = s.shownMessageTypes;
			if (_shownMessageTypes & MessageType.messages)
				_messageToggle.isOn = true;
			if (_shownMessageTypes & MessageType.warnings)
				_warningToggle.isOn = true;
			if (_shownMessageTypes & MessageType.errors)
				_errorToggle.isOn = true;

			messagesBuffer.insert(s.messages.to!dstring);
			rebuildMessages(true);
		}
	}

	private void saveSession()
	{
		auto s = new SessionData();
		s.messages = messagesBuffer.buffer.toArray().to!string;
		s.shownMessageTypes = _shownMessageTypes;
		saveSessionData(s);
	}

	private void foundIssue(string filePath, string lineNum, string errorMsg, bool isError)
	{
		import extensions.statuspanel;

		auto p = cast(StatusPanel)getBasicWidget("statuspanel");
		if (p is null)
			return;

		if (isError)
			p.mode = StatusPanel.Mode.normal;
	}

	override EventUsed onMouseScroll(Event event)
	{
		// Scroll view
		int d = cast(int) event.scroll.y;
		if (d < 0)
		{
			foreach (i; 0..d*d)
				textRenderer.text.scrollDown();
		}
		else
		{
			foreach (i; 0..d*d)
				textRenderer.text.scrollUp();
		}
		return EventUsed.yes;
	}

	override EventUsed onMouseDoubleClick(Event event)
	{
		auto info = textRenderer.getGlyphAt(this, event.mousePos);
		if (info.isValid)
		{
			auto buf = textRenderer.text.buffer;
			auto line = buf.lineContaining(info.index);
			
			import std.regex;		
			auto ctr = regex(ErrorListStyler.errorLineRe, "mg");
			auto m = match(line, ctr);
			import std.stdio;
			if (!m.captures.empty)
			{
				writeln(m.captures[2]);
				BufferView bv = app.openFile(to!string(m.captures[1]));
				if (bv !is null)
				{
					auto pos = m.captures[2][1..$-1];
					auto sp = std.algorithm.findSplit(pos, ",");
					int errorLine = 0;
					int errorColumn = 0;
					if (sp[1].empty)
						errorLine = to!int(pos) - 1; // lines are 0 indexed in buffer but 1 indexed in error message
					else
					{
						errorLine = to!int(sp[0]) - 1;
						errorColumn = to!int(sp[2]) - 1;
					}
					int errorStartOfLineIndex = bv.buffer.startAtLineNumber(errorLine);
					bv.cursorPoint = errorStartOfLineIndex + errorColumn;
					bv.centerOnLine(errorLine);
				}
			}

			writeln(line);
		}
		return EventUsed.yes;
	}

	private auto parseLine(dstring str)
	{
		struct ParsedLine
		{
			dstring lineText;
			MessageType type;
			dstring message;
			dstring file;
			int line;
			int column;
		}

		ParsedLine result = ParsedLine(str ~ "\n"d, MessageType.messages);

		import std.regex;		
		auto ctr = regex(ErrorListStyler.errorLineRe, "mg");
		auto m = match(str, ctr);

		if (!m.captures.empty)
		{
			result.message = m.captures[3];
			result.file = m.captures[1];
			if (result.message.startsWith("Error:"))
				result.type = MessageType.errors;
			else if (result.message.startsWith("Warning:"))
				result.type = MessageType.warnings;

			auto pos = m.captures[2][1..$-1];
			auto sp = std.algorithm.findSplit(pos, ",");
			int errorLine = 0;
			int errorColumn = 0;
			if (sp[1].empty)
				result.line = to!int(pos) - 1; // lines are 0 indexed in buffer but 1 indexed in error message
			else
			{
				result.line = to!int(sp[0]) - 1;
				result.column = to!int(sp[2]) - 1;
			}
		}
		return result;
	}

	override void update()
	{
		super.update();
		import std.stdio;
		//writeln("update");
	}

	override void draw()
	{
		super.draw();
		import std.stdio;
		//writeln("draw");
	}
}


class ErrorListStyler : TextStyler
{
	enum DStyle
	{
		other = 0,
		lineNumber = 1,
		error = 2,
		warning = 3,
	};

	enum errorLineRe = r"(\S*?)(\([\d,]+\)): ((?:Error|Warning).*)"d;

	this(BufferView text)
	{
		super();
		text.onInsert.connect(&textInsertedCallback);
		text.onRemove.connect(&textRemovedCallback);
	}

	override protected void styleBufferViewRegion(Region r, BufferView text)
	{
		import std.array;
		assert(r.a >= 0 && r.a <= text.length);
		assert(r.b >= 0 && r.b <= text.length);
		auto buf = array(text[r.a .. r.b]);

		size_t lastEndIdx = 0;
		size_t offset = r.a;

		import std.regex;		
		auto ctr = regex(errorLineRe, "mg");

		foreach (m; match(buf, ctr))
		{
			if (m.empty)
				continue;
			auto begin = m.pre.length;

			auto filePath = m.captures[1];
			auto end = begin + filePath.length;
			if (begin != lastEndIdx)
				_regionSet.merge(offset + lastEndIdx, offset + begin, DStyle.other);
			
			_regionSet.set(offset + begin, offset + end, DStyle.lineNumber);			

			auto lineInFile = m.captures[2];
			begin = end;
			end = begin + lineInFile.length;
			_regionSet.set(offset + begin, offset + end, DStyle.error);			
			
			auto message = m.captures[3];
			begin = end + 1;
			end = begin + message.length;
			_regionSet.set(offset + begin, offset + end, DStyle.other);
			lastEndIdx = end;
		}

		if (lastEndIdx != r.b)
			_regionSet.set(offset + lastEndIdx, r.b, DStyle.other);

		onChanged.emit();
	}

	override string styleIDToName(int id)
	{
		DStyle styleID = cast(DStyle)id;
		final switch(styleID)
		{
			case DStyle.other:
				return "errorlist-other";
			case DStyle.lineNumber:
				return "errorlist-line-number";
			case DStyle.error:
				return "errorlist-error";
			case DStyle.warning:
				return "errorlist-warning";
		}
	}
}
