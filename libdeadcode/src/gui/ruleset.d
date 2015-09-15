module gui.ruleset;

import std.exception;
import std.range;
import std.regex;

import test;
mixin registerUnittests;


class InvalidRuleKeyError : Exception
{
	this(string msg)
	{
		super(msg);
	}
}

class RuleEnv
{
	Type lookupValue(Type)(string key)
	{
		static if (is(Type : string))
			return lookupStringValue(key);
		else static if (is(Type : bool))
			return lookupBoolValue(key);
		else static if (is(Type : int))
			return lookupIntValue(key);
		assert(0);
	}

	abstract bool lookupBoolValue(string key);
	abstract string lookupStringValue(string key);
	abstract int lookupIntValue(string key);
}

class Rule
{
	string key;
	bool negate;

	this (string k)
	{
		key = k;
	}

    abstract protected bool eval(RuleEnv env);
    abstract bool isEqual(Object other) const pure nothrow @safe;

    bool test(RuleEnv env)
	{
		if (negate)
			return !eval(env);
		else
			return eval(env);
	}
}

version(unittest)
{
	class UnitTestRuleEnv : RuleEnv
	{
		override bool lookupBoolValue(string key)
		{
			if (key == "trueBool")
				return true;
			else if (key == "falseBool")
				return false;
			throw new InvalidRuleKeyError(key);
		}

		override string lookupStringValue(string key)
		{
			if (key == "emptyString")
				return "";
			else if (key == "testString")
				return "theTestString";
			else if (key == "allK")
				return "kkkkkkkkkkk";
			throw new InvalidRuleKeyError(key);
		}

		override int lookupIntValue(string key)
		{
			if (key == "zeroInt")
				return 0;
			else if (key == "tenInt")
				return 10;
			throw new InvalidRuleKeyError(key);
		}
	}
}

class EqualRule(Type) : Rule
{
	private Type value;

	this(string k, Type v)
	{
		super(k);
		value = v;
	}

    override bool isEqual(Object other) const pure nothrow @safe
    {
        auto o = cast(EqualRule!Type)other;
        return o !is null && key == o.key && negate == o.negate && value == o.value;
    }

	override protected bool eval(RuleEnv env)
	{
		return env.lookupValue!Type(key) == value;
	}
}

unittest
{

	auto env = new UnitTestRuleEnv();

	auto r1 = new EqualRule!bool("trueBool", true);
	assert(r1.test(env) == true);

	r1 = new EqualRule!bool("falseBool", false);
	Assert(r1.test(env) == true);

	r1 = new EqualRule!bool("falseBool", true);
	Assert(r1.test(env) == false);

	r1 = new EqualRule!bool("falseBool", true);
	r1.negate = true;
	Assert(r1.test(env) == true);

	auto r2 = new EqualRule!bool("unknownBool", true);
	Assert(collectException!InvalidRuleKeyError(r2.test(env)) !is null);
}

class RegexRule : Rule
{
	Regex!char re;

	this(string k, Regex!char _re)
	{
		super(k);
		re = _re;
	}

	this(string k, const(char)[] _re, const(char)[] flags = "")
	{
		super(k);
		re = regex(_re, flags);
	}

    override bool isEqual(Object other) const pure nothrow @safe
    {
        auto o = cast(RegexRule)other;
        return o !is null && key == o.key && negate == o.negate && re == o.re;
    }

	override protected bool eval(RuleEnv env)
	{
		auto val = env.lookupValue!string(key);
		auto m = match(val, re);
		return !m.empty && m.pre.empty && m.post.empty;
	}
}

unittest
{
	auto env = new UnitTestRuleEnv();

	auto r1 = new RegexRule("allK", "k+");
	Assert(r1.test(env) == true);

	// Only match entire content and not sub content
	r1 = new RegexRule("allK", "kkk");
	Assert(r1.test(env) == false);

	r1 = new RegexRule("emptyString", "k+");
	Assert(r1.test(env) == false);

	r1 = new RegexRule("testString", ".*estStrin.*");
	Assert(r1.test(env) == true);

	// Only match entire content and not sub content
	r1 = new RegexRule("testString", ".*estStrin");
	Assert(r1.test(env) == false);
}

class RegexContainsRule : Rule
{
	Regex!char re;

	this(string k, Regex!char _re)
	{
		super(k);
		re = _re;
	}

	this(string k, const(char)[] _re, const(char)[] flags = "")
	{
		super(k);
		re = regex(_re, flags);
	}

    override bool isEqual(Object other) const pure nothrow @safe
    {
        auto o = cast(RegexContainsRule)other;
        return o !is null && key == o.key && negate == o.negate && re == o.re;
    }

	override protected bool eval(RuleEnv env)
	{
		auto val = env.lookupValue!string(key);
		return !match(val, re).empty;
	}
}

unittest
{
	auto env = new UnitTestRuleEnv();

	auto r1 = new RegexContainsRule("allK", "k+");
	Assert(r1.test(env) == true);

	// Match sub content
	r1 = new RegexContainsRule("allK", "kkk");
	Assert(r1.test(env) == true);

	r1 = new RegexContainsRule("emptyString", "k+");
	Assert(r1.test(env) == false);

	r1 = new RegexContainsRule("testString", ".*estStrin.*");
	Assert(r1.test(env) == true);

	// Match sub content
	r1 = new RegexContainsRule("testString", ".*estStrin");
	Assert(r1.test(env) == true);
}

class RuleSet
{
	Rule[] rules;

	void addEquals(Type)(string key, Type value, bool negate = false)
	{
		auto v = new EqualRule!Type(key, value);
		v.negate = negate;
		rules ~= v;
	}

	void addRegex(string key, Regex!char r, bool negate = false)
	{
		auto v = new RegexRule(key, r);
		v.negate = negate;
		rules ~= v;
	}

	void addRegex(string key, const(char)[] _re, const(char)[] flags = "", bool negate = false)
	{
		addRegex(key, regex(_re, flags));
	}

	void addRegexContains(string key, Regex!char r, bool negate = false)
	{
		auto v = new RegexContainsRule(key, r);
		v.negate = negate;
		rules ~= v;
	}

	void addRegexContains(string key, const(char)[] _re, const(char)[] flags = "", bool negate = false)
	{
		addRegexContains(key, regex(_re, flags));
	}

    bool isEqual(RuleSet other)
    {
		if (other is null || other.rules.length != rules.length)
            return false;

        foreach (idx, r; rules)
        {
            if (!r.isEqual(other.rules[idx]))
                return false;
        }
        return true;
    }

	bool test(RuleEnv env)
	{
		foreach (v; rules)
			if (!v.test(env))
				return false;
		return true;
	}
}

unittest
{
	auto rs = new RuleSet();

	rs.addEquals("testString", "theTestString");
	rs.addEquals("trueBool", true);
	rs.addEquals("tenInt", 10);
	rs.addRegex("testString", ".*estStri.*");
	rs.addRegexContains("allK", "kkk");

	auto env = new UnitTestRuleEnv();
	Assert(rs.test(env) == true);

	rs.addEquals("tenInt", 12);
	Assert(rs.test(env) == false);
}

