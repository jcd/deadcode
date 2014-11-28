module extensions.attr;

public import extension;

import std.typetuple;
import std.traits;

enum isClass(alias T) = is(T == class);
enum isDerivedFromBasicCommand(alias T) = isImplicitlyConvertible!(T, BasicCommand);
enum isPublic(alias T) = T == "public";
enum isAnyPublic(alias T) = anySatisfy!(isPublic, __traits(getProtection, T));
alias isPublicFunction = templateAnd!(isSomeFunction, isAnyPublic);
alias isPublicClassDerivedFromBasicCommand = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicCommand);

template isPublicFunctionInModule(alias Mod)
{
	enum isPublicFunctionInModule(string symName) = isPublicFunction!(__traits(getMember, Mod, symName));
}

template isPublicBasicCommandClassInModule(alias Mod)
{
	enum isPublicBasicCommandClassInModule(string symName) = isPublicClassDerivedFromBasicCommand!(__traits(getMember, Mod, symName));
}

template registerModuleCommandFunctionByName(alias Mod)
{
	alias registerModuleCommandFunctionByName(string symName) = RegisterCommand!(__traits(getMember, Mod, symName));
}

template registerModuleCommandClassByName(alias Mod)
{
	alias registerModuleCommandClassByName(string symName) = BasicCommandWrap!(__traits(getMember, Mod, symName));
}

enum isInvalid(alias T) = T != "x";

alias moduleCommandFunctions(alias Mod) = Filter!(isPublicFunctionInModule!(Mod), __traits(allMembers, Mod));
alias moduleCommandClasses(alias Mod) = Filter!(isPublicBasicCommandClassInModule!(Mod), Filter!(isInvalid, __traits(allMembers, Mod)));

alias extensionCommandFunctions(alias Mod) = staticMap!(registerModuleCommandFunctionByName!Mod, moduleCommandFunctions!Mod);
alias extensionCommandFunctions(string Mod = __MODULE__) = staticMap!(registerModuleCommandFunctionByName!(mixin(Mod)), moduleCommandFunctions!(mixin(Mod)));

alias extensionCommandClasses(alias Mod) = moduleCommandClasses!Mod;
// alias extensionCommandClasses(string Mod = __MODULE__) = moduleCommandClasses!(mixin(Mod));
alias extensionCommandClasses(string Mod = __MODULE__)   = staticMap!(registerModuleCommandClassByName!(mixin(Mod)), moduleCommandClasses!(mixin(Mod)));

alias getCommandFunctionFunction(alias F) = F.Function;

template registerCommands(string Mod = __MODULE__) 
{	
	import std.typetuple;
	pragma(msg, "Registering command functions: ", staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod));
	//alias x = TypeTuple!(extensionCommandClasses!Mod);
	pragma(msg, "Registering command classes  : ", TypeTuple!(extensionCommandClasses!Mod));
}
