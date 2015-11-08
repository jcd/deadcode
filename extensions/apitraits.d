module extensions.attr;

import extensions.base;

import std.typetuple;
import std.traits;

enum isClass(alias T) = is(T == class);
enum isDerivedFromBasicCommand(alias T) = isImplicitlyConvertible!(T, BasicCommand);
enum isDerivedFromBasicWidget(alias T) = isImplicitlyConvertible!(T, BasicWidget);
enum isPublic(alias T) = T == "public";
enum isAnyPublic(alias T) = anySatisfy!(isPublic, __traits(getProtection, T));
alias isPublicFunction = templateAnd!(isSomeFunction, isAnyPublic);
alias isPublicClassDerivedFromBasicCommand = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicCommand);
alias isPublicClassDerivedFromBasicWidget = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicWidget);

template isPublicFunctionInModule(alias Mod)
{
	enum isPublicFunctionInModule(string symName) = isPublicFunction!(__traits(getMember, Mod, symName));
}

template isPublicBasicCommandClassInModule(alias Mod)
{
	enum isPublicBasicCommandClassInModule(string symName) = isPublicClassDerivedFromBasicCommand!(__traits(getMember, Mod, symName));
}

template isPublicBasicWidgetClassInModule(alias Mod)
{
	enum isPublicBasicWidgetClassInModule(string symName) = isPublicClassDerivedFromBasicWidget!(__traits(getMember, Mod, symName));
}

template registerModuleCommandFunctionByName(alias Mod)
{
	alias registerModuleCommandFunctionByName(string symName) = RegisterCommand!(__traits(getMember, Mod, symName));
}

template registerModuleCommandClassByName(alias Mod)
{
	alias registerModuleCommandClassByName(string symName) = BasicCommandWrap!(__traits(getMember, Mod, symName));
}

template registerModuleWidgetClassByName(alias Mod)
{
	alias registerModuleWidgetClassByName(string symName) = BasicWidgetWrap!(__traits(getMember, Mod, symName));
}

enum isValid(alias T) = T != "x"; // __traits(compiles, Filter!(isPublicBasicCommandClassInModule!(Mod), T));

template isAccessible(string Mod)
{
    // pragma(msg, Mod);
	enum isAccessible(string symName) = __traits(compiles, mixin(Mod ~ "." ~ symName));
}


alias moduleCommandFunctions(alias Mod) = Filter!(isPublicFunctionInModule!(Mod), __traits(allMembers, Mod));
alias moduleCommandClasses(string Mod) = Filter!(isPublicBasicCommandClassInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));
alias moduleWidgetClasses(alias Mod) = Filter!(isPublicBasicWidgetClassInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));

alias extensionCommandFunctions(alias Mod) = staticMap!(registerModuleCommandFunctionByName!Mod, moduleCommandFunctions!Mod);
alias extensionCommandFunctions(string Mod = __MODULE__) = staticMap!(registerModuleCommandFunctionByName!(mixin(Mod)), moduleCommandFunctions!(mixin(Mod)));

alias extensionCommandClasses(alias Mod) = moduleCommandClasses!Mod;
// alias extensionCommandClasses(string Mod = __MODULE__) = moduleCommandClasses!(mixin(Mod));
alias extensionCommandClasses(string Mod = __MODULE__) = staticMap!(registerModuleCommandClassByName!(mixin(Mod)), moduleCommandClasses!(Mod));

alias extensionWidgetClasses(alias Mod) = moduleWidgetClasses!Mod;
alias extensionWidgetClasses(string Mod = __MODULE__) = staticMap!(registerModuleWidgetClassByName!(mixin(Mod)), moduleWidgetClasses!(Mod));


alias getCommandFunctionFunction(alias F) = F.Function;

template registerCommands(string Mod = __MODULE__)
{
	import std.typetuple;
    version (none)
    {
        pragma(msg, "Registering command functions: ", Mod, " ", staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod));
	    //pragma(msg, "xx ", __traits(allMembers, Mod));
	    //alias x = TypeTuple!(extensionCommandClasses!Mod);
	    pragma(msg, "Registering command classes  : ", Mod, " ", TypeTuple!(extensionCommandClasses!Mod));
	    pragma(msg, "Registering widget classes  : ", Mod, " ", TypeTuple!(extensionWidgetClasses!Mod));
    }
    version (all)
    {
        struct CTRegister
        {
	        alias commandFunctionsCTRegister = staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod);
		    alias commandClassesCTRegister = TypeTuple!(extensionCommandClasses!Mod);
		    alias widgetClassesCTRegister = TypeTuple!(extensionWidgetClasses!Mod);           
        }
    }
}
