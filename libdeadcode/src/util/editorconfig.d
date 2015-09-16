module util.editorconfig;

enum EditorConfigIndentStyle : string
{
    tab = "tab",
    space = "space"
}

enum EditorConfigEndOfLine : string
{
    lf = "lf",
    cr = "cr",
    crlf = "crlf"
}

enum EditorConfigCharset : string
{
    latin1 = "latin1",
    utf8 = "utf-8",
    utf8BOM = "utf-8-bom",
    utf16BE = "utf-16-be",
    utf16LE = "utf-16-le"
}

enum EditorConfigSpacesAroundOperators : string
{
    _true = "true",
    _false = "false",
    hybrid = "hybrid"
}

enum EditorConfigSpacesAroundBrackets : string
{
    none = "none",
    inside = "inside",
    outside = "outside",
    both = "both"
}

enum EditorConfigIndentBraceStyle : string
{
    kAndR = "k&r",
    allman = "allman",
    gnu = "gnu",
    horstman = "horstman"
}

// http://editorconfig.org/#file-format-details
struct EditorConfig
{
    // Editor config universal
    EditorConfigIndentStyle indentStyle = EditorConfigIndentStyle.space;
    int indentSize = 4; // -1 means same as tabWidth
    int tabWidth = -1;       // defaults (ie. when -1) to indentSize when indentSize is >= 0
    EditorConfigEndOfLine endOfLine = EditorConfigEndOfLine.lf;
    EditorConfigCharset charset = EditorConfigCharset.utf8;
    bool trimTrailingWhiteSpace = true;
    bool insertFinalNewline = true;
    bool root = false;
    int maxLineLength = int.max;

    // Domain specific
    bool curlyBracketNextLine = true;
    EditorConfigSpacesAroundOperators spacesAroundOperators = EditorConfigSpacesAroundOperators._true;
    EditorConfigSpacesAroundBrackets spacesAroundBrackets = EditorConfigSpacesAroundBrackets.none;
    EditorConfigIndentBraceStyle indentBraceStyle = EditorConfigIndentBraceStyle.allman;
    int continuationIndentSize = -1; // defaults (ie. when -1) to indentSize
}

private struct EditorConfigPaths
{
    import std.path;
    private
    {
        string _currentDir;
        string _rootName;
    }

    this(string startDir)
    {
        _currentDir = startDir.buildNormalizedPath.absolutePath;
        _rootName = _currentDir.rootName();
    }

    @property string front() const
    {
        return _currentDir.buildPath(".editorconfig");
    }

    void popFront()
    {
        _currentDir = _currentDir.dirName();
    }

    @property bool empty() const
    {
        import std.stdio;
        writeln(_currentDir, " ", _rootName);
        return _currentDir == _rootName;
    }
}

private auto editorConfigPaths(string dir)
{
    return EditorConfigPaths(dir);
}

EditorConfig editorConfigForPath(string path)
{
    import std.path;
    import std.file;

    auto r = editorConfigPaths(path.dirName());

    string[string] options;

    foreach (iniFilePath; r)
    {
        if (exists(iniFilePath))
        {
            auto configResolver = EditorConfigResolver(iniFilePath);
            auto oldOptions = options;
            options = configResolver.resolve(path);
            if (oldOptions.length != 0)
            {
                foreach (k,v; oldOptions)
                    options[k] = v;
            }

            if (options.get("root", "") == "true")
                break;
        }
    }

    // Build the EditorConfig result
    EditorConfig res;

    foreach (k,v; options)
    {
        switch (k)
        {
            case "indent_style":
                res.indentStyle = v == "tab" ? EditorConfigIndentStyle.tab : EditorConfigIndentStyle.space;
                break;
            case "indent_size":
                res.indentSize = v.to!int;
                break;
            case "tab_width":
                res.tabWidth = v.to!int;
                break;
            case "end_of_line":
                switch (v)
                {
                    case "lf":
                        res.endOfLine = EditorConfigEndOfLine.lf;
                        break;
                    case "cr":
                        res.endOfLine = EditorConfigEndOfLine.cr;
                        break;
                    case "crlf":
                        res.endOfLine = EditorConfigEndOfLine.crlf;
                        break;
                    default:
                        break;
                }
                break;
            case "charset":
                res.charset = EditorConfigCharset.utf8;
                break;
            case "trim_trailing_whitespace":
                res.trimTrailingWhiteSpace = true;
                break;
            case "insert_final_newline":
                res.insertFinalNewline = true;
                break;
            case "root":
                res.root = false;
                break;
            case "max_line_length":
                res.maxLineLength = int.max;
                break;

            // Domain specific
            case "curly_bracket_next_line":
                res.curlyBracketNextLine = true;
                break;
            case "spaces_around_operators":
                res.spacesAroundOperators = EditorConfigSpacesAroundOperators._true;
                break;
            case "spaces_around_brackets":
                res.spacesAroundBrackets = EditorConfigSpacesAroundBrackets.none;
                break;
            case "indent_brace_style":
                res.indentBraceStyle = EditorConfigIndentBraceStyle.allman;
                break;
            case "continuation_indent_size":
                res.continuationIndentSize = -1; // defaults (ie. when -1) to indentSize
                break;
            default:
                break;
        }
    }

    if (res.indentStyle == EditorConfigIndentStyle.tab)
    {
        if (res.tabWidth != -1)
            res.indentSize = res.tabWidth;
        else
            res.tabWidth = res.indentSize;
    }
    else if (res.tabWidth == -1)
    {
        res.tabWidth = res.indentSize;
    }

    return res;
}

private struct EditorConfigResolver
{
    alias Properties = string[string];

    Properties[] sections;
    int[string] index;

    string iniBaseDir;

    this(string iniFilePath)
    {
        import std.file;
        import std.path;
        import std.file;
        import util.ini;

        iniBaseDir = dirName(iniFilePath);

        auto data = readText(iniFilePath);

        foreach(item; parseINI(data))
        {
            import std.stdio;
            writeln(item);
            auto idx = item.section in index;
            if (idx is null)
            {
                string[string] mm;
                mm[item.key.strip] = item.value.strip;
                sections ~= mm;
                index[item.section] = cast(int)sections.length - 1;
            }
            else
            {
                sections[*idx][item.key.strip] = item.value.strip;
            }
        }
    }

    string[string] resolve(string path)
    {
        string[string] options;
        import std.path;
        import std.string;

        foreach (idx; 0..index.length)
        {
            string sectionName;
            foreach (k,v; index)
                if (v == idx)
                    sectionName = k;

            auto sectionData = sections[idx];

            if (sectionName.length == 0 || (sectionName.indexOf('/') != -1 ? globMatchEditorConfig(path, buildPath(iniBaseDir, sectionName)) : globMatchEditorConfig(baseName(path), sectionName)))
            {
                foreach (propKey, propValue; sectionData)
                    options[propKey] = propValue;
            }
        }
        return options;
    }
}

import std.path : CaseSensitive, isDirSeparator, filenameCharCmp;
import std.range;
import std.traits;
import std.conv;

// From std.path with changes:
// * changes meaning to match all characters except '/'
// ** added to take over the old meaning of *
bool globMatchEditorConfig(CaseSensitive cs = CaseSensitive.osDefault, C, Range)
(Range path, const(C)[] pattern)
@safe pure nothrow
if (isForwardRange!Range && isSomeChar!(ElementEncodingType!Range) &&
    isSomeChar!C && is(Unqual!C == Unqual!(ElementEncodingType!Range)))
in
{
    // Verify that pattern[] is valid
    import std.algorithm : balancedParens;
    assert(balancedParens(pattern, '[', ']', 0));
    assert(balancedParens(pattern, '{', '}', 0));
}
body
{
    alias RC = Unqual!(ElementEncodingType!Range);

    static if (RC.sizeof == 1 && isSomeString!Range)
    {
        import std.utf : byChar;
        return globMatchEditorConfig!cs(path.byChar, pattern);
    }
    else static if (RC.sizeof == 2 && isSomeString!Range)
    {
        import std.utf : byWchar;
        return globMatchEditorConfig!cs(path.byWchar, pattern);
    }
    else
    {
        C[] pattmp;
        foreach (ref pi; 0 .. pattern.length)
        {
            const pc = pattern[pi];
            switch (pc)
            {
                case '*':
                    if (pi < pattern.length-1 && pattern[pi+1] == '*')
                    {
                        if (pi + 2 == pattern.length)
                            return true;
                        for (; !path.empty; path.popFront())
                        {
                            auto p = path.save;
                            if (globMatchEditorConfig!(cs, C)(p,
                                                  pattern[pi + 2 .. pattern.length]))
                                return true;
                        }
                        return false;
                    }
                    else
                    {
                        if (pi + 1 == pattern.length)
                            return true;
                        for (; !path.empty; path.popFront())
                        {
                            auto p = path.save;
                            //if (p[0].to!dchar.isDirSeparator() && !pattern[pi+1].isDirSeparator())
                            //    return false;
                            if (globMatchEditorConfig!(cs, C)(p,
                                                  pattern[pi + 1 .. pattern.length]))
                                return true;
                            if (p[0].to!dchar.isDirSeparator())
                                return false;
                        }
                        return false;
                    }
                case '?':
                    if (path.empty)
                        return false;
                    path.popFront();
                    break;

                case '[':
                    if (path.empty)
                        return false;
                    auto nc = path.front;
                    path.popFront();
                    auto not = false;
                    ++pi;
                    if (pattern[pi] == '!')
                    {
                        not = true;
                        ++pi;
                    }
                    auto anymatch = false;
                    while (1)
                    {
                        const pc2 = pattern[pi];
                        if (pc2 == ']')
                            break;
                        if (!anymatch && (filenameCharCmp!cs(nc, pc2) == 0))
                            anymatch = true;
                        ++pi;
                    }
                    if (anymatch == not)
                        return false;
                    break;

                case '{':
                    // find end of {} section
                    auto piRemain = pi;
                    for (; piRemain < pattern.length
                         && pattern[piRemain] != '}'; ++piRemain)
                    {   }

                    if (piRemain < pattern.length)
                        ++piRemain;
                    ++pi;

                    while (pi < pattern.length)
                    {
                        const pi0 = pi;
                        C pc3 = pattern[pi];
                        // find end of current alternative
                        for (; pi < pattern.length && pc3 != '}' && pc3 != ','; ++pi)
                        {
                            pc3 = pattern[pi];
                        }

                        auto p = path.save;
                        if (pi0 == pi)
                        {
                            if (globMatchEditorConfig!(cs, C)(p, pattern[piRemain..$]))
                            {
                                return true;
                            }
                            ++pi;
                        }
                        else
                        {
                            /* Match for:
                            *   pattern[pi0..pi-1] ~ pattern[piRemain..$]
                            */
                            if (pattmp.ptr == null)
                                // Allocate this only once per function invocation.
                                // Should do it with malloc/free, but that would make it impure.
                                pattmp = new C[pattern.length];

                            const len1 = pi - 1 - pi0;
                            pattmp[0 .. len1] = pattern[pi0 .. pi - 1];

                            const len2 = pattern.length - piRemain;
                            pattmp[len1 .. len1 + len2] = pattern[piRemain .. $];

                            if (globMatchEditorConfig!(cs, C)(p, pattmp[0 .. len1 + len2]))
                            {
                                return true;
                            }
                        }
                        if (pc3 == '}')
                        {
                            break;
                        }
                    }
                    return false;

                default:
                    if (path.empty)
                        return false;
                    if (filenameCharCmp!cs(pc, path.front) != 0)
                        return false;
                    path.popFront();
                    break;
            }
        }
        return path.empty;
    }
}

unittest
{
    assert (globMatchEditorConfig!(CaseSensitive.no)("foo", "Foo"));
    assert (!globMatchEditorConfig!(CaseSensitive.yes)("foo", "Foo"));

    assert(globMatchEditorConfig("foo", "*"));
    assert(globMatchEditorConfig("foo.bar"w, "*"w));
    assert(globMatchEditorConfig("foo.bar"d, "*.*"d));
    assert(globMatchEditorConfig("foo.bar", "foo*"));
    assert(globMatchEditorConfig("foo.bar"w, "f*bar"w));
    assert(globMatchEditorConfig("foo.bar"d, "f*b*r"d));
    assert(globMatchEditorConfig("foo.bar", "f???bar"));
    assert(globMatchEditorConfig("foo.bar"w, "[fg]???bar"w));
    assert(globMatchEditorConfig("foo.bar"d, "[!gh]*bar"d));

    assert(!globMatchEditorConfig("foo", "bar"));
    assert(!globMatchEditorConfig("foo"w, "*.*"w));
    assert(!globMatchEditorConfig("foo.bar"d, "f*baz"d));
    assert(!globMatchEditorConfig("foo.bar", "f*b*x"));
    assert(!globMatchEditorConfig("foo.bar", "[gh]???bar"));
    assert(!globMatchEditorConfig("foo.bar"w, "[!fg]*bar"w));
    assert(!globMatchEditorConfig("foo.bar"d, "[fg]???baz"d));
    assert(!globMatchEditorConfig("foo.di", "*.d")); // test issue 6634: triggered bad assertion

    assert(globMatchEditorConfig("foo.bar", "{foo,bif}.bar"));
    assert(globMatchEditorConfig("bif.bar"w, "{foo,bif}.bar"w));

    assert(globMatchEditorConfig("bar.foo"d, "bar.{foo,bif}"d));
    assert(globMatchEditorConfig("bar.bif", "bar.{foo,bif}"));

    assert(globMatchEditorConfig("bar.fooz"w, "bar.{foo,bif}z"w));
    assert(globMatchEditorConfig("bar.bifz"d, "bar.{foo,bif}z"d));

    assert(globMatchEditorConfig("bar.foo", "bar.{biz,,baz}foo"));
    assert(globMatchEditorConfig("bar.foo"w, "bar.{biz,}foo"w));
    assert(globMatchEditorConfig("bar.foo"d, "bar.{,biz}foo"d));
    assert(globMatchEditorConfig("bar.foo", "bar.{}foo"));

    assert(globMatchEditorConfig("bar.foo"w, "bar.{ar,,fo}o"w));
    assert(globMatchEditorConfig("bar.foo"d, "bar.{,ar,fo}o"d));
    assert(globMatchEditorConfig("bar.o", "bar.{,ar,fo}o"));

    assert(!globMatchEditorConfig("foo", "foo?"));
    assert(!globMatchEditorConfig("foo", "foo[]"));
    assert(!globMatchEditorConfig("foo", "foob"));
    assert(!globMatchEditorConfig("foo", "foo{b}"));

    assert (globMatchEditorConfig(`foo/foo\bar`, "f**b**r"));
    assert(globMatchEditorConfig("foo", "**"));
    assert(globMatchEditorConfig("foo/bar", "foo/bar"));
    assert(globMatchEditorConfig("foo/bar", "foo/*"));
    assert(globMatchEditorConfig("foo/bar", "*/bar"));
    assert(globMatchEditorConfig("/foo/bar/gluu/sar.png", "**/sar.png"));
    assert(globMatchEditorConfig("/foo/bar/gluu/sar.png", "**/*.png"));
    assert(!globMatchEditorConfig("/foo/bar/gluu/sar.png", "*/sar.png"));
    assert(!globMatchEditorConfig("/foo/bar/gluu/sar.png", "*/*.png"));


    static assert(globMatchEditorConfig("foo.bar", "[!gh]*bar"));

    import std.stdio;

    writeln(editorConfigForPath(r"C:\Projects\D\ded\libdeadcode\src\util\editorconfig.d"));
}


