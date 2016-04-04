module extensionapi.commandregisterct;

import dccore.attr : isClass;
import extensionapi.registerct;
import extensionapi.command : Command, RegisterClassCommand, RegisterFunctionCommand;

import std.meta : AliasSeq, Filter, staticMap, templateAnd;
import std.traits : isImplicitlyConvertible, isSomeFunction;

// Support for compile time reflecting a given module for command extensions and
// registering them for static init() on startup

enum isDerivedFromCommand(alias T) = isImplicitlyConvertible!(T, Command);
alias isPublicClassDerivedFromCommand = templateAnd!(isClass, isAnyPublic, isDerivedFromCommand);
alias isPublicFunction = templateAnd!(isSomeFunction, isAnyPublic);

// Filters
template isPublicFunctionInModule(alias Mod)
{
    enum isPublicFunctionInModule(string symName) = isPublicFunction!(__traits(getMember, Mod, symName));
}

template isPublicCommandClassInModule(alias Mod)
{
	enum isPublicCommandClassInModule(string symName) = isPublicClassDerivedFromCommand!(__traits(getMember, Mod, symName));
}

template registerModuleCommandFunctionByName(alias Mod)
{
	alias registerModuleCommandFunctionByName(string symName) = RegisterFunctionCommand!(__traits(getMember, Mod, symName));
}

template registerModuleCommandClassByName(alias Mod)
{
	alias registerModuleCommandClassByName(string symName) = RegisterClassCommand!(__traits(getMember, Mod, symName));
}

alias moduleCommandFunctions(alias ModAlias) = Filter!(isPublicFunctionInModule!(ModAlias), Filter!(isAccessible2!ModAlias, __traits(allMembers, ModAlias)));
alias moduleCommandClasses(alias ModAlias) = Filter!(isPublicCommandClassInModule!(ModAlias), Filter!(isAccessible2!ModAlias, __traits(allMembers, ModAlias)));

alias extensionCommandFunctions(alias ModAlias) = staticMap!(registerModuleCommandFunctionByName!ModAlias, moduleCommandFunctions!(ModAlias));

alias extensionCommandClasses(alias ModAlias) = staticMap!(registerModuleCommandClassByName!ModAlias, moduleCommandClasses!(ModAlias));

alias getCommandFunctionFunction(alias F) = F.Function;

alias commandFunctionsCTRegister(alias Mod) = staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod);
alias commandClassesCTRegister(alias Mod) = AliasSeq!(extensionCommandClasses!Mod);

