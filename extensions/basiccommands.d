module extensions.basiccommands;

import extensions;

//import application;
import core.buffer;
import core.bufferview;
import core.command;
import core.commandparameter;
//import application;
static import std.conv;

// move imports into func when compiler does break on it
import std.algorithm;

private enum getBufferOrReturn = q{
	auto b = app.currentBuffer;
	if (b is null)
		return;
};

private string createCmd(string name, string desc)
{
	string res = `cmgr.create("edit.` ~ name ~ `", "Move cursor to beginning of current line", null, delegate(CommandParameter[] data) {
		mixin(getBufferOrReturn);
		b.` ~ name ~ `();
	});`;
	return res;
}

import extensions;
alias a = RegisterExtension!BasicCommands;

class BasicCommands : Extension
{
    override @property string name() { return "base.commands"; }

    override void init()
    {

        CommandManager cmgr = app.commandManager;

	    // The default emacs key mappings
	    cmgr.create("edit.clearBuffer", "Scroll editor window one page down",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto dl = "Hello world I am fine right now";
		    b.clear(dl);
	    });

	    mixin(createCmd("cursorToBeginningOfLine", "Move cursor to beginning of current line"));
	    mixin(createCmd("cursorToEndOfLine", "Move cursor to end of current line"));
	    mixin(createCmd("cursorToWordBefore", "Move cursor to word before cursor"));
	    mixin(createCmd("cursorToWordAfter", "Move cursor to word after cursor"));

	    mixin(createCmd("selectToBeginningOfLine", "Expand selection to beginning of current line"));
	    mixin(createCmd("selectToEndOfLine", "Expand selection cursor to end of current line"));
	    mixin(createCmd("selectToWordBefore", "Expand selection to word before cursor"));
	    mixin(createCmd("selectToWordAfter", "Expand selection to word after cursor"));

	    mixin(createCmd("deleteToWordBefore", "Delete word before cursor"));
	    mixin(createCmd("deleteToWordAfter", "Delete word after cursor"));
	    mixin(createCmd("deleteToEndOfLine", "Delete line part after cursor"));
	    mixin(createCmd("clear", "Clear buffer"));
	    mixin(createCmd("undo", "Undo buffer"));
	    mixin(createCmd("redo", "Redo buffer"));
	    mixin(createCmd("copy", "Copy selection"));
	    mixin(createCmd("paste", "Paste entry from copy buffer"));
	    mixin(createCmd("pasteCycle", "Paste previous entry in instead of the last one just pasted copy buffer"));
	    mixin(createCmd("cut", "Cut selection"));

	    cmgr.create("edit.cursorToCharBefore", "Move cursor to char before cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    b.cursorLeft(1);
	    });

	    cmgr.create("edit.cursorToCharAfter", "Move cursor to char after cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    b.cursorRight(1);
	    });

	    cmgr.create("edit.cursorToCharAbove", "Move cursor to char before cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    ctrl.cursorUp(1);
		    int lineNum = ctrl.lineNumber;
		    //std.stdio.writeln("key down ", lineNum, " ", ctrl.lineOffset," ", ctrl.visibleLineCount /*, " ", ctrl.buffer.lineCount*/);
		    if (lineNum < ctrl.lineOffset)
			    ctrl.scrollUp();
	    });

	    cmgr.create("edit.scrollUp", "Scroll view up one line",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    ctrl.scrollUp(1);
	    });

	    cmgr.create("edit.scrollDown", "Scroll view down one line",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    ctrl.scrollDown(1);
	    });

	    cmgr.create("edit.cursorToCharBelow", "Move cursor to char after cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    ctrl.cursorDown();
		    int lineNum = ctrl.lineNumber;
		    if (lineNum > (ctrl.lineOffset + ctrl.visibleLineCount))
			    ctrl.scrollDown();
	    });

	    cmgr.create("edit.selectToCharBefore", "Select to char before cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    b.selectLeft(1);
	    });

	    cmgr.create("edit.selectToCharAfter", "Select to char after cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    b.selectRight(1);
	    });

	    cmgr.create("edit.selectToCharAbove", "Select to char before cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    ctrl.selectUp();
	    });

	    cmgr.create("edit.selectToCharBelow", "Select to char after cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    ctrl.selectDown();
	    });

	    cmgr.create("edit.selectPageUp", "Select page up from cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;
		    foreach (i; 0 .. ctrl.visibleLineCount)
		    {
			    ctrl.selectUp();
			    // TODO: optimize
			    ctrl.scrollUp();
		    }
	    });

	    cmgr.create("edit.selectPageDown", "Select page down from cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto ctrl = b;

		    if (ctrl.bufferEndOffset == ctrl.length)
		    {
			    // end of buffer already in view
			    foreach (i; 0 .. ctrl.visibleLineCount)
				    ctrl.selectDown();
		    }
		    else
		    {
			    foreach (i; 0 .. ctrl.visibleLineCount)
			    {
				    ctrl.selectDown();

				    // TODO: optimize
				    ctrl.scrollDown();
			    }
		    }
	    });

	    cmgr.create("edit.deleteCharBefore", "Delete character before cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    b.remove(-1);
	    });

	    cmgr.create("edit.deleteCharAfter", "Delete character after cursor",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    b.remove(1);
	    });

	    cmgr.create("edit.insert", "Insert a newline at cursor",
				    createParams(""),
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto str = data[0].get!string();
		    import std.conv;
		    b.insert(str);
	    });


	    class BufferViewAnimator
	    {
		    int lineRelative;
		    int lineOffset;
		    float speed = 3f;
		    float remainder = 0f;

		    @property isRunning() const pure nothrow @safe
		    {
			    return lineOffset != int.max;
		    }

		    BufferView bufferView;
		    // Timeline.Runner runner;

		    this(BufferView bv)
		    {
			    bufferView = bv;
			    lineOffset = int.max;
		    }

		    //import animation.interpolate;
		    import core.time;

		    private bool seek()
		    {

			    if (!isRunning || offset == lineOffset)
			    {
				    lineOffset = int.max;
				    return false;
			    }

			    float diff = lineOffset - offset;


			    int viewLines = bufferView.visibleLineCount;
			    float delta = void;
			    if (diff < 0)
			    {
				    float change = -speed;
				    if (-diff > viewLines)
						    change = (diff / viewLines) * speed; // diff is negative ie. change is negative

				    const bool willOvershoot = diff > change;
				    if (willOvershoot)
					    delta = diff;
				    else
					    delta = change;
			    }
			    else // diff > 0
			    {
				    float change = speed;
				    if (diff > viewLines)
					    change = (diff / viewLines) * speed;

				    const willOvershoot = diff < change;
				    if (willOvershoot)
					    delta = diff;
				    else
					    delta = change;
			    }

			    int deltaInt = cast(int)delta;
			    // remainder = delta - deltaInt;

			    offset = deltaInt + offset;
			    return true;
		    }

		    private bool xseek()
		    {
			    if (!isRunning || offset == lineOffset)
			    {
				    remainder = 0f;
				    lineOffset = int.max;
				    return false;
			    }

			    float diff = lineOffset - offset;

			    float delta = void;
			    if (diff < 0)
			    {
				    const float change = -speed + remainder;
				    const bool willOvershoot = diff > change;
				    if (willOvershoot)
					    delta = diff;
				    else
					    delta = change;
			    }
			    else // diff > 0
			    {
				    const float change = speed + remainder;
				    const willOvershoot = diff < change;
				    if (willOvershoot)
					    delta = diff;
				    else
					    delta = change;
			    }

			    int deltaInt = cast(int)delta;
			    remainder = delta - deltaInt;

			    offset = deltaInt + offset;
			    return true;
		    }

		    void pageUp()
		    {
			    if (bufferView.lineOffset == 0)
			    {
				    bufferView.lineNumberRelativeToView = 0;
			    }
			    else
			    {
				    bool _isRunning = isRunning;
				    int curLineOffset = _isRunning ? lineOffset : bufferView.lineOffset;
				    lineOffset = curLineOffset < bufferView.visibleLineCount ? 0 : curLineOffset - bufferView.visibleLineCount;
				    if (!_isRunning)
				    {
					    remainder = 0f;
					    speed = app.getGlobalStyle!float("page-down-speed");
					    lineRelative = bufferView.lineNumberRelativeToView;
					    if (lineRelative < 0 || lineRelative >= bufferView.visibleLineCount)
						    lineRelative = 0;
					    app.guiRoot.timeout(dur!"msecs"(10), &seek);
				    }
				    seek();
			    }

			    //auto timeline = app.guiRoot.activeWindow.timeline;
			    //float start = float.max;
			    //float duration = speed;
			    //if (runner !is null)
			    //{
			    //    start = runner.start;
			    //
			    //}
			    //
			    //if (ctrl.lineOffset == 0)
			    //{
			    //    ctrl.lineNumberRelativeToView = 0;
			    //}
			    //else
			    //{
			    //    getCreate(bv).pageUp();
			    //}
			    //
			    //auto newRunner = timeline.animate!("offset", LinearCurve)(new BufferViewAnimator(ctrl), target, speed);
		    }

		    void pageDown()
		    {
			    if (bufferView.bufferEndOffset == bufferView.length)
			    {
				    // End of buffer already in view.
				    // Goto last line
				    for (int i = 0; i < bufferView.visibleLineCount; i++)
					    bufferView.cursorDown();
			    }
			    else
			    {
				    bool _isRunning = isRunning;
				    int curLineOffset = _isRunning ? lineOffset : bufferView.lineOffset;
				    lineOffset = curLineOffset + bufferView.visibleLineCount;
				    if (!_isRunning)
				    {
					    remainder = 0f;
					    speed = app.getGlobalStyle!float("page-down-speed");
					    lineRelative = bufferView.lineNumberRelativeToView;
					    if (lineRelative < 0 || lineRelative >= bufferView.visibleLineCount)
						    lineRelative = 0;
					    app.guiRoot.timeout(dur!"msecs"(10), &seek);
				    }
				    seek();
			    }

			    //if (runner.stopped)
			    //    lineRelative = bufferView.lineNumberRelativeToView
			    //
			    //float speed = app.getGlobalStyle!float("page-down-speed");
			    //auto timeline = app.guiRoot.activeWindow.timeline;
			    //if (ctrl.bufferEndOffset == ctrl.length)
			    //{
			    //    // End of buffer already in view.
			    //    // Goto last line
			    //    for (int i = 0; i < ctrl.visibleLineCount; i++)
			    //        ctrl.cursorDown();
			    //}
			    //else
			    //{
			    //    getCreate(bv).pageDown();
			    //}
			    //
			    //auto newRunner = timeline.animate!("offset", LinearCurve)(new BufferViewAnimator(ctrl), ctrl.lineOffset + ctrl.visibleLineCount, speed);
		    }

		    @property
		    {
			    int offset() const
			    {
				    return 	bufferView.lineOffset;
			    }
			    void offset(int o)
			    {
				    bufferView.lineOffset = o;
				    bufferView.lineNumberRelativeToView = lineRelative;
			    }
		    }
	    }

	    BufferViewAnimator[BufferView] bufferViewAnimators;

	    BufferViewAnimator getCreate(BufferView bv)
	    {
		    auto a = bv in bufferViewAnimators;
		    if (a is null)
		    {
			    auto anim = new BufferViewAnimator(bv);
			    bufferViewAnimators[bv] = anim;
			    return anim;
		    }
		    return *a;
	    }

	    cmgr.create("edit.scrollPageDown", "Scroll view one page down",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    getCreate(b).pageDown();
	    });

	    cmgr.create("edit.scrollPageUp", "Scroll view one page up",
				    null,
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    getCreate(b).pageUp();
	    });

	    cmgr.create("edit.cursorToLine", "Move cursor up or down until cursor reaches the line number given as argument",
				    createParams(1),
				    delegate(CommandParameter[] data) {
		    mixin(getBufferOrReturn);
		    auto i = data[0].peek!int;
		    assert(i !is null);
		    b.cursorToLine(*i);

	    //    if (i is null)
	    //    {
	    //        import controls.command;
	    //        auto cc = app.guiRoot.activeWindow.userData.get!(Application.WindowData)().commandControl;
	    //        cc.setCommand("edit.cursorToLine ");
	    //        cc.show(CommandControl.Mode.oneline);
	    //    }
	    //    else
	    //    {
	    ////		auto str = data.get!string();
	    //        import std.conv;
	    //        b.cursorToLine(*i);
	    //    }
	    });

	    // cmgr.add(new OpenFileCommand);

	    class ShowBufferCommand : Command
	    {
		    override @property string name() const { return "edit.showBuffer"; }
		    override @property string description() const { return "Show named buffer in active window"; }

		    this()
		    {
			    super(createParams(""));
		    }

		    override void execute(CommandParameter[] data)
		    {
			    auto path = data[0].get!string;
			    app.showBuffer(path);
		    }

		    override CompletionEntry[] getCompletions(CommandParameter[] data)
		    {
			    auto prefix = data[0].get!string();
			    auto a = app.getActiveBufferCompletions(prefix);
                return a;
			    // If the prefix is empty we know that the active buffer is the first entry. And we don't
			    // want to return that since you never want to activate the current active buffer.
			    //if (prefix.empty && app.currentBuffer !is null && !app.currentBuffer.name.empty)
			    //    a = a[1..$];

			    //return a.toCompletionEntries();
		    }
	    }

	    cmgr.add(new ShowBufferCommand);

	    class IncrementalSearchCommand : Command
	    {
		    override @property string name() const { return "edit.incrSearch"; }
		    override @property string description() const { return "Incremental search active buffer"; }

		    struct SearchData
		    {
			    int startPos;
			    int lastPos;
		    }

		    this()
		    {
			    super(createParams(""));
		    }

		    override void execute(CommandParameter[] data)
		    {
			    // If command window is not open the open it with the command in place and no arg
			    // else
			    // if the command is already running then search for the next item from the end of current selection or
			    // cursorPoint in no selection.
			    auto b = app.currentBuffer;
			    if (b is null)
				    return;
			    import std.stdio;

			    if (b.name == "*CommandInput*")
			    {
				    app.addMessage("got " ~ data[0].get!string());
			    }
			    else
			    {
				    app.commandManager.execute("app.toggleCommandArea", createArgs("edit.incrSearch "));
			    }
		    }

		    override CompletionEntry[] getCompletions(CommandParameter[] data)
		    {
			    return [data[0].get!string()].toCompletionEntries();
		    }
	    }

    }
}
