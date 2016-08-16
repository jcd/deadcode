module dccore.attr;

import std.traits : isSomeFunction;

enum isClass(alias T) = is(T == class);
enum isMethod(alias T) = isSomeFunction!T;
enum isMethod(T) = false;
enum isPublic(alias T) = T == "public";
enum isAnyPublic(alias T) = anySatisfy!(isPublic, __traits(getProtection, T));


/** Compile time check if a type equals another type

	Template accepting a type and will in turn create a homonym template accepting another type.
	The final template value will be true if the two types are equal and false if not.
*/
template isType(TheseTypes) 
{
	template isType(alias OtherType)
	{
		enum isType = is(typeof(OtherType) == TheseTypes);
	}
	template isType(OtherType)
	{
		enum isType = is(OtherType == TheseTypes);
	}
}

template isType(TheseTypes...) if (TheseTypes.length > 1)
{
	template isType(alias OtherType)
	{
		enum isType = anySatisfy!(.isType!OtherType, TheseTypes);
	}
	template isType(OtherType)
	{
		enum isType = anySatisfy!(.isType!OtherType, TheseTypes);
	}
}

/** Compile time check if a type does not equal another type

Template accepting a type and will in turn create a homonym template accepting another type.
The final template value will be true if the two types are unequal and false if not.
*/
template isNotType(TheseTypes)
{
	template isNotType(alias OtherType)
	{
		enum isNotType = ! is(typeof(OtherType) == TheseTypes);
	}
	template isNotType(OtherType)
	{
		enum isNotType = ! is(OtherType == TheseTypes);
	}
}

template isNotType(TheseTypes...) if (TheseTypes.length > 1)
{
	template isNotType(alias OtherType)
	{
		enum isNotType = ! anySatisfy!(isType!OtherType, TheseTypes);
	}
	template isNotType(OtherType)
	{
		enum isNotType = ! anySatisfy!(isType!OtherType, TheseTypes);
	}
}

/// Compile time check if 'what' has an attibute of type AttrType
alias hasAttribute(alias what, AttrType) = anySatisfy!(isType!AttrType, __traits(getAttributes, what));
template hasAttributeCurry(AttrType)
{
    alias hasAttributeCurry(alias what) = anySatisfy!(isType!AttrType, __traits(getAttributes, what));
}

//alias hasAttribute(What, AttrType) = anySatisfy!(isType!AttrType, __traits(getAttributes, What));

/// Compile time get all attributes on 'what' that have type AttrType
enum getAttributes(alias what, AttrType) = [ Filter!(isType!AttrType, __traits(getAttributes, what)) ];
// enum getAttributes(What, AttrType) = [ Filter!(isType!AttrType, __traits(getAttributes, What)) ];

template isEqual(string One)
{
    enum isEqual(string Other) = One == Other;
}
alias hasDerivedMember(alias what, string memberName) = anySatisfy!(isEqual!memberName, __traits(derivedMembers, what));


struct sillyWalk { int i; }

enum isSillyWalk(alias T) = is(typeof(T) == sillyWalk);

import std.typetuple;
alias hasSillyWalk(alias what) = anySatisfy!(isSillyWalk, __traits(getAttributes, what));
enum hasSillyWalk(what) = false;

alias helper(alias T) = T;
alias helper(T) = T;

void allWithSillyWalk(alias a, alias onEach)() {
    pragma(msg, "Processing: " ~ a.stringof);
    foreach(memberName; __traits(allMembers, a)) {
        // guards against errors from trying to access private stuff etc.
        static if(__traits(compiles, __traits(getMember, a, memberName))) {
            alias member = helper!(__traits(getMember, a, memberName));

            // pragma(msg, "looking at " ~ memberName);
            import std.string;
            static if(!is(typeof(member)) && member.stringof.startsWith("module ")) {
                enum mn = member.stringof["module ".length .. $];
                mixin("import " ~ mn ~ ";");
                allWithSillyWalk!(mixin(mn), onEach);
            }

            static if(hasSillyWalk!(member)) {
                onEach!member;
            }
        }
    }
}

void walkModules(alias a)() {
    pragma(msg, "Processing: " ~ a.stringof);
    foreach(memberName; __traits(allMembers, a)) {
        // guards against errors from trying to access private stuff etc.
        static if(__traits(compiles, __traits(getMember, a, memberName))) {
            alias member = helper!(__traits(getMember, a, memberName));

            pragma(msg, "  Member " ~ memberName);
			static if(!is(typeof(member)))
				pragma(msg, "  " ~ member.stringof);

            // pragma(msg, "looking at " ~ memberName);
            import std.string;
            static if(!is(typeof(member)) && member.stringof.startsWith("module ")) {
                enum mn = member.stringof["module ".length .. $];
                mixin("import " ~ mn ~ ";");
                walkModules!(mixin(mn));
            }
        }
    }
}
