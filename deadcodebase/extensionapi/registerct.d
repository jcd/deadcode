module extensionapi.registerct;

import dccore.attr : isAnyPublic;

//template isAccessible(string Mod)
//{
//    template isAccessible(string symName)
//    {
//        static if (__traits(compiles, typeof( mixin("{ import " ~ Mod ~ "; alias UU = " ~ Mod ~ "." ~ symName ~ "; }") )  ) )
//        {
//            enum isAccessible = isAnyPublic!(__traits(getMember, mixin(Mod), symName));
//        }
//        else
//            enum isAccessible = false;
//    }
//}

template isAccessible2(alias Mod)
{
    template isAccessible2(string symName)
    {
        import std.traits;
        enum _fqn = fullyQualifiedName!Mod;
        static if (__traits(compiles, typeof( mixin("{ import " ~ _fqn ~ "; alias UU = " ~ _fqn ~ "." ~ symName ~ "; }") )  ) )
        // static if (__traits(compiles, { alias a  = __traits(getMember, Mod, symName); } ) )
        //pragma(msg, symName, " XX");
        //pragma(msg, symName, " ", __traits(compiles, typeof( mixin("{ import " ~ _fqn ~ "; alias UU = " ~ _fqn ~ "." ~ symName ~ "; }") )  ));
        //pragma(msg, symName, " ", __traits(getProtection, __traits(getMember, Mod, symName)));
        //static if ( is ( typeof(__traits(getMember, Mod, symName)) ) &&
        //            __traits(getProtection, __traits(getMember, Mod, symName)) != "private")
        {
            enum isAccessible2 = isAnyPublic!(__traits(getMember, Mod, symName));
        }
        else
            enum isAccessible2 = false;
    }
}
