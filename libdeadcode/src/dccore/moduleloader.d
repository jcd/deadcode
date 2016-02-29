module dccore.moduleloader;

struct ModuleLoader(alias Mod, string modFilename)
{
    version (portable)
    {
        enum dllBytes = cast(ubyte[]) import(modFilename);

        bool load()
        {
            import std.stdio;
            try
            {
                import dccore.path;

                import std.file;

                string depacked = buildPath(tempDir(), modFilename);
                writeln("Unpacking to ", depacked);
                std.file.write(depacked, dllBytes);                // Writing the dynlib to a temporary file.
                Mod.load(depacked);                                // Use the depacked dynlib and load its symbols.
            }
            catch(Exception e)
            {
                writeln("Error loading ", Mod.stringof, " lib ", e);
                return false;
            }
            return true;
        }
    }
    else
    {
        bool load()
        {
            import std.stdio;
            try
            {
                Mod.load();
            }
            catch(Exception e)
            {
                writeln("Error loading ", Mod.stringof, " lib ", e);
                return false;
            }
            return true;
        }
    }
}

struct ModuleLoaderRaw(string modFilename)
{
    version (portable)
    {
        enum dllBytes = cast(ubyte[]) import(modFilename);

        bool load()
        {
            import std.stdio;
            try
            {
                import derelict.util.sharedlib;
                import std.file;
                import dccore.path;


                string depacked = buildPath(tempDir(), modFilename);
                writeln("Unpacking to ", depacked);
                std.file.write(depacked, dllBytes);                // Writing the dynlib to a temporary file.
                SharedLib sl;
                sl.load([depacked]);
                // Mod.load(depacked);                                // Use the depacked dynlib and load its symbols.
            }
            catch(Exception e)
            {
                writeln("Error loading ", modFilename, " lib ", e);
                return false;
            }
            return true;
        }
    }
    else
    {
        bool load()
        {
            return true;
        }
    }
}
