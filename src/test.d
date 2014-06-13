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
	int offsBegin = agName.length + DELIMLEN + (agName.length ? 1 : 0);
	int offsEnd = func.indexOf("_", offsBegin);
	int agAtLine = func[offsBegin..offsEnd].to!int;

	// In case of Asserts in member functions of classes defined in a unittest scope
	// we need to check of . after the __unittestLxx_xx 
	int offsStop = func.indexOf(".", offsEnd);

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

void printStats(bool includeSuccessful = false)
{
	import std.algorithm;
	foreach (rec; g_TestRecords)
	{
		if (includeSuccessful || !rec.success)
			writeln("Test ", rec.file[4..$], ":", rec.line, " ", rec.msg, " ", rec.assertion, " ", rec.success ? "OK" : "FAILED");
	}
	writeln(format("%s of %s OK", g_TestRecords.count!"a.success", g_Total));
}

void Assert(lazy bool expMustBeTrue, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	bool res = expMustBeTrue();
	recordTestResult(res, "", msg, file, line, func);
	// writeln("Test ", file, "@", line, " ", msg, ": ", res ? "OK" : "FAILED");
}

mixin template registerUnittests(alias mod)
{
	static this()
	{
		import std.typetuple;
		alias tests = TypeTuple!(__traits(getUnitTests, mod));
		import std.string;
		import std.algorithm;

		foreach (test; tests)
		{
			// ie. __unittestL235_52
			//enum name = __traits(identifier, test)[11..$];
			//enum name = __traits(identifier, test)[11..$];
			//enum linen = name[0.. indexOf(name, "_")];
			//writeln("FOOO " ~ name);

			//if (textAnchor.number+1 == linen.to!uint)
			//{
			//    //writeln("FOOO " ~ line);
			//    //	test();
			//}
			enum name = __traits(identifier, test);
			g_ModuleUnitTests[name] = &test;
			auto info = parseUnitTestName(name);
			g_TestOrder ~= info;
		}
		sort!"a.testNumber < b.testNumber"(g_TestOrder);
	}
}

void Assert(alias MOD, T, V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{


}

void Assert(T, V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__, string func = __FUNCTION__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a == b;

	recordTestResult(res, text(a, " == ", b), msg ~ " " ~ func, file, line, func);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " == ", b, " ", res ? "OK" : "FAILED");
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
