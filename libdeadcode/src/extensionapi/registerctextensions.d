module extensionapi.registerctextensions;

template registerCommands(string Mod = __MODULE__)
{
    import extensionapi.commandregisterct;
    import extensionapi.extensionregisterct;
    import extensionapi.widgetregisterct;

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
	        alias _commandFunctionsCTRegister = commandFunctionsCTRegister!(mixin(Mod));
		    alias _commandClassesCTRegister = commandClassesCTRegister!(mixin(Mod));
		    alias _extensionClassesCTRegister = extensionClassesCTRegister!(mixin(Mod));
		    alias _widgetClassesCTRegister = widgetClassesCTRegister!(mixin(Mod));
        }
    }
}
