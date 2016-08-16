module platform.config;

import dccore.path;

static import dccore.uri;
import std.format : format;

enum appName = "DeadCode";

// DEPRECTATED APU. Use Paths instead.
dccore.uri.URI resourceURI(string path, PathBase base = PathBase.userDataDir)
{
    return new dccore.uri.URI(paths.based(base, path));
}

/** The location that is use as base for relative paths/URIs.
*/
enum PathBase : uint
{
	currentDir = 1,    /// The current working directory
	executableDir = 2, /// The dir of this executable
	resourceDir = 4,   /// The default resources dir
	binariesDir = 8,   /// The default binary helper executables dir
	userDataDir = 16,  /// The user data dir which is platform specific
	sessionDir = 32,   /// Session temporary dir. Is cleared upon start and stop of app.
	homeDir = 64,      /// The user home dir which is platform specific
}

@CtxAutoCreate
class Paths
{
	enum CtxAutoCreate = true; 

	void setResourcesRoot(string r)
	{
		_resourcesRoot = r;
	}

	void setBinariesRoot(string r)
	{
		_binariesRoot = r;
	}

	string current(string relativePath = null) const 
	{
		return based(PathBase.currentDir, relativePath);
	}

	string executable(string relativePath = null) const 
	{
		return based(PathBase.executableDir, relativePath);
	}

	string resource(string relativePath = null) const 
	{
		return based(PathBase.resourceDir, relativePath);
	}

	string binary(string relativePath = null) const 
	{
		return based(PathBase.binariesDir, relativePath);
	}

	string userData(string relativePath = null) const 
	{
		return based(PathBase.userDataDir, relativePath);
	}

	string session(string relativePath = null) const 
	{
		return based(PathBase.sessionDir, relativePath);
	}

	string home(string relativePath = null) const 
	{
		return based(PathBase.homeDir, relativePath);
	}

	string based(PathBase base, string relativePath = null) const
	{
		if (isAbsolute(relativePath))
		{
			auto res = new dccore.uri.URI(relativePath);
			res.normalize();
			return res.uriString;
		}

		import core.stdc.string;
		string basePath;
		final switch (base)
		{
			case PathBase.currentDir:
				basePath = absolutePath(std.file.getcwd());
				break;
			case PathBase.executableDir:
				basePath = absolutePath(std.file.thisExePath().dirName());
				break;
			case PathBase.resourceDir:
				basePath = _resourcesRoot;
				break;
			case PathBase.binariesDir:
				basePath = _binariesRoot;
				break;
			case PathBase.sessionDir:
				// TODO: implement
				std.stdio.writeln("Error: Implement sessionDir");
				break;
			case PathBase.userDataDir:
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
					import dccore.path;

					string home = environment.get("XDG_DATA_HOME", expandTilde("~/.local/share"));
					basePath = absolutePath(buildPath(home, appName));
				}
				break;
			case PathBase.homeDir:
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

		auto u = new dccore.uri.URI(buildNormalizedPath(basePath, relativePath));
		u.normalize();
		return u.uriString;
	}

private:
	string _resourcesRoot;
	string _binariesRoot;
}

import dccore.ctx;

// Convenience property for access cached Ctx.Get!Paths
private CtxVar!Paths _paths;
@property Paths paths()
{
	return _paths;
}

@property
{
    string resourcePath()
    {
        return paths.resource();
    }

    string binaryPath()
    {
        return paths.binary();
    }
}


version (Windows)
{
    immutable string builtinFontPath = r"C:\Windows\Fonts\verdana.ttf";

    import core.sys.windows.windows;
    extern (Windows)
    {
        nothrow export BOOL SHGetSpecialFolderPathA(HWND hwndOwner, char* lpszPath, int csidl, BOOL fCreate);
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

    string defaultExecExtension(string path)
    {
		return defaultExtension(path, ".exe");
    }


    pragma(lib, "kernel32");
    extern (Windows) DWORD GetLongPathNameW(LPCWSTR lpszShortPath, LPWSTR lpszLongPath, DWORD chBuffer);

    string statFilePathCase(string inPath)
    {
        import std.conv;
        import std.internal.cstring;
        import std.windows.syserror;
        import std.string;

        string ipath = r"\\?\" ~ inPath.replace("/", r"\");
        enum numChars = 32767;
        static wchar[numChars] buf;

        DWORD res = GetLongPathNameW(ipath.tempCStringW(), buf.ptr, numChars);
        if (res == 0)
            throw new Exception("Error getting long case of file " ~ sysErrorString(GetLastError()));

        return buf[4..res].to!string.replace(r"\", "/");
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

    string defaultExecExtension(string path)
    {
		return path;
    }

    string statFilePathCase(string inPath)
    {
        return inPath;
    }
}
