module extensions.errorlist;

import extensionapi;
mixin registerCommands;

import controls.button;
import dccore.buffer : InvalidIndex;
import gui.event;
import gui.layout.constraintlayout;
import gui.layout.gridlayout;
import gui.widgetfeature.ninegridrenderer;
import gui.widgetfeature.textrenderer;
import gui.styledtext;
import gui.style;
import gui.text;
import math.rect;
import math.region;
import math.smallvector;
import math.smallmatrix;

import std.algorithm;
import std.array : empty;
import std.conv;
import std.regex;
import std.string : tr;
import dccore.signals;
import std.typecons;

class ErrorListWidget : BasicWidget
{
	enum initializeMessage = "Console initialized";

	static WidgetID widgetID;

	private TextRenderer!BufferView textRenderer;
    private int currentIssueLine = int.min;
	private int lines = 0;
	private int preferredEmptyBottomLines = 1;

    // region set name -> decoration
    RegionSetDecoration[string] decorations;

	private enum MessageType : ubyte
	{
		message = 1,
		warning = 2,
		error   = 4,
        test    = 8,
        all = ubyte.max
	}
	private ubyte _shownMessageTypes = 6;

	struct Message
	{
		MessageType type;
		string message;
		string file;
		int line;
		int column;
		Object owner; // optional owner object
        int ownerID;  // optional id set by the owner
	}

	private Message[] messages;

	private struct ToggleInfo
    {
		ToggleButton toggle;
		int messageCount;
        string name;
	    void updateToggleText()
        {
	        toggle.text = text(messageCount, " ", name);
        }
    }

    private ToggleInfo[4] _toggles;

    private ToggleInfo* getToggle(MessageType t)
    {
        switch (t)
        {
	        case MessageType.message:
	            return &_toggles[0];
	        case MessageType.warning:
	            return &_toggles[1];
	        case MessageType.error:
	            return &_toggles[2];
	        case MessageType.test:
	            return &_toggles[3];
	        default:
	            return &_toggles[0];
        }
    }

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

	void append(string msg, Object owner = null, int ownerID = -1)
	{
		import std.conv;
		auto r = parseMessage(msg);
        append(r);
    }

	void append(Message m)
    {
		messages ~= m;
		ToggleInfo* t = getToggle(m.type);
        t.messageCount++;
        t.updateToggleText();
		appendVisible(m);
	}

	void removeMessages(Object owner, int ownerID)
    {
		messages = messages.remove!(a => a.owner is owner && a.ownerID == ownerID);
		rebuildMessages();
    }

	Message getMessageByLine(int line)
    {
		int visibleMessageIndex = 0;
        foreach (ref Message m; messages)
        {
            if (m.type & _shownMessageTypes)
            {
				if (visibleMessageIndex == line)
	                return m;
                visibleMessageIndex++;
            }
        }

        return Message.init;
    }

	private void appendVisible(T)(T r)
	{
		if (r.type & _shownMessageTypes)
        {
			textRenderer.text.insert(r.message);
		    lines++;
        }
		if ((textRenderer.text.visibleLineCount - preferredEmptyBottomLines) < lines)
			textRenderer.text.scrollDown();
	}

	private void rebuildMessages()
	{
		clearVisible();
		foreach (ref t; _toggles)
			t.messageCount = 0;

		foreach (ref Message message; messages)
        {
			getToggle(message.type).messageCount++;
			appendVisible(message);
        }

		foreach (ref t; _toggles)
	        t.updateToggleText();
	}

	void clear()
	{
		messages.length = 0;
		clearVisible();

		foreach (ref t; _toggles)
        {
	        t.messageCount = 0;
            t.updateToggleText();
        }

		import extensions.statuspanel;
		auto p = get!StatusPanel("statuspanel");
		if (p is null)
			return;

		p.mode = StatusPanel.Mode.hidden;
	}

	private void clearVisible()
	{
        currentIssueLine = int.min;
		textRenderer.text.lineOffset = 0;
        textRenderer.text.clear();
		lines = 0;
	}

    final void setRegionSetStyle(string name, string cssClassName = null, bool mergeBorders = false)
    {
        if (cssClassName is null)
            cssClassName = name;

        RegionSetDecoration* d = name in decorations;
        RegionSetDecoration rsd = null;
        if (d is null)
        {
            rsd = new RegionSetDecoration(cssClassName);
            decorations[name] = rsd;
        }
        else
        {
            rsd = *d;
            rsd.classNames.length = 0;
            rsd.classNames ~= cssClassName;
        }
        rsd.mergeBorders = mergeBorders;
    }

    override void drawFeatures()
    {
		auto bg = background;
		if (bg !is null)
			bg.draw(this);

		// Draw features
		foreach (f; features)
		{
			if (f !is textRenderer)
                f.draw(this);
		}

        textRenderer.updateLayout(this);

		drawDecorations();

        textRenderer.draw(this);
    }

    private void drawDecorations()
    {
        // TODO: get selection regionset directly when it becomes a region set
        auto bv = textRenderer.text;
        bv.getRegionSet("selection").clear(bv.selection.normalized());

        auto sheet = window.styleSheet;

        foreach (k, d; decorations)
        {
            auto rs = bv.getRegionSet(k);
            if (rs !is null)
            {
                d.styleSheet = sheet;
                d.textLayout = textRenderer.layout;
                d.regions = rs;
                d.update(bv.bufferStartOffset, this.size);
            }
        }

        Mat4f transform;
		getStyledScreenToWorldTransform(transform);
		Mat4f trx = window.MVP * transform;

        string[] removeDecors;

        foreach (k, d; decorations)
        {
            d.draw(trx);
        }
    }

	override void init()
	{
		name = "errorlist";
		//auto n = new NineGridRenderer("box");
		//n.color = Vec3f(0.25, 0.25, 0.25);
		//features ~= n;

		auto v = app.bufferViewManager.create();

		textRenderer = new TextRenderer!BufferView(v);
		auto styler = new ErrorListStyler(v, this);
		textRenderer.textStyler = styler;
		features ~= textRenderer;

        setRegionSetStyle("error-highlight");

        layout = null;

		auto box = new Widget(this);
		box.name = "toggles";
		box.layout = new GridLayout(GridLayout.Direction.row, 1);

		_progressWidget = new Widget();
		_progressWidget.name = "progress";
		_progressWidget.parent = box;
		_progressWidget.visible = false;

        ToggleButton setupToggle(string name, string postfixText, MessageType type, void delegate(ToggleButton b) toggleFunc)
        {
            auto b = new ToggleButton(text(0, " ", postfixText));
            b.name = name;
            b.zOrder = 99;
            ToggleInfo* info = getToggle(type);
            info.toggle = b;
            info.name = postfixText;
            b.onToggled.connect(toggleFunc);
            return b;
        }

        setupToggle("toggleErrors", "errors", MessageType.error, &toggleErrors).parent = box;
        setupToggle("toggleTests", "tests", MessageType.test, &toggleTests).parent = box;

		auto b = new ToggleButton(text(0, " warnings"));
		b.name = "toggleWarnings";
		b.parent = box;
		b.zOrder = 99;
		with (getToggle(MessageType.warning))
        {
            toggle = b;
            name = "warnings";
        }

		b.onToggled.connect(&toggleWarnings);
		b = new ToggleButton(text(0, " messages"));
		b.name = "toggleMessages";
		b.parent = box;
		b.zOrder = 99;
		with (getToggle(MessageType.message))
        {
            toggle = b;
            name = "messages";
        }
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
		append(initializeMessage);
		v.centerOnLine(v.lineCount-3);
	}

	private void toggleErrors(ToggleButton b)
	{
		set(MessageType.error, b.isOn);
	}
	private void toggleWarnings(ToggleButton b)
	{
		set(MessageType.warning, b.isOn);
	}
	private void toggleMessages(ToggleButton b)
	{
		set(MessageType.message, b.isOn);
	}

	private void toggleTests(ToggleButton b)
	{
		set(MessageType.test, b.isOn);
	}

	override void fini()
	{
		saveSession();
	}

	static class SessionData
	{
		Message[] messages;
		ubyte shownMessageTypes;
	}

	private void loadSession()
	{
		import std.string;
        auto s = loadSessionData!SessionData();
		if (s !is null)
		{
			_shownMessageTypes = s.shownMessageTypes;
			if (_shownMessageTypes & MessageType.message)
				getToggle(MessageType.message).toggle.isOn = true;
			if (_shownMessageTypes & MessageType.warning)
				getToggle(MessageType.warning).toggle.isOn = true;
			if (_shownMessageTypes & MessageType.error)
				getToggle(MessageType.error).toggle.isOn = true;
			if (_shownMessageTypes & MessageType.test)
				getToggle(MessageType.test).toggle.isOn = true;

			/*
			// collapse initialize messages
			messages.reserve(s.messages.length);
            foreach (idx, m; s.messages)
            {
                if (m.message.chomp == initializeMessage && idx != 0 && s.messages[idx-1].message.chomp == initializeMessage)
	                continue;
                messages ~= m;
            }

            if (messages.length != 0 && messages[$-1].message.chomp == initializeMessage)
                messages.length = messages.length - 1;
			*/
			rebuildMessages();
		}
	}

	private void saveSession()
	{
		auto s = new SessionData();
		//s.messages = messages;
		s.shownMessageTypes = _shownMessageTypes;
		saveSessionData(s);
	}

	private void foundIssue(string filePath, string lineNum, string errorMsg, bool isError)
	{
		import extensions.statuspanel;

		auto p = get!StatusPanel("statuspanel");
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
		auto posInfo = textRenderer.getGlyphAt(this, event.mousePos);
		if (posInfo.isValid)
		{
			auto buf = textRenderer.text.buffer;
			auto line = buf.lineNumberAt(posInfo.index);
			selectIssueHelper(line);

//	         auto info = getMessageByLine(line);
//
//            if (info.file !is null)
//			{
//                textRenderer.getOrCreateHighlighter("error-highlight").regions.clear();
//				BufferView bv = app.openFile(to!string(info.file));
//				if (bv !is null)
//				{
//					int errorStartOfLineIndex = bv.buffer.startAtLineNumber(info.line);
//					bv.cursorPoint = errorStartOfLineIndex + info.column;
//					bv.centerOnLine(info.line);
//                }
//                auto issueListBufferView = textRenderer.text;
//                issueListBufferView.dirty = true;
//                currentIssueLine = buf.lineNumberAt(posInfo.index);
//                auto ends = buf.lineEndsAt(posInfo.index);
//                if (ends[0] != InvalidIndex)
//                    textRenderer.getOrCreateHighlighter("error-highlight").regions.set(ends[0], ends[1]);
//			}
		}
		return EventUsed.yes;
	}

    void selectNextIssue()
    {
        int checkIssueLine = currentIssueLine == int.min ? 0 : currentIssueLine;
        foreach (idx; 0 .. textRenderer.text.lineCount)
        {
            checkIssueLine = (checkIssueLine + 1) % textRenderer.text.lineCount;
            if (selectIssueHelper(checkIssueLine))
	            break;
//            {
//                currentIssueLine = checkIssueLine;
//                auto ends = textRenderer.text.buffer.lineEndsForLineNumber(currentIssueLine);
//                textRenderer.getOrCreateHighlighter("error-highlight").regions.clear();
//                if (ends[0] != InvalidIndex)
//                    textRenderer.getOrCreateHighlighter("error-highlight").regions.set(ends[0], ends[1]);
//                textRenderer.text.viewOnLinePaged(currentIssueLine);
//                textRenderer.text.dirty = true;
//                break;
//            }
        }

    }

    void selectPreviousIssue()
    {
        if (textRenderer.text.lineCount == 0)
            return;

        int checkIssueLine = currentIssueLine == int.min ? 0 : currentIssueLine;

        foreach (idx; 0 .. textRenderer.text.lineCount )
        {
            checkIssueLine = (textRenderer.text.lineCount + checkIssueLine - 1) % textRenderer.text.lineCount;
            if (selectIssueHelper(checkIssueLine))
				break;
//            {
//                currentIssueLine = checkIssueLine;
//                auto ends = textRenderer.text.buffer.lineEndsForLineNumber(currentIssueLine);
//                textRenderer.getOrCreateHighlighter("error-highlight").regions.clear();
//                if (ends[0] != InvalidIndex)
//                    textRenderer.getOrCreateHighlighter("error-highlight").regions.set(ends[0], ends[1]);
//                textRenderer.text.viewOnLinePaged(currentIssueLine);
//                textRenderer.text.dirty = true;
//                break;
//            }
        }
    }

    private bool selectIssueHelper(int lineNum)
    {
        auto info = getMessageByLine(lineNum);

        if (info.file !is null)
        {
            BufferView bv = app.openFile(to!string(info.file));
            if (bv !is null)
            {
                int errorStartOfLineIndex = bv.buffer.startAtLineNumber(info.line);
                bv.cursorPoint = errorStartOfLineIndex + info.column;
                bv.centerOnLine(info.line, true);
            }

            currentIssueLine = lineNum;
            auto ends = textRenderer.text.buffer.lineEndsForLineNumber(currentIssueLine);
            auto rs = textRenderer.text.getRegionSet("error-highlight");
            rs.clear();
            if (ends[0] != InvalidIndex)
                rs.set(ends[0], ends[1]);

            // TODO: Do like TextEditor for setting regions render styles

                       // textRenderer.getOrCreateHighlighter("error-highlight").regions.set(ends[0], ends[1]);
            textRenderer.text.centerOnLine(currentIssueLine, true);
            textRenderer.text.dirty = true;

            return true;
        }
        else
        {
            return false;
        }
    }

	static auto parseMessage(const(char)[] str)
	{
		Message result = Message(MessageType.message, (str ~ "\n").idup);

		import std.regex;
		auto ctr = regex(ErrorListStyler.errorLineRe, "mg");
		auto m = matchFirst(result.message, ctr);

		if (!m.empty)
		{
			auto messageText = m.captures[3];
			result.file = m.captures[1].tr(r"\", "/");
			if (messageText.startsWith("Error:"))
				result.type = MessageType.error;
			else if (messageText.startsWith("Warning:"))
				result.type = MessageType.warning;

			auto pos = m.captures[2][1..$-1];
			auto sp = std.algorithm.findSplit(pos, ",");
			if (sp[1].empty)
				result.line = to!int(pos) - 1; // lines are 0 indexed in buffer but 1 indexed in error message
			else
			{
				result.line = to!int(sp[0]) - 1;
				result.column = to!int(sp[2]) - 1;
			}
			result.message  = text(result.file, "(", pos, "): ", messageText, "\n");
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

@Shortcut("<f8>")
void issueNext(Application app)
{
    ErrorListWidget w = cast(ErrorListWidget)app.getWidget("errorlist");
    if (w is null)
        return;
    w.selectNextIssue();
}

@Shortcut("<shift> + <f8>")
void issuePrevious(Application app)
{
    ErrorListWidget w = cast(ErrorListWidget)app.getWidget("errorlist");
    if (w is null)
        return;
    w.selectPreviousIssue();
}

class ErrorListStyler : TextStyler
{
	enum DStyle
	{
		other = 0,
		otherHighlighted = 1,
		lineNumber = 2,
        fileName = 3,
		error = 4,
		warning = 5,
	};

	enum errorLineRe = r"(\S*?)(\([\d,]+\)): ((?:Error|Warning)?.*)";

    private ErrorListWidget _errorListWidget;

	this(BufferView text, ErrorListWidget w)
	{
		super();
        _errorListWidget = w;
		text.onChanged.connect(&textChangedCallback);
	}

	override protected void styleBufferViewRegion(Region r, BufferView text)
	{
		import std.array;
		assert(r.a >= 0 && r.a <= text.length);
		assert(r.b >= 0 && r.b <= text.length);
		auto buf = array(text[r.a .. r.b]);

		int lastEndIdx = 0;
		int offset = r.a;

		import std.regex;
		auto ctr = regex(errorLineRe, "mg");

        import dccore.buffer;
        TextBuffer textBuf = text.buffer;

		foreach (m; match(buf, ctr))
		{
			if (m.empty)
				continue;
			auto begin = cast(int)m.pre.length;

			auto filePath = m.captures[1];
			auto end = begin + cast(int)filePath.length;
			if (begin != lastEndIdx)
				_regionSet.merge(offset + lastEndIdx, offset + begin, DStyle.other);

			_regionSet.set(offset + begin, offset + end, DStyle.fileName);

            int issueLineNumber = textBuf.lineNumberAt(offset + begin);

			auto lineInFile = m.captures[2];
			begin = end;
			end = begin + cast(int)lineInFile.length;
			_regionSet.set(offset + begin, offset + end, DStyle.lineNumber);

			auto message = m.captures[3];
			begin = end + 2; // ": ".length == 2
			end = begin + cast(int)message.length;

            DStyle otherStyle = DStyle.other;
			auto msg = _errorListWidget.getMessageByLine(issueLineNumber);
            switch (msg.type)
            {
                case ErrorListWidget.MessageType.message:
	                otherStyle = DStyle.other;
	                break;
                case ErrorListWidget.MessageType.warning:
	                otherStyle = DStyle.otherHighlighted;
	                break;
                case ErrorListWidget.MessageType.error:
	                otherStyle = DStyle.otherHighlighted;
	                break;
				default:
	                otherStyle = DStyle.other;
	                break;
			}

            _regionSet.set(offset + begin, offset + end, otherStyle);
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
			case DStyle.otherHighlighted:
				return "errorlist-other-highlighted";
			case DStyle.lineNumber:
				return "errorlist-line-number";
			case DStyle.fileName:
				return "errorlist-file-name";
			case DStyle.error:
				return "errorlist-error";
			case DStyle.warning:
				return "errorlist-warning";
		}
	}
}
