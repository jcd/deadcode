module extensions.language.d;

import extensionapi;

import dccore.language;

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

	@property string name() const pure nothrow @safe
    {
        return "D";
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

    @property string languageName() const pure @safe nothrow
    {
        return "D";
    }

    bool detect(BufferView bv)
    {
        import std.path;
        return extension(bv.name) == ".d" || !bv.find("^module ").empty;
    }

	ICodeModel createModel(BufferView v)
	{
		auto m = new DCodeModel(v, this);
		updateAST(m);
		return m;
	}

    bool IsSupportingFileExtension(string ext)
    {
		import std.algorithm;
        import std.string;
		enum exts = [ "d", "di" ];
	    return exts.canFind(ext.chompPrefix("."));
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
			//writefln("DCodeModel %s(%s,%s): %s", fileName, line, column, message);
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

import controls.texteditor : TextEditorDataAnchorManager, TextEditorDataAnchorWidget;
import extensions.language.d.analysis.base;

class AnalysisAnchorWidget : TextEditorDataAnchorWidget!Message
{
	import gui.label;
	Label label;

	override void update()
	{
		super.update();
		if (label is null)
		{
			auto m = anchorData;
			if ( m.message.length)
			{
				label = new Label(m.message);
				label.parent = this;
			}
		}
	}
}

static TextEditorDataAnchorManager!AnalysisAnchorWidget anchorManager;
static this()
{
    anchorManager = new typeof(anchorManager);
}
