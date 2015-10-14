module core.pack;

struct FilePack(string path)
{
    version (all)
    {
        enum bytes = cast(ubyte[]) import(path);

        string unpack()
        {
            import std.stdio;

            string depacked = null;
            try
            {
                import std.algorithm;
                import std.path;
                import std.file;
                import std.format;
                import std.range;
                import std.regex;
                import std.conv;

                depacked = buildPath(tempDir(), path);
                version (linux)
                    writeln("Unpacking ", path ," to dir ", depacked);

                uint offset;

                // Read the index of the pack and write files to dir
                auto r = (cast(string)bytes).splitter("\n");
                offset += r.front.length + 1;
                r.popFront(); // skip comment
                int lineCount = r.front.matchFirst(`files:\s(\d+)`)[1].to!int;
                // writeln("Reading ", lineCount, " files");
                offset += r.front.length + 1;
                r.popFront();

                struct FileInfo
                {
                    string path;
                    uint size;
                }
                FileInfo []infos;
                foreach (inf; r.takeExactly(lineCount))
                {
                    offset += inf.length + 1;
                    auto m = inf.matchFirst(`"(.*)"\s(\d+)`);
                    infos ~= FileInfo(m[1], m[2].to!uint);
                }
                r.popFrontExactly(lineCount);

                if (exists(depacked))
                    rmdirRecurse(depacked);

                // Extract files ranges and save to dir
                foreach (inf; infos)
                {
                    ubyte[] fileData = bytes[offset..offset+inf.size];
                    offset += inf.size;
                    // Make sure the dir exists
                    string targetPath = buildPath(depacked, inf.path);
                    mkdirRecurse(dirName(targetPath));
                    std.file.write(targetPath, fileData);                // Writing the dynlib to a temporary file.
                    //writeln("Wrote ",inf, " ", targetPath, " size ", inf.size);
                }
            }
            catch(Exception e)
            {
                version (linux)
                    writeln("Error loading ", path, " pack ", e);
                return null;
            }
            return depacked;
        }
    }
    else
    {
        string unpack()
        {
            return "";
        }
    }
}
