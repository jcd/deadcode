module test;

import std.stdio;

void Assert(lazy bool expMustBeTrue, string msg = "", string file = __FILE__, int line = __LINE__)
{
	bool res = expMustBeTrue();
	writeln("Test ", file, "@", line, " ", msg, ": ", res ? "OK" : "FAILED");
}


void Assert(T,V)(lazy T thisExp, lazy V isEqualToThisExp, string msg = "", string file = __FILE__, int line = __LINE__)
{
	auto a = thisExp();
	auto b = isEqualToThisExp();
	bool res = a == b;
	writeln("Test ", file, "@", line, " ", msg, ": ", a, " == ", b, " ", res ? "OK" : "FAILED");
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
//	writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? ANSI_GREEN ~ "OK" ~ ANSI_RESET : ANSI_RED ~ "FAILED" ~ ANSI_RESET);
	writeln("Test ", file, "@", line, " ", msg, ": ", a, " is ", b, " ", res ? "OK" : "FAILED");
}
