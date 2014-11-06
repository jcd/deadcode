module extensions.search;

import extension;

@MenuItem("Edit/Search")
@Shortcut("<ctrl> + i")
@Shortcut("<alt> + i", "Lin")
class SearchCommand : BasicCommand!SearchCommand
{
	this()
	{
		super(createParams(""));
	}

	override void execute(CommandParameter[] v)
	{
		import std.string;
		auto str = v[0].get!string;
		auto b = currentBuffer.buffer;
		auto r = b[currentBuffer.cursorPoint..b.length];
		int idx = -1;
		for (int i = 0; i < r.length; ++i)
		{
			int j = i;
			foreach (s; str)
			{
				if (r[j] != s)
					break;
				++j;
			}
			if (j - i == str.length)
			{
				idx = i;
				break;
			}
		}
		if (idx != -1)
			currentBuffer.cursorPoint = currentBuffer.cursorPoint + idx;
	}
}

@RegisterCommand!search2
@MenuItem("Edit/Search2")
@Shortcut("<ctrl> + j")
@Shortcut("<alt> + j", "Lin")
void search2(GUIApplication app, string needle)
{
	import std.string;
	auto str = needle;
	auto b = app.currentBuffer.buffer;
	auto r = b[app.currentBuffer.cursorPoint..b.length];
	int idx = -1;
	for (int i = 0; i < r.length; ++i)
	{
		int j = i;
		foreach (s; str)
		{
			if (r[j] != s)
				break;
			++j;
		}
		if (j - i == str.length)
		{
			idx = i;
			break;
		}
	}
	if (idx != -1)
		app.currentBuffer.cursorPoint = app.currentBuffer.cursorPoint + idx;
}

@RegisterCommand!wordUppercase
@MenuItem("Edit/Uppercase")
@Shortcut("<ctrl> + u")
void wordUppercase(GUIApplication app, string dummy)
{
	import std.uni;
	auto b = app.currentBuffer;
	auto origPoint = b.cursorPoint;
	Region r = b.selection;
	
	if (r.empty)
	{
		// Get word on cursor
		b.cursorToBeginningOfWord();
		r.a = b.cursorPoint;
		b.selectToEndOfWord();
		r.b = b.cursorPoint;
	}

	if (!r.empty)
	{
		auto txt = b.getText(r);
		toUpperInPlace(txt);
		b.replace(cast(dstring)txt, r);
	}
	b.cursorPoint = origPoint;
}

@RegisterCommand!textUppercase @MenuItem("Text/Uppercase") @Shortcut("<ctrl> + o")
void textUppercase(GUIApplication app, string dummy)
{
	auto b = app.currentBuffer;
	auto r = b.getRegion(RegionQuery.selectionOrWord);
	if (!r.empty)
		b.replace(cast(immutable)std.uni.toUpper(b.getText(r)), r);
}

@RegisterCommand!textUppercase2 @MenuItem("Text/Uppercase2") @Shortcut("<ctrl> + r")
void textUppercase2(GUIApplication app, string dummy)
{
	app.currentBuffer.transform!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}
