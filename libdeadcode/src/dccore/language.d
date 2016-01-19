module dccore.language;

import dccore.bufferview;

import std.algorithm;
import std.array;

import std.functional; // : unaryFun, binaryFun;
import std.range;

auto findByValue(alias pred, R)(R haystack)
//if (is(typeof(find!pred(haystack))))
//if (isInputRange!R)// &&
    //is (typeof(unaryFun!pred(haystack.front)) : bool))
{
    foreach (k, v; haystack)
        if (pred(v))
            return v;
    return null;
}

class CodeIntelManager
{
	private
	{
		ICodeIntel[string] _codeIntels;
	}

	void register(string name, ICodeIntel i)
	{
		_codeIntels[name] = i;
	}

	ICodeIntel lookup(string languageName)
	{
		return _codeIntels.get(languageName, null);
	}

    ICodeIntel detect(BufferView bv)
    {
        return findByValue!(a => a.detect(bv))(_codeIntels);
    }

    ICodeIntel lookupByFileExtension(string ext)
    {
        return _codeIntels.findByValue!(a => a.IsSupportingFileExtension(ext));
        /*
        foreach (k, i; _codeIntels)
        {
            if (i.IsSupportingFileExtension(ext))
	            return i;
        }
        return null;
        */
    }
}

static private CodeIntelManager _manager;

CodeIntelManager manager()
{
	if (_manager is null)
		_manager = new CodeIntelManager;
	return _manager;
}

interface ICodeIntel
{
    @property string languageName() const pure @safe nothrow;
	bool detect(BufferView v);
	ICodeModel createModel(BufferView v);
    bool IsSupportingFileExtension(string ext);
}

interface ICodeModel
{
	@property ICodeIntel codeIntel();
	@property string name() const pure nothrow @safe;
	void updateAST();
	string getSuggestedPath();
}
