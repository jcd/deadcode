module util.string;

import std.typecons;

import test;
mixin registerUnittests;


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
        string[] reversePathElements;
        int pathElementsUsed;
    }
    int idx = 0;

static string[] myreverse(string[] arr)
{
	arr.reverse();
return arr;
}

    auto r = names
        .map!((a) => SortHelper(idx++, a, myreverse(a.pathSplitter.array))).array
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
                int newElementsUsed = cast(int)prefix.length + 1; // +1 to add the disambiguating elements
                item.pathElementsUsed = min(newElementsUsed, item.reversePathElements.length);
                r[index - 1].pathElementsUsed = min(newElementsUsed, r[index - 1].reversePathElements.length);
            }
        }
    }

    return r.sort!((a,b) => a.index < b.index).map!((a) => tuple(myreverse(a.reversePathElements[0..a.pathElementsUsed]).buildPath, a.name));
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


// TODO: replace with proper dynamic programming equivalent.

/*!
* string_score.c: String Scoring Algorithm 0.1
* https://github.com/kurige/string_score
*
* Based on Javascript code by Joshaven Potter
* https://github.com/joshaven/string_score
*
* MIT license: http://www.opensource.org/licenses/mit-license.php
*
* Date: Tue Mar 21 2011
*/

private
{
	enum ACRONYM_BONUS        = 0.8;
	enum CONSECUTIVE_BONUS    = 0.6;
	enum START_OF_STR_BONUS   = 0.1;
	enum SAMECASE_BONUS       = 0.1;
	enum MATCH_BONUS          = 0.1;
    enum AFTER_NONALNUM_BONUS = 0.1;
}

double rank( string a, string b, double fuzziness = 0.0 )
{
    import std.ascii;
    import std.range;
	import std.string;

	/* If the original string is equal to the abbreviation, perfect match. */
    if( a == b )
		return 1.0;

	/* If perfectly bad match. */
    if( b.empty )
		return 0.0;

    /* Create a ref of original string, so that we can manipulate it. */
    string aref = a;

    double score = 0.0;
    bool start_of_string_bonus = false;

    size_t c_index;

    double fuzzies = 1.0;

    /* Walk through abbreviation and add up scores. */
    foreach (i, c; b)
    {
        /* Find the first case-insensitive match of a character. */

        //printf( "- %c (%s)\n", c, aptr );
        c_index = aref.indexOf(c, CaseSensitive.no);

        /* Set base score for any matching char. */
        if( c_index == -1 )
        {
            if( fuzziness > 0.0 )
            {
                fuzzies += 1.0 - fuzziness;
                continue;
            }
            return 0.0;
        }
        else
		{
            score += MATCH_BONUS;

            // If char is matching just right after a non alnum char we add bonus
            if (i > 0 && !isAlphaNum(b[i-1]))
                score += AFTER_NONALNUM_BONUS;
		}

        /* Same-case bonus. */
        if( aref[c_index] == c )
        {
            //printf( "* Same case bonus.\n" );
            score += SAMECASE_BONUS;
        }

        /* Consecutive letter & start-of-string bonus. */
        if( c_index == 0 )
        {
            /* Increase the score when matching first character of the
			remainder of the string. */
            //printf( "* Consecutive char bonus.\n" );
            score += CONSECUTIVE_BONUS;
            if( i == 0 )
                /* If match is the first char of the string & the first char
				of abbreviation, add a start-of-string match bonus. */
                start_of_string_bonus = true;
        }
        else if( aref[c_index - 1] == ' ' )
        {
            /* Acronym Bonus
			* Weighing Logic: Typing the first character of an acronym is as
			* if you preceded it with two perfect character matches. */
            //printf( "* Acronym bonus.\n" );
            score += ACRONYM_BONUS;
        }

        /* Left trim the already matched part of the string.
		(Forces sequential matching.) */
		aref = aref[c_index + 1..$];
	}

    score /= b.length;

    /* Reduce penalty for longer strings. */
    score = ((score * (b.length / cast(double)a.length)) + score) / 2;
    score /= fuzzies;

    if( start_of_string_bonus && (score + START_OF_STR_BONUS < 1) )
    {
        //printf( "* Start of string bonus.\n" );
        score += START_OF_STR_BONUS;
    }

    return score;
}

unittest
{
	void t(string a, string b, double expected = -1)
	{
		import std.stdio;
		auto r = a.rank(b);
		writeln(a, " <=> ", b, " is ", r);

		if (expected == -1)
			return;
	}

	t("ResourceProviderFactory", "ResourceProviderFactory");
	t("ResourceProviderFactory", "res");
	t("ResourceProviderFactory", "rpf");
	t("ResourceProviderFactory", "RPF");
}
