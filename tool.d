import std.algorithm;
import std.conv;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.getopt;
import std.array;
import std.net.curl;
import std.regex;

void usage()
{
	auto usageTmpl = """tool <command> [command options...]
Commands
  setup     : Setup development env. e.g. create VS project files.
  build     : Compile and link libraries and executables
  test      : Run tests (building if necessary) optional filter can be provided
  test-file : Run unittest on specific source path(s) relative to libdeadcode/src
  dist      : Create and/or upload installer e.g. tool dist 1.3
  help      : Takes one of the other commands as sole argument
  changes   : Git git changeset comments since provided tag
  ddox      : Build ddox
  listPublished : list published zips on server
""";
 write(usageTmpl);
}

void commandUsage(string cmd)
{
	switch (cmd)
	{
		case "setup":
			setup([], true);
			break;
		case "build":
			build([], true);
			break;
		case "test":
			test([], true);
			break;
		case "test-file":
			testFile([], true);
			break;
		case "dist":
			dist([], true);
			break;
		case "listPublished":
			break;
		case "changes":
			changes([], true);
			break;
		case "ddox":
			ddox([], true);
			break;
		default:
			writeln("Cannot display help for unknown command " ~ cmd);
			break;
	}
}

void main(string[] args)
{
	if (args.length < 2)
	{
		usage();
		return;
	}
	else if (["-h", "/h", "/?", "--help", "/help"].count(args[1].toLower()))
	{
		usage();
		return;
	}

	switch (args[1])
	{
		case "setup":
			setup(args);
			return;
		case "build":
			build(args);
			return;
		case "test":
			test(args);
			return;
		case "test-file":
			testFile(args);
			return;
		case "dist":
			dist(args);
			return;
		case "listPublished":
			listPublished();
			return;
		case "changes":
			changes(args);
			return;
		case "ddox":
			ddox(args);
			return;
        case "generate-resource-pack":
            generateResourcePack(args);
            return;
		case "help":
			if (args.length == 2)
				usage();
			else
				commandUsage(args[2]);
			return;
		default:
			break;
	}
	write("Unknown command : " ~ args[1] ~ ". Use -h for help");
}

void setup(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool setup");
		writeln("generates or updates project files from dub file");
		return;
	}
	auto cmd = "dub generate visuald";
	writeln(cmd);
	auto res = executeShell(cmd);
	writeln(format("status %s:", res.status));
	writeln(res.output);
}

void build(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool build");
		writeln("build the project taking an optional build config argument");
		return;
	}

	auto cmd = "dub build 2>&1";
	if (args.length > 2)
		cmd = "dub build --config=" ~ args[2] ~ " 2>&1";
	writeln(cmd);
	auto res = pipeShell(cmd, Redirect.stdin);
	wait(res.pid);
//	writeln(format("status %s:", res.status));
//	writeln(res.output);
}

void test(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool test");
		writeln("Run all unittest. Takes an optional argument used for filtering output.");
		return;
	}

	string filt = args.length > 2 ? args[2] : "";
	auto cmd = "dub run --config=unittest";
	writeln(cmd);
	auto res = pipeShell(cmd, Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);
	foreach (line; res.stdout.byLine)
	{
		if (filt.empty || line.startsWith("0x") || !line.find(filt).empty || !line.toLower().find("exception").empty)
		{
			writeln(line);
		}
	}
	wait(res.pid);
}

void testFile(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool test-file <path relative to libdeadcode/src/>...");
		writeln("Run unittest for source file specified.");
		return;
	}

    if (args.length < 3)
    {
        writeln("Missing source file(s) argument");
        return;
    }

	auto cmd = r"rdmd.exe -version=Unicode --main -Ilibdeadcode\src -IC:\Users\jonasd\AppData\Roaming\dub\packages\memutils-0.3.1\source -IC:\Users\jonasd\AppData\Roaming\dub\packages\libasync-0.7.1\source -Iexternal\d-libraries -unittest .\libdeadcode\src\";

    foreach (p; args[2..$])
    {
        auto runCmd = cmd ~ p;
        writeln(runCmd);
        auto res = pipeShell(runCmd, Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);
        foreach (line; res.stdout.byLine)
        {
            writeln(line);
        }
        wait(res.pid);
    }
}

void dist(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool dist");
		writeln("collects build results (but will not build), zips them up and uploads to server.");
		writeln("accepts two optional arguments:\n\t--uploadTo|-u : a ssh destination dir to upload to");
		writeln("\t--skipUpload|-s: if set to true the zip is not uploaded (dry run)");
		return;
	}

	bool batchMode = false;
	bool skipUpload = false;
	string outputVersion = null;
	auto uploadPath = "jcd@freeze.steamwinter.com:webdownloads/";

	getopt(args,
		"batch|b", &batchMode,
		// "outputVersion|o", &outputVersion,
		"uploadTo|u", &uploadPath,
		"skipUpload|s", &skipUpload);

	if (args.length < 3)
	{
		writeln("Version argument must be specified e.g. 'tool dist 0.1'");
		return;
	}

	outputVersion = args[2];

	// Make sure the Changelog has been updated
	auto chlog = File("Changelog.txt");
	bool isThisReleaseLine(char[] l)
	{
		auto r = l.startsWith("Release " ~ outputVersion.idup);
		return r;
	}
	auto hasChangelogEntry = chlog.byLine().find!isThisReleaseLine;
	if (hasChangelogEntry.empty)
	{
		writeln("Please update changelog with entries for " ~ outputVersion);
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
	std.file.write(buildPath(packRoot, "version"), outputVersion);
	archive(packRoot, outputPath);
	if (!skipUpload)
	{
		upload(outputPath, uploadPath);
		upload("Changelog.txt", uploadPath);

		writeln("On server:");
		listPublished();
	}
}

void collect(string packRoot)
{
	string[] files = [
		"ded.exe",
		"ded-debug.exe",
        "dcd-server.exe",
		"SDL2.dll",
		"SDL2_image.dll",
		"SDL2_ttf.dll",
		"libfreetype-6.dll",
		"libpng16-16.dll",
		"zlib1.dll",
		"Changelog.txt"
	];

	writeln("Copying");

	foreach (f; files)
	{
		string dest = buildPath(packRoot, f);
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
	auto res = pipeShell(cmd, Redirect.stdin);
	int status = wait(res.pid);

	if (status != 0)
	{
		writeln(format("status %s:", status));
	}
	else
	{
		writeln("\n\nArtifact created: ", absolutePath(outputPath));
	}
}


void upload(string from, string to, bool recursive = false)
{
    static string pw = null;
	if (!upload(from, to, pw, recursive))
	{
		writeln("Cannot upload without password.");
		write("password: ");
		pw = strip(readln());
		upload(from, to, pw, recursive);
	}
}

bool upload(string from, string to, string pw, bool recursive = false)
{
	auto scpCmd = buildPath("external", "putty", "pscp.exe");
	writeln("Uploading to jcd@", to);

	auto cmd = format("%s -batch -q -v -pw %s %s %s", scpCmd, "xxxx", from, to);
	writeln(cmd);

	auto args = [scpCmd, "-batch", "-q", "-v", "-C"];
    if (recursive)
        args ~= "-r";

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
	auto pipes = pipeProcess(args, Redirect.stdout | Redirect.stderrToStdout);
	foreach (line; pipes.stdout.byLine)
	{
		if (strip(line).endsWith("Unable to authenticate"))
			result = false;
		writeln(line);
	}
    //foreach (line; pipes.stderr.byLine)
    //{
    //    if (strip(line).endsWith("Unable to authenticate"))
    //        result = false;
    //    writeln(line);
    //}

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

void listPublished()
{
	auto re = r"<a.*?>(.*?)</a>\s+(.*?)\s+(.*?)\s+(.*)";
	foreach (l; byLine("http://freeze.steamwinter.com/downloads/"))
	{
		auto cap = matchFirst(l, re);
		if (!cap.empty)
		{
			writeln(cap[1], " \t", cap[2], " ", cap[3], "\t", cap[4]);
		}
	}
}

void changes(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool changes <tag name>");
		writeln("Display changes since tag name");
		return;
	}

	if (args.length < 3)
	{
		writeln("Missing tag name argument");
		return;
	}

	string tagName = args[2];

	auto cmd = "git log --oneline " ~ tagName ~ "..HEAD";
	writeln(cmd);
	auto res = executeShell(cmd);
	if (res.status)
	{
		writeln(format("Error code %s:", res.status));
	}
	else
	{
		writeln(res.output);
	}
}

void ddox(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool ddox");
		writeln("Build documenation in ddox format to ...");
		return;
	}

    //if (args.length < 3)
    //{
    //    writeln("Missing tag name argument");
    //    return;
    //}

    bool reuseJSON = false;
    bool uploadToSite = false;
    bool uploadHelpersToSite = false;
    bool skipHTMLGeneration = false;

    getopt(args,
           "reuse-json|r", &reuseJSON,
           "upload|u", &uploadToSite,
           "upload-helpers|h", &uploadHelpersToSite,
           "skip-html-generation|s", &skipHTMLGeneration
           );

    auto cmd = "dub build --config=ddox";
	if (!reuseJSON)
    {
        writeln(cmd);
	    auto res = executeShell(cmd);
	    if (res.status)
	    {
		    writeln(format("Error code %s:", res.status));
            return;
	    }
	    else
	    {
		    writeln(res.output);
	    }

        cmd = r"..\ddox\ddox.exe filter .\docs.json --min-protection=Protected";
        writeln(cmd);
        res = executeShell(cmd);
        if (res.status)
        {
            writeln(format("Error code %s:", res.status));
        }
        else
        {
            writeln(res.output);
        }
    }

	if (!skipHTMLGeneration)
    {
        cmd = r"..\ddox\ddox.exe generate-html --navigation-type=ModuleTree .\docs.json ddox";
	    writeln(cmd);
	    auto res = executeShell(cmd);
	    if (res.status)
	    {
		    writeln(format("Error code %s:", res.status));
	    }
	    else
	    {
		    writeln(res.output);
	    }
    }

    if (uploadToSite)
    {
        auto uploadPath = "jcd@freeze.steamwinter.com:webdownloads/";
        upload("ddox", uploadPath, true);
    }

    if (uploadHelpersToSite)
    {
        auto uploadPath = "jcd@freeze.steamwinter.com:webdownloads/ddox/";
        upload("ddox/scripts", uploadPath, true);
        upload("ddox/styles", uploadPath, true);
        upload("ddox/images", uploadPath, true);
        upload("ddox/prettify", uploadPath, true);
        upload("ddox/page", uploadPath, true);
    }
}

void generateResourcePack(string[] args, bool showUsage = false)
{
	if (showUsage)
	{
		writeln("tool generate-resource-list <source dir> <target file>");
		writeln("Generate a file listing all resource files");
		return;
	}

	if (args.length < 3)
	{
		writeln("Missing source dir argument");
		return;
	}

	if (args.length < 4)
	{
		writeln("Missing target file argument");
		return;
	}

	string sourceDir = args[2];

	string targetFilePath = args[3];
    if (exists(targetFilePath))
        remove(targetFilePath);

    auto r = dirEntries(sourceDir, SpanMode.depth);
    struct FileInfo
    {
        string path;
        ulong size;
    }

    FileInfo[] infos;

    foreach (name; r)
	{
        if (name.isDir)
            continue;
        auto sz = name.getSize();
		infos ~= FileInfo(name, sz);
    }

	auto f = File(targetFilePath, "w");
    f.write("# This file is auto generated as a prebuild step for release builds\n");
    f.write("files: ", infos.length, "\n");

    foreach (i; infos)
        f.write("\"", i.path, "\"", " ", i.size, "\n");

    foreach (i; infos)
    {
        ubyte[] bytes = cast(ubyte[]) read(i.path);
        f.rawWrite(bytes);
    }
}
