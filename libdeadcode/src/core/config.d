module core.config;

version (Windows)
{
	
	string setupRegistryEntry(string keyPath, string value)
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
