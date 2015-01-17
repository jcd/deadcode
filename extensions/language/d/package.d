module extensions.language.d;

import extensions.attr;

import core.language; 

import std.d.lexer;
import std.d.parser;
import std.d.ast;

static this()
{
	manager().register("D", new DCodeIntel());

	if (true)
		manager();
	else
		manager();
}

class DCodeModel : ICodeModel
{
	private
	{
		BufferView _bufferView;
		DCodeIntel _codeIntel;
		const(Token)[] _tokens;
		Module _mod;	
	}

	@property const(Token)[] tokens() const pure nothrow @safe
	{
		return _tokens;
	}

	@property ICodeIntel codeIntel()
	{
		return _codeIntel;
	}

	private this(BufferView v, DCodeIntel i)
	{
		_bufferView = v;
		_codeIntel = i;
	}

	void updateAST()
	{
		_codeIntel.updateAST(this);
	}

	void accept(ASTVisitor v)
	{
		v.visit(_mod);
	}

	string getSuggestedPath()
	{
		import std.array;
		import std.path;
		auto v = _codeIntel.updateFastInfo(this);
		string res = v.moduleName.replace(".", dirSeparator);
		if (res.length)
			res ~= ".d";
		return res;
	}
}

class FastDVisitor : ASTVisitor
{
	string moduleName;
	override void visit(const ModuleDeclaration moduleDeclaration)
	{
		moduleName = null;
		string delim;
		foreach (t; moduleDeclaration.moduleName.identifiers[])
		{
			moduleName ~= delim;
			moduleName ~= t.text;
			delim = ".";
		}
	}

	alias visit = ASTVisitor.visit;
}

class DCodeIntel : ICodeIntel
{
	private
	{
		StringCache _cache;
		FastDVisitor _fastVisitor;
	}

	this()
	{
		_cache = StringCache(StringCache.defaultBucketCount);
		_fastVisitor = new FastDVisitor;
	}

	ICodeModel createModel(BufferView v)
	{
		auto m = new DCodeModel(v, this);
		updateAST(m);
		return m;
	}

	void updateAST(DCodeModel m)
	{
		import std.conv;
		LexerConfig config;
		config.fileName = m._bufferView.name;
		config.stringBehavior = StringBehavior.source;

		static void logMessage(string fileName, size_t line, size_t column, string message, bool isError)
		{
			import std.stdio;
			writefln("DCodeModel %s(%s,%s): %s", fileName, line, column, message);
		}
		string data = m._bufferView.getText().to!string;
		m._tokens = getTokensForParser(cast(ubyte[])data, config, &_cache);
		m._mod = parseModule(m._tokens, m._bufferView.name, null, &logMessage);
	}

	// TODO: it sucks with threading and returning the visitor
	FastDVisitor updateFastInfo(DCodeModel m)
	{
		if (m._mod is null)
			updateAST(m);
		if (m._mod !is null)
			_fastVisitor.visit(m._mod);
		return _fastVisitor;
	}
}

