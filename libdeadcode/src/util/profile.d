module util.profile;

public import tharsis.prof;

private ubyte[] storage;
Profiler profiler;

void initProfiler()
{
    // Get 2 MB more than the minimum (maxEventBytes). Could also use malloc() here.
    storage = new ubyte[Profiler.maxEventBytes + 1024 * 1024 * 2];
    // Could use std.typecons.scoped! to avoid GC here.
    profiler = new Profiler(storage);
}
