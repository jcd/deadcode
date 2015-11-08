module extensions.apitraits;

import extensions.base;

import std.typetuple;
import std.traits;

enum isClass(alias T) = is(T == class);
enum isDerivedFromBasicCommand(alias T) = isImplicitlyConvertible!(T, BasicCommand);
enum isDerivedFromExtension(alias T) = isImplicitlyConvertible!(T, Extension);
enum isDerivedFromBasicWidget(alias T) = isImplicitlyConvertible!(T, BasicWidget);
enum isPublic(alias T) = T == "public";
enum isAnyPublic(alias T) = anySatisfy!(isPublic, __traits(getProtection, T));
alias isPublicFunction = templateAnd!(isSomeFunction, isAnyPublic);
alias isPublicClassDerivedFromBasicCommand = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicCommand);
alias isPublicClassDerivedFromExtension = templateAnd!(isClass, isAnyPublic, isDerivedFromExtension);
alias isPublicClassDerivedFromBasicWidget = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicWidget);

// Filters
template isPublicFunctionInModule(alias Mod)
{
    enum isPublicFunctionInModule(string symName) = isPublicFunction!(__traits(getMember, Mod, symName));
}

template isPublicBasicCommandClassInModule(alias Mod)
{
	enum isPublicBasicCommandClassInModule(string symName) = isPublicClassDerivedFromBasicCommand!(__traits(getMember, Mod, symName));
}

template isPublicExtensionClassInModule(alias Mod)
{
	enum isPublicExtensionClassInModule(string symName) = isPublicClassDerivedFromExtension!(__traits(getMember, Mod, symName));
}

template isPublicBasicWidgetClassInModule(alias Mod)
{
	enum isPublicBasicWidgetClassInModule(string symName) = isPublicClassDerivedFromBasicWidget!(__traits(getMember, Mod, symName));
}

// Registrars
template registerModuleCommandFunctionByName(alias Mod)
{
	alias registerModuleCommandFunctionByName(string symName) = RegisterCommand!(__traits(getMember, Mod, symName));
}

template registerModuleCommandClassByName(alias Mod)
{
	alias registerModuleCommandClassByName(string symName) = BasicCommandWrap!(__traits(getMember, Mod, symName));
}

template registerModuleExtensionClassByName(alias Mod)
{
	alias registerModuleExtensionClassByName(string symName) = RegisterExtension!(__traits(getMember, Mod, symName));
}

template registerModuleWidgetClassByName(alias Mod)
{
	alias registerModuleWidgetClassByName(string symName) = BasicWidgetWrap!(__traits(getMember, Mod, symName));
}

template isAccessible(string Mod)
{
	template isAccessible(string symName)
    {
        static if (__traits(compiles, typeof( mixin("{ import " ~ Mod ~ "; alias UU = " ~ Mod ~ "." ~ symName ~ "; }") )  ) )
        {
            enum isAccessible = isAnyPublic!(__traits(getMember, mixin(Mod), symName));
        }
        else
            enum isAccessible = false;
    }
}

alias moduleCommandFunctions(string Mod) = Filter!(isPublicFunctionInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));
alias moduleCommandClasses(string Mod) = Filter!(isPublicBasicCommandClassInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));
alias moduleExtensionClasses(string Mod) = Filter!(isPublicExtensionClassInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));
alias moduleWidgetClasses(alias Mod) = Filter!(isPublicBasicWidgetClassInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));

//alias extensionCommandFunctions(alias Mod) = staticMap!(registerModuleCommandFunctionByName!Mod, moduleCommandFunctions!Mod);
alias extensionCommandFunctions(string Mod) = staticMap!(registerModuleCommandFunctionByName!(mixin(Mod)), moduleCommandFunctions!(Mod));

//alias extensionCommandClasses(alias Mod) = moduleCommandClasses!Mod;
// alias extensionCommandClasses(string Mod = __MODULE__) = moduleCommandClasses!(mixin(Mod));
alias extensionCommandClasses(string Mod) = staticMap!(registerModuleCommandClassByName!(mixin(Mod)), moduleCommandClasses!(Mod));

alias extensionExtensionClasses(string Mod) = staticMap!(registerModuleExtensionClassByName!(mixin(Mod)), moduleExtensionClasses!(Mod));


//alias extensionWidgetClasses(alias Mod) = moduleWidgetClasses!Mod;
alias extensionWidgetClasses(string Mod) = staticMap!(registerModuleWidgetClassByName!(mixin(Mod)), moduleWidgetClasses!(Mod));


alias getCommandFunctionFunction(alias F) = F.Function;

template registerCommands(string Mod = __MODULE__)
{
	import std.typetuple;

    version (none)
    {
        pragma(msg, "Registering command functions: ", Mod, " ", staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod));
	    pragma(msg, "Registering command classes  : ", Mod, " ", TypeTuple!(extensionCommandClasses!Mod));
	    pragma(msg, "Registering widget classes  : ", Mod, " ", TypeTuple!(extensionWidgetClasses!Mod));
    }
    version (all)
    {
        struct CTRegister
        {
	        alias commandFunctionsCTRegister = staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod);
		    alias commandClassesCTRegister = TypeTuple!(extensionCommandClasses!Mod);
		    alias extensionClassesCTRegister = TypeTuple!(extensionExtensionClasses!Mod);
		    alias widgetClassesCTRegister = TypeTuple!(extensionWidgetClasses!Mod);
        }
    }
}

template registerExtensions(string Mod = __MODULE__)
{
	import std.typetuple;
    alias extensionClassesCTRegister = TypeTuple!(extensionExtensionClasses!Mod);
}
