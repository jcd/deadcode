module extensionapi.commandregisterct;

import dccore.attr : isClass;
import extensionapi.registerct;
import extensionapi.command : BasicCommand, BasicCommandWrap, RegisterCommand;

import std.meta : AliasSeq, Filter, staticMap, templateAnd;
import std.traits : isImplicitlyConvertible, isSomeFunction;

// Support for compile time reflecting a given module for command extensions and
// registering them for static init() on startup

enum isDerivedFromBasicCommand(alias T) = isImplicitlyConvertible!(T, BasicCommand);
alias isPublicClassDerivedFromBasicCommand = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicCommand);
alias isPublicFunction = templateAnd!(isSomeFunction, isAnyPublic);

// Filters
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

alias moduleCommandFunctions(alias ModAlias) = Filter!(isPublicFunctionInModule!(ModAlias), Filter!(isAccessible2!ModAlias, __traits(allMembers, ModAlias)));
//alias moduleCommandClasses(string Mod) = Filter!(isPublicBasicCommandClassInModule!(mixin(Mod)), Filter!(isAccessible!Mod, __traits(allMembers, mixin(Mod))));
alias moduleCommandClasses(alias ModAlias) = Filter!(isPublicBasicCommandClassInModule!(ModAlias), Filter!(isAccessible2!ModAlias, __traits(allMembers, ModAlias)));

//alias extensionCommandFunctions(alias Mod) = staticMap!(registerModuleCommandFunctionByName!Mod, moduleCommandFunctions!Mod);
alias extensionCommandFunctions(alias ModAlias) = staticMap!(registerModuleCommandFunctionByName!ModAlias, moduleCommandFunctions!(ModAlias));

//alias extensionCommandClasses(alias Mod) = moduleCommandClasses!Mod;
// alias extensionCommandClasses(string Mod = __MODULE__) = moduleCommandClasses!(mixin(Mod));
alias extensionCommandClasses(alias ModAlias) = staticMap!(registerModuleCommandClassByName!ModAlias, moduleCommandClasses!(ModAlias));

alias getCommandFunctionFunction(alias F) = F.Function;

alias commandFunctionsCTRegister(alias Mod) = staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod);
alias commandClassesCTRegister(alias Mod) = AliasSeq!(extensionCommandClasses!Mod);

