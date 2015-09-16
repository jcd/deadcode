module util.ini;

import std.stdio: File, writeln;
import std.range;
import std.algorithm: canFind;
import std.string: strip, splitLines;
import std.traits: Unqual;
import std.conv: text;

struct ConfigItem {
	string section;
	string key;
	string value;
}

private struct ConfigItems(Range,string kvSeparators=":=",string commentChars=";#")
{
	Unqual!Range _input;
	string currentSection = "";

	this(Unqual!Range r) {
		_input = r;
		skipNonKeyValueLines();
	}

	@property bool empty() {
		return _input.empty;
	}
	@property void popFront() {
		_input.popFront();
		skipNonKeyValueLines();
	}
	@property auto front() {
		auto line = _input.front;
		foreach(uint i, const c; line) {
			if (kvSeparators.canFind(c)) {
				auto key   = line[0..i];
				auto value = line[i+1..$];
				return ConfigItem(currentSection, key.idup, value.idup);
			}
		}
		return ConfigItem(currentSection, line.idup, "");
	}
	private void skipNonKeyValueLines() {
		while(!_input.empty) {
			auto line = strip(_input.front);
			if (line == "" || isComment(line)) {
				_input.popFront();
				continue;
			}
			if (line[0] == '[' && line[$-1] == ']') { /* section start */
				currentSection = line[1..$-1].idup;
				_input.popFront();
				continue;
			}
			break;
		}
	}
	private static bool isComment(in char[] line) pure @safe {
		assert (line != "");
		auto c = line[0];
		if (commentChars.canFind(c)) return true;
		return false;
	}
}

auto parseINIlines(Range)(Range r) if (isInputRange!(Unqual!Range))
{
	return ConfigItems!(Range)(r);
}

auto parseINI(string data)
{
	return data.splitLines.parseINIlines;
}

auto parseINI(File fh)
{
	return fh.byLine.parseINIlines;
}

unittest {
	auto data = "
        general section=possible
        [Simple Values]
        key=value
        spaces in keys=allowed
        spaces in values=allowed as well
        spaces around the delimiter = obviously
        you can also use : to delimit keys from values

        [All Values Are Strings]
        values like this: 1000000
        or this: 3.14159265359
        are they treated as numbers? : no
        integers, floats and booleans are held as: strings
        can use the API to get converted values directly: true

        [Multiline Values]
        [No Values]
        key_without_value
        empty string value here =

        [You can use comments]
        # like this
        ; or this

        # By default only in an empty line.
        # Inline comments can be harmful because they prevent users
        # from using the delimiting characters as parts of values.
        # That being said, this can be customized.

        [Sections Can Be Indented]
        can_values_be_as_well = True
        does_that_mean_anything_special = False
        purpose = formatting for readability
        # Did I mention we can indent comments, too?
        [foo[section]bar]
        subsub = 43";
	foreach(item; parseINI(data)) {
		writeln(text(item));
	}
}
