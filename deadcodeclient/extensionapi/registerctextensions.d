module extensionapi.registerctextensions;


template registerCommands(string Mod = __MODULE__)
{
    import extensionapi.commandregisterct;

    version (none)
    {
        import std.typetuple;
        pragma(msg, "Registering command functions: ", Mod, " ", staticMap!(getCommandFunctionFunction, extensionCommandFunctions!Mod));
	    pragma(msg, "Registering command classes  : ", Mod, " ", TypeTuple!(extensionCommandClasses!Mod));
    }
    version (all)
    {
        struct CTRegister
        {
	        alias _commandFunctionsCTRegister = commandFunctionsCTRegister!(mixin(Mod));
		    alias _commandClassesCTRegister = commandClassesCTRegister!(mixin(Mod));
        }
    }
}
