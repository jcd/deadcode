module test;

import std.stdio;
import std.string;
import std.conv;

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
	}
	alias TestRecord[] TestRecords;
	TestRecords g_TestRecords;
}

void recordTestResult(bool success, string assertion, string msg, string file, int line)
{
	g_Total++;
	g_TestRecords ~= TestRecord( success, assertion, msg, file, line );
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

void Assert(lazy bool expMustBeTrue, string msg = "", string file = __FILE__, int line = __LINE__)
{
	bool res = expMustBeTrue();
	recordTestResult(res, "", msg, file, line);
	// writeln("Test ", file, "@", line, " ", msg, ": ", res ? "OK" : "FAILED");
}

void Assert(T,V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a == b;
	recordTestResult(res, text(a, " == ", b), msg, file, line);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " == ", b, " ", res ? "OK" : "FAILED");
} 

immutable string ANSI_RED = "\x1b[31m";
immutable string ANSI_GREEN = "\x1b[32m";
immutable string ANSI_YELLOW = "\x1b[33m";
immutable string ANSI_RESET = "\x1b[0m";

void AssertIs(T,V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a is b;
	recordTestResult(res, text(a, " is ", b), msg, file, line);
	//	writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? ANSI_GREEN ~ "OK" ~ ANSI_RESET : ANSI_RED ~ "FAILED" ~ ANSI_RESET);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? "OK" : "FAILED");
}

void AssertIsNot(T,V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a !is b;
	recordTestResult(res, text(a, " is not ", b), msg, file, line);
	//	writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? ANSI_GREEN ~ "OK" ~ ANSI_RESET : ANSI_RED ~ "FAILED" ~ ANSI_RESET);
	// writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? "OK" : "FAILED");
}
