module test;

import std.stdio;
import std.string;
import std.conv;

struct UnitTestInfo
{
	string fullName; // including nested classes etc.
	string aggregateName; // class/module/struct name
	int testNumber; // global
	int testScopeStartsAtLine;
}

static
{
	int g_Total = 0;
	struct TestRecord
	{
		bool success;
		string assertion;
		string msg;
		string file;
		int line;
		UnitTestInfo testInfo;
	}
	alias TestRecord[] TestRecords;
	TestRecords g_TestRecords;
	alias void function() UnitTestFunc;
	UnitTestFunc[string] g_ModuleUnitTests;
	UnitTestInfo[] g_TestOrder;
}

UnitTestInfo parseUnitTestName(string func)
{
	// Parse func line e.g.
	// math.region.Region.__unittestL60_63
	string[] f;
	string agName = "";
	if (func[0..2] != "__")
		agName = func[0..func.indexOf(".__")];
	const int DELIMLEN = 11; // __unittestL
	int offsBegin = cast(int)agName.length + DELIMLEN + (agName.length ? 1 : 0);
	int offsEnd = cast(int)func.indexOf("_", offsBegin);
	int agAtLine = func[offsBegin..offsEnd].to!int;

	// In case of Asserts in member functions of classes defined in a unittest scope
	// we need to check of . after the __unittestLxx_xx
	int offsStop = cast(int)func.indexOf(".", offsEnd);

	int testNumber = func[offsEnd+1.. offsStop == -1 ? func.length : offsStop].to!int;
	return UnitTestInfo(func, agName, testNumber, agAtLine);
}

void recordTestResult(bool success, string assertion, string msg, string file, int line, string func)
{
	g_Total++;
	import std.stdio;
	auto info = parseUnitTestName(func);
	g_TestRecords ~= TestRecord( success, assertion, msg, file, line, info);
}

TestRecord getTestResult(string filename, int unittestStartLine)
{
	TestRecords recs = g_TestRecords;
	foreach (rec; recs)
	{
		if (rec.testInfo.testScopeStartsAtLine == unittestStartLine && rec.file == filename)
			return rec;
	}
	return TestRecord();
}

void printStats(bool includeSuccessful = false)
{
	import std.algorithm;
	foreach (rec; g_TestRecords)
	{
		if (includeSuccessful || !rec.success)
			writeln("Test ", rec.file[0..$], ":", rec.line, " ", rec.msg, " ", rec.assertion, " ", rec.success ? "OK" : "FAILED");
	}
	writeln(format("%s of %s OK", g_TestRecords.count!"a.success", g_Total));
}

void Assert(lazy bool expMustBeTrue, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	bool res = expMustBeTrue();
	recordTestResult(res, "", msg, file, line, func);
	// writeln("Test ", file, "@", line, " ", msg, ": ", res ? "OK" : "FAILED");
}

mixin template registerUnittests()
{
    version(unittest)
    {
	    static this()
	    {
		    import std.typetuple;
		    int a;

            alias tests = TypeTuple!(__traits(getUnitTests, __traits(parent,__traits(parent, a))));

            import std.string;
		    import std.algorithm;
            import std.traits;
            import std.typetuple;

            import std.stdio;
            //enum ii = __traits(identifier, __traits(parent,__traits(parent, a)));
            // pragma(msg, "Capturing tests in ii);
            // writeln("Capturing tests in " ~ ii);

		    // Module level tests
            foreach (tst; tests)
		    {
			    // ie. __unittestL235_52
			    //enum name = __traits(identifier, test)[11..$];
			    //enum name = __traits(identifier, test)[11..$];
			    //enum linen = name[0.. indexOf(name, "_")];
			    //import std.stdio;
                writeln("Module Unittest: " ~ __traits(identifier, tst));

			    //if (textAnchor.number+1 == linen.to!uint)
			    //{
			    //    //writeln("FOOO " ~ line);
			    //    //	test();
			    //}
			    enum name = __traits(identifier, tst);
			    g_ModuleUnitTests[name] = &tst;
			    auto info = parseUnitTestName(name);
			    g_TestOrder ~= info;
		    }

            enum allmems = TypeTuple!(__traits(allMembers, __traits(parent,__traits(parent, a))));
            //enum aggregates = Filter!(isAggregateType, allmems);

            //   writeln("All members ", allmems);
            // Aggregate level tests
            foreach (agg; allmems)
            {
                static if (is(TypeTuple!(__traits(getMember, __traits(parent,__traits(parent, a)), agg))[0] == class) ||
                           is(TypeTuple!(__traits(getMember, __traits(parent,__traits(parent, a)), agg))[0] == struct))
                {
                    //alias mem = __traits(getMember, __traits(parent,__traits(parent, a)), agg);
                    alias aggTests = TypeTuple!(__traits(getUnitTests, __traits(getMember, __traits(parent,__traits(parent, a)), agg)));
                    foreach (tst; aggTests)
		            {
			            // ie. __unittestL235_52
			            //enum name = __traits(identifier, test)[11..$];
			            //enum name = __traits(identifier, test)[11..$];
			            //enum linen = name[0.. indexOf(name, "_")];
			            //import std.stdio;
                        writeln("Aggregate Unittest: " ~ __traits(identifier, tst));

			            //if (textAnchor.number+1 == linen.to!uint)
			            //{
			            //    //writeln("FOOO " ~ line);
			            //    //	test();
			            //}
			            enum name = __traits(identifier, tst);
			            g_ModuleUnitTests[name] = &tst;
			            auto info = parseUnitTestName(name);
			            g_TestOrder ~= info;
		            }
                }
            }
		    sort!"a.testNumber < b.testNumber"(g_TestOrder);

	    };
    }
}

//void Assert(alias MOD, T, V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
//{
//
//
//}

void Assert(T, V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a == b;

	recordTestResult(res, text(a, " == ", b), msg ~ " " ~ func, file, line, func);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " == ", b, " ", res ? "OK" : "FAILED");
}

void AssertRangesEqual(T, V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	auto r1 = thisExp();
	auto r2 = isEqualToThisExp();

    int count = 0;
    while (!r1.empty && !r2.empty)
    {
        count++;
        recordTestResult(r1.front == r2.front, text(r1.front, " == ", r2.front), msg ~ " " ~ func, file, line, func);
        r1.popFront();
        r2.popFront();
    }

    if (r1.empty != r2.empty)
    {
        static if (__traits(compiles, r1.length == r2.length))
            recordTestResult(false, text("length of ", r1, " == length of ", r2), msg ~ " " ~ func, file, line, func);
        else
        {
            if (r1.empty)
                recordTestResult(false, text("length of not equal. Got ", count, " prefix length in first"), msg ~ " " ~ func, file, line, func);
            else
                recordTestResult(false, text("length of not equal. Got ", count, " prefix length in latter"), msg ~ " " ~ func, file, line, func);
        }
    }
}

immutable string ANSI_RED = "\x1b[31m";
immutable string ANSI_GREEN = "\x1b[32m";
immutable string ANSI_YELLOW = "\x1b[33m";
immutable string ANSI_RESET = "\x1b[0m";

void AssertIs(T,V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a is b;
	recordTestResult(res, text(a, " is ", b), msg, file, line, func);
	//	writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? ANSI_GREEN ~ "OK" ~ ANSI_RESET : ANSI_RED ~ "FAILED" ~ ANSI_RESET);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? "OK" : "FAILED");
}

void AssertIsNot(T,V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a !is b;
	recordTestResult(res, text(a, " is not ", b), msg, file, line, func);
	//	writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? ANSI_GREEN ~ "OK" ~ ANSI_RESET : ANSI_RED ~ "FAILED" ~ ANSI_RESET);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? "OK" : "FAILED");
}
