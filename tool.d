import std.conv;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.getopt;

void usage()
{
	write("""tool [-h] [--batch|-b] [--uploadTo|-u dest] <-outputVersion|-o ver> 
		""");
}

void main(string[] args)
{
	bool batchMode = false;
	bool showUsage = false;
	string outputVersion = null;
	auto uploadPath = "jcd@freeze.steamwinter.com:webdownloads/";

	getopt(args,
		"help|h", &showUsage,
		"batch|b", &batchMode,
		"outputVersion|o", &outputVersion,
		"uploadTo|u", &uploadPath);

	if (showUsage)
	{
		usage();
		return;
	}

	if (outputVersion is null)
	{
		writeln("Version argument must be specified e.g. 0.1");
		return;
	}

	auto osStr = to!string(std.system.os);
	auto outputPath = buildPath("dist", format("ded-%s_%s.zip", outputVersion, osStr));
	auto packRoot = buildPath("dist", "files-" ~ osStr);
	
	writeln("Packroot is ", packRoot);

	// clean up
	rmdirRecurse(packRoot);
	mkdirRecurse(packRoot);

	collect(packRoot);
	archive(packRoot, outputPath);
	upload(outputPath, uploadPath);
}

void collect(string packRoot)
{
	string[] files = [
		"ded.exe",
		"ded_d.exe",
		"SDL2.dll",
		"SDL2_image.dll",
		"SDL2_ttf.dll",
		"libfreetype-6.dll",
		"libpng16-16.dll",
		"zlib1.dll",
		"white.png"
	];

	writeln("Copying");

	foreach (f; files)
	{
		string dest =  buildPath(packRoot, f);
		std.stdio.writeln(f, " => ", dest);
		if (exists(dest))
			remove(dest);
		copy(f, dest);
	}

	auto r = dirEntries("resources", SpanMode.depth);
	foreach (name; r)
	{
		string src = name;
		string srcDir = isDir(name) ? name : dirName(name);
		string dest = buildPath(packRoot, name);
		string destDir = buildPath(packRoot, srcDir);
		
		writeln(src, " => ", dest);

		if (!exists(destDir))
			mkdirRecurse(destDir);

		if (isDir(src))
			continue;

		if (exists(dest))
			remove(dest);
		copy(src, dest);
	}
}

void archive(string packRoot, string outputPath)
{
	string zipcmd = buildPath("external", "7zip", "7za.exe");
	string srcDir = buildPath(".", packRoot, "*"); // need . prefix for 7zip to not include dir part
	
	if (exists(outputPath))
	{
		writeln("Removing existing ", outputPath);
		remove(outputPath);
	}
	
	auto cmd = format("%s a -r %s %s", zipcmd, outputPath, srcDir);
	writeln(cmd);
	auto res = executeShell(cmd);

	if (res.status != 0)
	{
		writeln(format("status %s:", res.status));
		writeln(res.output);
	}
	else
	{
		writeln("\n\nArtifact created: ", absolutePath(outputPath));
	}
}


void upload(string from, string to)
{
	if (!upload(from, to, null))
	{
		writeln("Cannot upload without password.");
		write("password: ");
		string pw = strip(readln());
		upload(from, to, pw);
	}
}

bool upload(string from, string to, string pw)
{
	auto scpCmd = buildPath("external", "putty", "pscp.exe");
	writeln("Uploading to jcd@", to);

	auto cmd = format("%s -batch -q -v -pw %s %s %s", scpCmd, "xxxx", from, to);
	writeln(cmd);

	auto args = [scpCmd, "-batch", "-q", "-v"];
	if (pw !is null)
	{ 
		args ~= "-pw";
		args ~= pw;
	}
	args ~= from;
	args ~= to;

//	auto args = [scpCmd, "-batch", "-q", "-v", "-pw", pw, from, to];
//	auto args = [scpCmd, "-batch", "-q", "-v", from, to];

	bool result = true;
	auto pipes = pipeProcess(args, Redirect.stdout | Redirect.stderr);
	foreach (line; pipes.stdout.byLine)
	{
		if (strip(line).endsWith("Unable to authenticate"))
			result = false;
		writeln(line);
	}
	foreach (line; pipes.stderr.byLine)
	{
		if (strip(line).endsWith("Unable to authenticate"))
			result = false;
		writeln(line);
	}

	int res = wait(pipes.pid);
	if (res != 0)
	{
		writeln(format("status %s:", res));
	}
	else
	{
		writeln("\n\nUploaded to: ", to);
	}
	return result;
}
