module extensionapi.widgetregisterct;

import dccore.attr : isClass;
import extensionapi.registerct;

import std.meta : AliasSeq, Filter, staticMap, templateAnd;
import std.traits : isImplicitlyConvertible;

// Support for compile time reflecting a given module for widget extensions and
// registering them for static init() on startup

import extensionapi.widget : BasicWidget, BasicWidgetWrap;
enum isDerivedFromBasicWidget(alias T) = isImplicitlyConvertible!(T, BasicWidget);
alias isPublicClassDerivedFromBasicWidget = templateAnd!(isClass, isAnyPublic, isDerivedFromBasicWidget);

template isPublicBasicWidgetClassInModule(alias Mod)
{
	enum isPublicBasicWidgetClassInModule(string symName) = isPublicClassDerivedFromBasicWidget!(__traits(getMember, Mod, symName));
}

template registerModuleWidgetClassByName(alias Mod)
{
	alias registerModuleWidgetClassByName(string symName) = BasicWidgetWrap!(__traits(getMember, Mod, symName));
}

alias moduleWidgetClasses(alias Mod) = Filter!(isPublicBasicWidgetClassInModule!Mod, Filter!(isAccessible2!Mod, __traits(allMembers, Mod)));

//alias extensionWidgetClasses(alias Mod) = moduleWidgetClasses!Mod;
alias extensionWidgetClasses(alias Mod) = staticMap!(registerModuleWidgetClassByName!Mod, moduleWidgetClasses!Mod);

alias widgetClassesCTRegister(alias Mod) = AliasSeq!(extensionWidgetClasses!Mod);
