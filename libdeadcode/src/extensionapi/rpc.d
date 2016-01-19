module extensionapi.rpc;

version = OutputRPCAPI;

import dccore.attr : isClass, isMethod, isAnyPublic, hasAttributeCurry;
import std.meta : staticMap;
import std.traits;
import std.typecons;
import std.typetuple;

alias isPublicClass = templateAnd!(isClass, isAnyPublic);
alias isPublicMethod = templateAnd!(isMethod, isAnyPublic);


template isPublicInModule(alias Mod)
{
	enum isPublicInModule(string symName) = isAnyPublic!(__traits(getMember, Mod, symName));
}

template isPublicClassInModule(alias Mod)
{
	enum isPublicClassInModule(string symName) = isPublicClass!(__traits(getMember, Mod, symName));
}

template isPublicMethodInClass(alias Cls)
{
//	enum isPublicMethodInClass(string symName) = symName != "slot_t" && isMethod!(__traits(getMember, Cls, symName));
	enum isPublicMethodInClass(string symName) = isMethod!(__traits(getMember, Cls, symName));
}
alias RPCObjectLookup = Object delegate(string typeName, string typeID);

interface IRPCClass
{
    import msgpack;
    void unpackAndCall(Unpacker unpacker, RPCObjectLookup lookup, Object o, ref ubyte[] resultData);
}

IRPCClass[string] g_RPCClasses;

IRPCClass lookupRPCClass(string typeName)
{
    return g_RPCClasses.get(typeName, null);
}

struct RegisterRPCClass(alias Sym, alias _mapMethod)
{
    alias Type = Sym;
    static this()
    {
        g_RPCClasses[RPCClass!(Sym, _mapMethod).name] = new RPCClass!(Sym, _mapMethod);
    }
}

//ubyte[] packRPCResult(T)(ref T r)
//{
//    T = lookupRPCClass(T.stringof);
//    return pack(r);
//}
//
//ubyte[] packRPCResult(T : BufferView)(ref T r)
//{
//    return pack(r.id);
//}

template genParams(Types...)
{
    template genParams(Idents...)
    {
        // pragma (msg, "GenParams ", Types, Idents);
        // import extensionapi.types;
        // alias genParams = genParamsDirect!(
        static if (Types.length == 0)
            enum genParams = "";
        else static if (Types.length == 1)
            enum genParams = Types[0].stringof ~ " " ~ Idents[0];
        else
        {
            alias gp = .genParams!(Types[1..$]);
            enum genParams = Types[0].stringof ~ " " ~ Idents[0] ~ ", " ~ gp!(Idents[1..$]);
        }

    }
}

//template genParamsDirect

template paramTypesToUnpackTypes(Types...)
{
    static if (Types.length == 0)
    {
        alias paramTypesToUnpackTypes = AliasSeq!();
    }
    else static if (Types.length == 1)
    {
        static if (is(Types[0] == class))
            alias paramTypesToUnpackTypes = string;
        else
            alias paramTypesToUnpackTypes = Types[0];
    }
    else
    {
        alias paramTypesToUnpackTypes = AliasSeq!(paramTypesToUnpackTypes!(Types[0]), Types[1..$]);
    }
}

Tuple!Params lookupObjectParams(UnpackedParams, Params...)(RPCObjectLookup lookup, UnpackedParams up)
{
    Tuple!Params params;

    foreach (i, ParamType; AliasSeq!Params)
    {
        static if (is(ParamType == class))
        {
            params[i] = cast(ParamType) lookup(ParamType.stringof, up[i]);
        }
        else
        {
            params[i] = up[i];
        }
    }
    return params;
}

class RPCClass(alias Sym, alias _mapMethod) : IRPCClass
{
    import msgpack;

    enum name = Sym.stringof;
    alias Type = Sym;

    alias Methods = _mapMethod!(RegisterRPCClass!(Sym, _mapMethod));

    version (OutputRPCAPI)
    {
        enum RPCAPIPREFIX = "RPCAPI_" ~ Sym.stringof ~ ":";
        pragma(msg, RPCAPIPREFIX, "class ", Sym.stringof, " : RPCProxy {");
    }

    version (OutputRPCAPI)
        static if ( hasMember!(Sym, "id") )
            pragma(msg, RPCAPIPREFIX, "    " ~ typeof(Sym.id).stringof ~ " id;");

    void unpackAndCall(Unpacker unpacker, RPCObjectLookup lookup, Object o, ref ubyte[] resultData)
    {
        Type obj = cast(Type) o;
        import std.range;

        string methodName;
        unpacker.unpack(methodName);
        foreach (m; Methods)
        {
            if (m.name == methodName)
            {
                alias ParamTypes = Parameters!(m.Method);
                alias ParamUnpackTypes = paramTypesToUnpackTypes!ParamTypes;
                alias ParamIdents = ParameterIdentifierTuple!(m.Method);
                enum ParamCount = ParamTypes.length;
                alias Returning = ReturnType!(m.Method);
                alias Typ = genParams!(ParamTypes);
                version (OutputRPCAPI)
                {
                    //pragma(msg, "paramtypes ", ParamTypes);a
                    pragma(msg, RPCAPIPREFIX, "    ", Returning.stringof, " ", m.name, "(", Typ!(ParamIdents), ") { mixin(RPCProxyMethodMixin); }");
                }

                // pragma(msg, RPCAPIPREFIX, "    ", Returning.stringof, " ", m.name, "(");
                //foreach (i, ident; ParamIdents)
                //{
                //    pragma(msg, RPCAPIPREFIX, "        ", i == 0 ? "" : ", ", ParamTypes[i].stringof, " ", ident);
                //}
                //pragma(msg, RPCAPIPREFIX, "        ) { mixin(RPCProxyMethodMixin); }");

                static if (ParamTypes.length == 0)
                {
                    static if (is(Returning : void))
                        __traits(getMember, obj, m.name)();
                    else
                        auto result = __traits(getMember, obj, m.name)();
                }
                else static if (ParamTypes.length == 1)
                {
                    ParamUnpackTypes unpackParams;
                    unpacker.unpack(unpackParams);
                    auto up  = tuple(unpackParams);
                    Tuple!ParamTypes params = lookupObjectParams!(typeof(up),ParamTypes)(lookup, up);

                    static if (is(Returning : void))
                        __traits(getMember, obj, m.name)(params[0]);
                    else
                        auto result = __traits(getMember, obj, m.name)(params[0]);
                }
                else static if (ParamTypes.length == 2)
                {
                    ParamUnpackTypes unpackParams;
                    unpacker.unpack(unpackParams);
                    auto up  = tuple(unpackParams);
                    Tuple!ParamTypes params = lookupObjectParams!(typeof(up),ParamTypes)(lookup, up);
                    static if (is(Returning : void))
                        __traits(getMember, obj, m.name)(params[0], params[1]);
                    else
                        auto result = __traits(getMember, obj, m.name)(params[0], params[1]);
                }
                else static if (ParamTypes.length == 3)
                {
                    ParamUnpackTypes unpackParams;
                    unpacker.unpack(unpackParams);
                    auto up  = tuple(unpackParams);
                    Tuple!ParamTypes params = lookupObjectParams!(typeof(up), ParamTypes)(lookup, up);
                    static if (is(Returning : void))
                        __traits(getMember, obj, m.name)(params[0], params[1], params[2]);
                    else
                        auto result = __traits(getMember, obj, m.name)(params[0], params[1], params[2]);
                }

                // Serialize result. also convert know object types to ids.

                static if (!is(Returning : void))
                {
                    static if (is(Returning == class))
                    {
                        //if (hasMember!(Returning, "id"))
                        //{
                            resultData = pack(result.id);
                        //}
                        //else
                        //{
                        //    pragma(msg, "Trying to RPC return class with no id property: ", Returning.stringof);
                        //}
                    }
                    else
                    {
                        resultData = pack(result);
                    }
                }
            }
        }
        version (OutputRPCAPI)
        {
            pragma(msg, RPCAPIPREFIX, "}");
            pragma(msg, RPCAPIPREFIX); // newline
        }
    }

    //pragma(msg, Sym, " methods ", Methods);
}

alias RPCIdentifiers = AliasSeq!("isAccessible", "accessibleMembers", "isAccessible3", "accessibleMembersByAlias",
                                 "accessiblePublicMembers", "getMemberAlias", "accessiblePublicClasses",
                                 "accessiblePublicClassMembers", "CreateInstance", "RegisterRPCMethod",
                                 "registerModuleRCPClassByName",
                                 "registerModuleRCPMethodByName", "mapMethod", "mapMethod2"
                                 );

	import std.typetuple;
    import std.traits;

    private template isAccessible4(alias Mod)
    {
        template isAccessible4(string symName)
        {
            import std.traits;
            enum _fqn = fullyQualifiedName!Mod;
            static if (__traits(compiles, typeof( mixin("{ import " ~ _fqn ~ "; alias UU = " ~ _fqn ~ "." ~ symName ~ "; }") )  ) )
            {
                static if ( staticIndexOf!(symName, RPCIdentifiers) != -1 )
                {
                    enum isAccessible4 = false;
                }
                else
                {
                    enum isAccessible4 = isAnyPublic!(__traits(getMember, Mod, symName));
                }
            }
            else
                enum isAccessible4 = false;
        }
    }

    private template isAccessible3b(alias Cls)
    {
        template isAccessible3b(string symName)
        {
            import std.traits;
            //enum _fqn = fullyQualifiedName!Cls;
            //static if (__traits(compiles, typeof( mixin("{ import " ~ _fqn ~ "; alias UU = " ~ _fqn ~ "." ~ symName ~ "; }") )  ) )
            // pragma(msg, "FOOOO ", symName, " " , is( typeof(Identity!(__traits(getMember, Cls, symName)))));
            static if ( is( typeof(Identity!(__traits(getMember, Cls, symName))) )  )
            {
                enum isAccessible3b = isAnyPublic!(__traits(getMember, Cls, symName));
            }
            else
                enum isAccessible3b = false;
        }
    }

    private template accessibleMembers(alias Mod)
    {
        alias accessibleMembers = Filter!(isAccessible4!Mod, __traits(allMembers, Mod));
    }

    private enum isAccessible3(alias name) = name == "setLogFile" || name == "onFileDropped" || name == "quit" || name == "hello" || name == "getCurrentBuffer" || name == "name" || name == "bufferViewParamTest" || name == "value" || name == "addCommand" || name == "addMenuItem" || name == "addCommandShortcuts" || name == "execute" || name == "canExecute";

    private template accessibleMembersByAlias(alias Cls)
    {
        alias accessibleMembersByAlias = Filter!(isAccessible3b!Cls, __traits(allMembers, Cls));
    }

    private template accessiblePublicMembers(string Mod = __MODULE__)
    {
        alias accessiblePublicMembers =  Filter!(isPublicInModule!(mixin(Mod)), accessibleMembers!Mod);
    }

    private template getMemberAlias(alias Mod)
    {
        alias getMemberAlias(string Mem) = Identity!(__traits(getMember, Mod, Mem));
    }

    private template accessiblePublicClasses(alias Mod)
    {
        alias accessiblePublicClasses =  staticMap!(getMemberAlias!Mod, Filter!(isPublicClassInModule!Mod, accessibleMembers!Mod));
    }

    private template accessiblePublicClassMembers(alias Cls)
    {
        pragma(msg, Cls);
        pragma(msg, accessibleMembersByAlias!Cls);
        alias accessiblePublicClassMembers = staticMap!(getMemberAlias!Cls, Filter!(isPublicMethodInClass!Cls, accessibleMembersByAlias!Cls));
        //alias accessiblePublicClassMembers = staticMap!(getMemberAlias!Cls, Filter!(isPublicMethodInClass!Cls, accessibleMembersByAlias!Cls));
    }

    private enum CreateInstance(T) = T.init;


    private struct RegisterRPCMethod(alias Cls, alias Meth)
    {
        enum fullName = fullyQualifiedName!Meth;
        enum name = __traits(identifier, Meth);
        alias Type = Cls;
        alias Method = Meth;

        pragma(msg, "method ", fullyQualifiedName!Method, " ", __traits(parent, Method));
    }

    private template registerModuleRCPClassByName(alias Mod)
    {
        alias registerModuleRCPClassByName(alias Sym) = RegisterRPCClass!(Sym, mapMethod);
    }

    private template registerModuleRCPMethodByName(alias Mod)
    {
        template registerModuleRCPMethodByName(alias Sym)
        {
            alias registerModuleRCPMethodByName = RegisterRPCMethod!(Mod, Sym);
        }
    }



    private alias mapMethod(Cls) = staticMap!(registerModuleRCPMethodByName!(Cls.Type), Filter!(hasAttributeCurry!RPC, accessiblePublicClassMembers!(Cls.Type)));
    private alias mapMethod2(Cls) = accessiblePublicClassMembers!(Cls.Type);


alias rpcClassesCTRegister(alias Mod) = staticMap!(registerModuleRCPClassByName!Mod, Filter!(hasAttributeCurry!RPC, accessiblePublicClasses!Mod));

    template registerRPC(string Mod = __MODULE__)
    {

    version (none)
    {
        pragma(msg, "Registering command functions: ", Mod, " ", staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod));
	    pragma(msg, "Registering command classes  : ", Mod, " ", TypeTuple!(extensionCommandClasses!Mod));
	    pragma(msg, "Registering widget classes  : ", Mod, " ", TypeTuple!(extensionWidgetClasses!Mod));
    }
    version (all)
    {
        private struct CTRegisterRPC
        {
            alias rpcTypes = rpcClassesCTRegister!(mixin(Mod));
            pragma(msg, rpcTypes);

            //alias rpcTypesMethods = staticMap!(mapMethod, rpcTypes);
            //pragma(msg, rpcTypesMethods);
            //import std.traits;
            //pragma(msg, getSymbolsByUDA(mixin(Mod), RPC));
        }
    }
}

// Attribute specifying that a type or method should be exposed to remote procedure calls
struct RPC
{
}
