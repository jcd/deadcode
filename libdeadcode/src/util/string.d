module util.string;

import std.typecons;

version (unittest) import test;

// TODO: This could be optimized
auto uniquePostfixPath(R)(R names)
{
    import std.algorithm;
    import std.array;
    import std.path;

    struct SortHelper
    {
        int index;
        string name;
        const(char)[][] reversePathElements;
        int pathElementsUsed;
    }
    int idx = 0;

    auto r = names
        .map!((a) => SortHelper(idx++, a, a.pathSplitter.array.reverse)).array
        .sort!"a.reversePathElements < b.reversePathElements"().array;


    foreach (index, ref item; r)
    {
        import std.stdio;
        item.pathElementsUsed = 1;
        if (index != 0)
        {
            int lastPathElementsUsed = r[index-1].pathElementsUsed;

            auto prefix = commonPrefix(r[index-1].reversePathElements, item.reversePathElements);
            if (prefix.length != 0)
            {
                int newElementsUsed = prefix.length + 1; // +1 to add the disambiguating elements
                item.pathElementsUsed = min(newElementsUsed, item.reversePathElements.length);
                r[index - 1].pathElementsUsed = min(newElementsUsed, r[index - 1].reversePathElements.length);
            }
        }
    }

    return r.sort!((a,b) => a.index < b.index).map!((a) => tuple(a.reversePathElements[0..a.pathElementsUsed].reverse.buildPath, a.name));
}

version (unittest)
private string[] toarr(R)(R e)
{
    import std.algorithm;
    import std.array;
    return e.map!"a[0]".array;
}

unittest
{
    auto a = [ "a1", "a2", "b" ];


    a = [ "b", "a", "b"];
    Assert(uniquePostfixPath(a).toarr, a, "One level uniquePostfixPath");

    a = [ "b", "a", "foo\\a" ];
    Assert(uniquePostfixPath(a).toarr, a, "One conflict uniquePostfixPath");

    a = [ "b", "foo\\a", "bar\\a"];
    Assert(uniquePostfixPath(a).toarr, a, "One two conflicts uniquePostfixPath");

    a = [ "b", "a", "foo\\a", "bar\\a"];
    Assert(uniquePostfixPath(a).toarr, a, "One two conflicts uniquePostfixPath");

    a = [ "b", "foo\\a", "bar\\a", "a"];
    Assert(uniquePostfixPath(a).toarr, a, "One two conflicts reverse uniquePostfixPath");

    a = [ "b", "foo\\a", "bar\\goo\\a", "a"];
    Assert(uniquePostfixPath(a).toarr, [ "b", "foo\\a", "goo\\a", "a"], "One three conflicts reverse uniquePostfixPath");

    // With prefix
    a = [ "prefix\\b", "prefix\\a", "prefix\\b"];
    Assert(uniquePostfixPath(a).toarr, [ "prefix\\b", "a", "prefix\\b"], "One level uniquePostfixPath");

    a = [ "prefix\\b", "prefix\\a", "prefix\\foo\\a" ];
    Assert(uniquePostfixPath(a).toarr, [ "b", "prefix\\a", "foo\\a" ], "One conflict uniquePostfixPath");

    a = [ "prefix\\b", "prefix\\a", "prefix\\foo\\a", "prefix\\bar\\a"];
    Assert(uniquePostfixPath(a).toarr, [ "b", "prefix\\a", "foo\\a", "bar\\a"], "One two conflicts uniquePostfixPath");

    a = [ "prefix\\b", "prefix\\foo\\a", "prefix\\bar\\a", "prefix\\a"];
    Assert(uniquePostfixPath(a).toarr, [ "b", "foo\\a", "bar\\a", "prefix\\a"], "One two conflicts reverse uniquePostfixPath");

    a = [ "prefix\\b", "prefix\\foo\\a", "prefix\\bar\\goo\\a", "prefix\\a"];
    Assert(uniquePostfixPath(a).toarr, [ "b", "foo\\a", "goo\\a", "prefix\\a"], "One three conflicts reverse uniquePostfixPath");
    //printStats(true);
}
