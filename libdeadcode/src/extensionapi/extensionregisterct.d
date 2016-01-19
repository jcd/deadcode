module extensionapi.extensionregisterct;

import dccore.attr : isClass;
import extensionapi.registerct;
import extensionapi.extension : Extension, RegisterExtension;

import std.meta : AliasSeq, Filter, staticMap, templateAnd;
import std.traits : isImplicitlyConvertible;

// Support for compile time reflecting a given module for extension extensions and
// registering them for static init() on startup

enum isDerivedFromExtension(alias T) = isImplicitlyConvertible!(T, Extension);
alias isPublicClassDerivedFromExtension = templateAnd!(isClass, isAnyPublic, isDerivedFromExtension);

template isPublicExtensionClassInModule(alias Mod)
{
	enum isPublicExtensionClassInModule(string symName) = isPublicClassDerivedFromExtension!(__traits(getMember, Mod, symName));
}

template registerModuleExtensionClassByName(alias Mod)
{
	alias registerModuleExtensionClassByName(string symName) = RegisterExtension!(__traits(getMember, Mod, symName));
}

alias moduleExtensionClasses(alias Mod) = Filter!(isPublicExtensionClassInModule!Mod, Filter!(isAccessible2!Mod, __traits(allMembers, Mod)));
alias extensionExtensionClasses(alias Mod) = staticMap!(registerModuleExtensionClassByName!Mod, moduleExtensionClasses!Mod);
alias extensionClassesCTRegister(alias Mod) = AliasSeq!(extensionExtensionClasses!Mod);

template registerExtensions(string Mod = __MODULE__)
{
	import std.typetuple;
    alias extensionClassesCTRegister = extensionClassesCTRegister!Mod;
}
