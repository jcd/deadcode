module core.language;

import core.bufferview;

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
	ICodeModel createModel(BufferView v);
}

interface ICodeModel
{
	@property ICodeIntel codeIntel();
	
	void updateAST();
	string getSuggestedPath();
}
