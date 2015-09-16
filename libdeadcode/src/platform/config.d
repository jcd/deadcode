module platform.config;

static import core.uri;
import std.format : format;
import std.path;

private string _resourcesRoot;
private string _binariesRoot;

enum appName = "DeadCode";

@property
{
    string resourcesRoot()
    {
        return _resourcesRoot;
    }

    void resourcesRoot(string r)
    {
        _resourcesRoot = r;
    }

    string binariesRoot()
    {
        return _binariesRoot;
    }

    void binariesRoot(string r)
    {
        _binariesRoot = r;
    }
}


version (Windows)
{
    immutable string builtinFontPath = r"C:\Windows\Fonts\verdana.ttf";

    import std.c.windows.windows;
    extern (Windows)
    {
        nothrow export BOOL SHGetSpecialFolderPathA(HWND hwndOwner, LPTSTR lpszPath, int csidl, BOOL fCreate);
    }

    void addFileBrowserContextMenuItem(string name, string command)
    {
        setupRegistryEntry(format(r"Software\Classes\*\shell\%s\command", name), command);
    }

    string getOrSetConfigField(string key, string value)
    {
        return setupRegistryEntry(format(r"Software\SteamWinter\DeadCode\%s", key), value);
    }

    private string setupRegistryEntry(string keyPath, string value)
	{
		import core.sys.windows.windows;
		import std.stdio;
		import std.string;

		HKEY pRegKey;
		LONG lRtnVal = 0;
		DWORD disposition;

		// Call to RegCreateKeyEx
		lRtnVal = RegCreateKeyExA(
								  HKEY_CURRENT_USER,
								  keyPath.toStringz(),
								  0,
								  null,
								  REG_OPTION_NON_VOLATILE,
								  KEY_ALL_ACCESS,
								  null,
								  &pRegKey,
								  &disposition);

		// Check GetLastError to check error condition
		if(lRtnVal != ERROR_SUCCESS)
		{
			writefln("RegCreateKeyEx failed: %s %s\n", keyPath, lRtnVal);
			return null;
		}

		scope (exit) RegCloseKey(pRegKey);

		//debug addMessage("Disposition: %s %d\n", keyPath, disposition);

		if (disposition == REG_CREATED_NEW_KEY)
		{
			// set the value
			auto execPathC = value.toStringz();
			lRtnVal = RegSetValueExA (pRegKey,
									  null,
									  0,
									  REG_SZ,
									  cast(ubyte*)execPathC,
									  value.length + 1);

			if(lRtnVal != ERROR_SUCCESS)
			{
				writefln("RegSetValueEx failed: %s %s\n", keyPath, lRtnVal);
				return null;
			}
		}
		else
		{
			uint regType;
			uint strSize = 1024;
			char[1024] str;
			lRtnVal = RegQueryValueExA(pRegKey, null, null, &regType, str.ptr, &strSize);
			if(lRtnVal != ERROR_SUCCESS)
			{
				writefln("RegQueryKeyValueEx failed: %s %s\n", keyPath, lRtnVal);
				return null;
			}
			return str[0..strSize-1].idup;
		}
		return null;
	}
}
version (linux)
{
    immutable string builtinFontPath = r"/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";

    import std.format;

    void addFileBrowserContextMenuItem(string name, string command)
    {
       // setupRegistryEntry(format(r"Software\Classes\*\shell\%s\command", name), command);
        //analyticsKey = setupRegistryEntry(r"Software\SteamWinter\Ded",
        //                                  randomUUID().toString());
    }

    string getOrSetConfigField(string key, string value)
    {
        import std.file;

        auto u = resourceURI(key);

        mkdirRecurse(u.dirName.uriString);

        if (exists(u.uriString))
            value = readText(u.uriString);
        else
            std.file.write(u.uriString, value);
	return value;    
	}
}


/** The location that is use as base for relative paths/URIs.
*/
enum ResourceBaseLocation : uint
{
	currentDir = 1,    /// The current working directory
	executableDir = 2, /// The dir of this executable
	resourceDir = 4,   /// The default resources dir
	binariesDir = 8,   /// The default binary helper executables dir
	userDataDir = 16,  /// The user data dir which is platform specific
	sessionDir = 32,   /// Session temporary dir. Is cleared upon start and stop of app.
	homeDir = 64,      /// The user home dir which is platform specific
}

core.uri.URI resourceURI(string path, ResourceBaseLocation base = ResourceBaseLocation.userDataDir)
{
    if (isAbsolute(path))
    {
        auto res = new core.uri.URI(path);
        res.normalize();
        return res;
    }

    import core.stdc.string;
    string basePath;
    final switch (base)
    {
        case ResourceBaseLocation.currentDir:
            basePath = absolutePath(std.file.getcwd());
            break;
        case ResourceBaseLocation.executableDir:
            basePath = absolutePath(std.file.thisExePath().dirName());
            break;
        case ResourceBaseLocation.resourceDir:
            basePath = resourcesRoot;
            break;
        case ResourceBaseLocation.binariesDir:
            basePath = binariesRoot;
            break;
        case ResourceBaseLocation.sessionDir:
            // TODO: implement
            std.stdio.writeln("Error: Implement sessionDir");
            break;
        case ResourceBaseLocation.userDataDir:
            version (Windows)
            {
				char[MAX_PATH] buffer;
				auto CSIDL_APPDATA = 0x001a;
				void* dummy;
				if (SHGetSpecialFolderPathA(dummy, buffer.ptr, CSIDL_APPDATA, 0) == TRUE)
					basePath = absolutePath(buildPath(buffer[0..strlen(buffer.ptr)].idup, appName));
				else
					throw new Exception("Cannot get APPDATA dir");
            }
            version (linux)
            {
                import std.process;
                import std.path;
                string home = environment.get("XDG_DATA_HOME", expandTilde("~/.local/share"));
                basePath = absolutePath(buildPath(home, appName));
            }
            break;
        case ResourceBaseLocation.homeDir:
            version (Windows)
            {
				char[MAX_PATH] buffer;
				auto CSIDL_PROFILE = 0x0028;
				void* dummy;
				if (SHGetSpecialFolderPathA(dummy, buffer.ptr, CSIDL_PROFILE, 0) == TRUE)
					basePath = buildPath(buffer[0..strlen(buffer.ptr)].idup);
				else
					throw new Exception("Cannot get HOME dir");
            }
            version (linux)
            {
                string home = expandTilde("~");
                basePath = absolutePath(home);
            }
            break;
    }

    auto u = new core.uri.URI(buildNormalizedPath(basePath, path));
    u.normalize();
    return u;
}
