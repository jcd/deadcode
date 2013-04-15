module system;

import core.sys.windows.windows;
import std.string;

string getRunningExecutablePath()
{
	char[1024] buf;
	DWORD res = GetModuleFileNameA(cast(void*)0, buf.ptr, 1024);
	auto idx = lastIndexOf(buf[0..res], '\\'); 
	string p = buf[0 .. idx+1].idup;
	return p;
}
