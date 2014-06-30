module gui.style.parser;

import core.uri;

import gui.resource;
import gui.resources.material : Material, MaterialManager;
import gui.resources.font : Font, FontManager;

import gui.style.manager;
import gui.style.style;
import gui.style.stylesheet;
import gui.style.types;

import math._;

import std.conv;
import std.path;
import std.range;

class CustomMaterialLoader : IResourceLoader!Material
{
	static CustomMaterialLoader _the;
	static @property singleton()
	{
		if (_the is null)
		{
			_the = new CustomMaterialLoader;
		}
		return _the;
	}

	bool load(Material r, URI uri)
	{
		// TODO: Remove since tex and shader are lazy loaded as well
		//gui.resources.Texture tex = cast(gui.resources.Texture) r.texture;
		//if (tex !is null)
		//    tex.ensureLoaded();
		//
		//gui.resources.ShaderProgram sp = cast(gui.resources.ShaderProgram) r.shader;
		//if (sp !is null)
		//    sp.ensureLoaded();

		// There is no. Just make a callback to the manager that all is ok
		r.manager.onResourceLoaded(r, null);
		return true;
	}

	bool save(Material p, URI uri)
	{
		throw new Exception("Cannot save materials");
	}

}

class CustomFontLoader : IResourceLoader!Font
{
	static CustomFontLoader _the;
	static @property singleton()
	{
		if (_the is null)
		{
			_the = new CustomFontLoader;
		}
		return _the;
	}

	bool load(Font r, URI uri)
	{
		r.init();
		r.manager.onResourceLoaded(r, null);
		return true;
	}

	bool save(Font p, URI uri)
	{
		throw new Exception("Cannot save fonts");
	}
}

class StyleSheetParser
{
	import std.string;

	struct Error
	{
		int line;
		int column;
		string message;
	}

	alias Error[] Errors;
	Errors errors;

	string singleCharToks = "{}():;#@\"'>%*";

	enum TokenType : ubyte
	{
		curlOpen,
		curlClose,
		parenOpen,
		parenClose,
		colon,
		semicolon,
		hash,
		at,
		doubleQuote,
		quote,
		greaterThan,
		pct,
		star,
		identifier,
		number,
		dot,
		whitespace,
		eof,
		invalid
	}

	struct Token
	{
		TokenType type;
		string value;

		bool oneOf(Args...)(Args args)
		{
			foreach (a; args)
				if (a == type)
					return true;
			return false;
		}

		T to(T)()
		{
			return value.to!T;
		}

		@property bool eof() { return type == TokenType.eof; }
		@property bool invalid() { return type == TokenType.invalid; }
		@property bool whitespace() { return type == TokenType.whitespace; }
	}

	int line = 1;
	string spaceChars = " \t\n\r";
	string nonSpaceChars = "^ \t\n\r";
	string tokenChars = "^ \t\n\r{}):;#\"'";
	string numberTokenChars = "[0-9.]";
	string txt;
	Token curToken;
	StyleSheet sheet;
	URI baseURI;
	FontManager fontManager;
	MaterialManager materialManager;

	@property bool hasErrors() const
	{
		return !errors.empty;
	}

	void addError(string msg, int line = -1, int col = -1)
	{
		errors ~= Error(line, col, msg);
	}

	this(string txt, StyleSheet sheet, URI baseURI, FontManager fontManager, MaterialManager materialManager)
	{
		this.txt = txt;
		this.sheet = sheet;
		this.baseURI = baseURI;
		this.fontManager = fontManager;
		this.materialManager = materialManager;
	}

	// A bit of a hack to get nice looking unquoted strings in stylesheets
	string nextNonWhitespaceString()
	{
		return munch(txt, nonSpaceChars);		
	}

	Token nextToken(bool skipWhiteSpace = true)
	{
		import std.algorithm;
		auto space = munch(txt, spaceChars);
		line += space.count('\n');

		if (!skipWhiteSpace && !space.empty)
		{
			curToken.type = TokenType.whitespace;
			curToken.value = space;
			return curToken;
		}

		//if (!txt.empty && (txt[0] == '}' || txt[0] == '{' || txt[0] == ';' || txt[0] == ':' || txt[0] == '#' || txt[0] == '\'' || txt[0] == '"' || txt[0] == ')'))
		if (txt.empty)
		{
			curToken.type = TokenType.eof;
			curToken.value = null;
			return curToken;
		}

		import std.string;
		auto idx = std.string.indexOf(singleCharToks, txt[0]);

		if (idx != -1)
		{
			// One char tokens
			curToken.type = cast(TokenType)idx;
			curToken.value = txt[0..1];
			txt = txt[1..$];
		}
		else
		{
			import std.regex;

			// identifier
			auto re = regex("^[a-zA-Z]+[-a-zA-Z_]*");
			auto m = txt.matchFirst(re);
			if (!m.empty)
			{
				curToken.type = TokenType.identifier;
				curToken.value = m.captures[0];
				txt = txt[curToken.value.length..$];
			}
			else
			{
				// number
				auto re2 = regex(r"^(?:-?\.[0-9]+)|^(?:-?[0-9]+\.?[0-9]*)");
				auto m2 = txt.matchFirst(re2);
				if (!m2.empty)
				{
					curToken.type = TokenType.number;
					curToken.value = m2.captures[0];
					txt = txt[curToken.value.length..$];
				}
				else if (txt[0] == '.')
				{
					curToken.type = TokenType.dot;
					curToken.value = ".";
					txt = txt[1..$];
				}
				else
				{
					addError("Invalid style token following '" ~ curToken.value ~ "'", line);
					curToken.value = txt;
					curToken.type = TokenType.invalid;
					throw new Exception("Invalid stylesheet syntax");
				}
			}
		}
		return curToken;
	}

	Token requireNextToken(TokenType requiredType = TokenType.invalid, bool skipWhiteSpace = true)
	{
		auto lastToken = curToken;
		nextToken(skipWhiteSpace);
		if (curToken.type == TokenType.eof)
		{
			addError("Incomplete style rule following " ~ lastToken.value ~ "'", line);
			throw new Exception("Premature end of stylesheet file");
		}
		assertToken(requiredType);
		return curToken;
	}

	float extractOptionalNumber(Token t)
	{
		return t.type == TokenType.dot ? float.nan : t.to!float();
	}

	float requireNextOptionalNumber()
	{
		return extractOptionalNumber(requireNextToken());
	}

	void assertToken(TokenType requiredType)
	{
		if (requiredType != TokenType.invalid && curToken.type != requiredType)
		{
			addError("Unexpected token at this point in file '" ~ curToken.value ~ "'", line);
			throw new Exception("Unexpected token in stylesheet");
		}
	}

	/*
	string nextOptionalQuotedString()
	{		
	munch(txt, spaceChars);
	if (txt.empty)
	{
	addError("EOF reached while parsing optional quoted string", line);
	throw new Exception("Premature EOF");
	}

	if ("\"'".canFind(txt[0]))
	{
	auto startQuoteChar = txt[0];
	auto res = munch(txt[1..$], "^" ~ startQuoteChar); // TODO: support quoted " and '
	if (txt.empty)
	{
	addError("EOF reached while parsing end of optional quoted string", line);
	throw new Exception("Premature EOF");
	}
	txt = txt[1..$];
	}
	else
	{
	return nextNonWhitespaceString();
	}
	}
	*/
	void skipToEndOfProperty()
	{
		while (curToken.type != TokenType.semicolon && curToken.type != TokenType.curlClose)
			requireNextToken();
	}

	private void setFontFromUrl(Style style, string uriStr)
	{
		auto theURI = new URI(uriStr);
		if (!theURI.isAbsolute)
			theURI.makeAbsolute(baseURI);

		switch (uriStr.extension)
		{
			case ".font":
				if (fontManager !is null)
				{
					// Let material manager handle this for us
					style.font = fontManager.declare(theURI);
				}
				break;
			case ".ttf":
				// Create a custom font and use a dummy loader for that
				if (style._fields._font is null)
					style.font = fontManager.declare(CustomFontLoader.singleton);

				style._fields._font.path = theURI.toString(); // TODO: make into URI instead?
				break;
			default:
				addError("Unsupported font type " ~ uriStr);
				throw new Exception("Unsupported font type");
		}
	}

	void parseFontProperty(Style style)
	{		
		while (requireNextToken().type == TokenType.identifier || 
			   curToken.type == TokenType.number)
		{
			switch (curToken.type)
			{
				case TokenType.identifier:
					if (curToken.value != "url")
					{
						addError("Cannot parse font size", line);
						skipToEndOfProperty();
						return;
					}

					requireNextToken(TokenType.parenOpen);
					auto theStr = munch(txt,"^)");
					requireNextToken(TokenType.parenClose);
					setFontFromUrl(style, theStr);			
					if (theStr.extension == ".font")
					{
						skipToEndOfProperty();
						return; // skip everything else because the font file has it all
					}
					break;

				case TokenType.number:
					import std.format;
					int v;
					if (formattedRead(curToken.value, "%s", &v) == 0)
					{
						addError("Cannot parse font size", line);

						// skip to end of propery declaration
						skipToEndOfProperty();
						return;
					}

					// Create a custom font and use a dummy loader for that
					if (style._fields._font is null)
						style.font = fontManager.declare(CustomFontLoader.singleton);

					style._fields._font.size = v;
					break;
				default:
					assert(0); // cannot happen
					break;
			}
		}
	}

	void parseBackgroundProperty(Style style)
	{
		if (materialManager is null)
		{
			skipToEndOfProperty();
			return;
		}

		while (requireNextToken().type == TokenType.identifier)
		{
			if (curToken.value != "url")
			{
				addError("Cannot parse background property url not enclosed in url(...)", line);
				skipToEndOfProperty();
				return;
			}

			requireNextToken(TokenType.parenOpen);
			auto theStr = munch(txt,"^)");
			requireNextToken(TokenType.parenClose);

			auto theURI = new URI(theStr);
			if (!theURI.isAbsolute)
				theURI.makeAbsolute(baseURI);

			switch (theURI.extension)
			{
				case ".material":
					// Let material manager handle this for us
					if (style._fields._background !is null)
						addError("overriding existing material", line);
					style.background = materialManager.declare(theURI);
					skipToEndOfProperty();
					return;

				case ".png":	
					// Create a custom material and use a dummy loader for that
					if (style._fields._background is null)
						style.background = materialManager.declare(CustomMaterialLoader.singleton);			
					else if (style._fields._background.hasTexture())
						addError("overriding existing texture on material", line);
					style._fields._background.texture = materialManager.textureManager.declare(theURI);
					break;
				case ".shaderprogram":				
					// Create a custom material and use a dummy loader for that
					if (style._fields._background is null)
						style.background = materialManager.declare(CustomMaterialLoader.singleton);			
					else if (style._fields._background.hasShader())
						addError("overriding existing shader on material", line);

					style._fields._background.shader = materialManager.shaderProgramManager.declare(theURI);
					break;
				default:
					addError("Unsupported file extension for background style " ~ theURI.extension, line);
					break;
			}
		}
	}

	void parseColor(ref Color color)
	{
		requireNextToken();
		string colStr;
		switch (curToken.type)
		{
			case TokenType.identifier:
				auto theStr = munch(txt,"^)");
				colStr = curToken.value ~ theStr ~ ')';
				requireNextToken(TokenType.parenClose);
				break;
			case TokenType.hash:
				colStr = "#" ~ munch(txt, "^;}" ~ spaceChars);
				break;
			default:
				addError("Invalid color value", line);
				return;
		}

		auto col = Color.fromCSSString(colStr);
		if (col[1])
		{
			color = col[0];
		}
		else
		{
			addError("Invalid color string format", line);
		}
	}

	void parseWordWrapProperty(Style style)
	{
		requireNextToken(TokenType.identifier);
		style.wordWrap = curToken.value == "true";
		requireNextToken();
	}

	void parseRect(ref Rectf r)
	{
		r.x = requireNextOptionalNumber();
		r.y = requireNextOptionalNumber();
		r.w = requireNextOptionalNumber();
		r.h = requireNextOptionalNumber();
	}

	void parseRectOffset(ref RectfOffset r)
	{
		r.top = requireNextOptionalNumber();
		r.left = requireNextOptionalNumber();
		r.right = requireNextOptionalNumber();
		r.bottom = requireNextOptionalNumber();
	}

	void parsePositionProperty(Style style)
	{
		requireNextToken(TokenType.identifier);
		switch (curToken.value)
		{
			case "static":
				style.position = Style.Position.static_;
				break;	
			case "fixed":
				style.position = Style.Position.fixed;
				break;	
			case "relative":
				style.position = Style.Position.relative;
				break;	
			case "absolute":
				style.position = Style.Position.absolute;
				break;	
			default:
				style.position = Style.Position.invalid;
				addError(text("Unknown position value '", curToken, "'"), line);
				break;
		}
		skipToEndOfProperty();
	}

	// Parse into val and eat unit specifier as well
	void parseScale(ref CSSScale val)
	{
		assertToken(TokenType.number);
		val.value = curToken.value.to!float();

		bool consumed = false;
		CSSUnit sz = CSSUnit.pixels;

		bool skipWhitespace = false;

		switch (requireNextToken(TokenType.invalid, skipWhitespace).type)
		{
			case TokenType.pct:
				sz = CSSUnit.pct;
				break;
			case TokenType.identifier:
				switch (curToken.value)
				{
					case "in":
						consumed = true;
						sz = CSSUnit.inch;
						break;
					case "cm":
						consumed = true;
						sz = CSSUnit.cm;
						break;
					case "mm":
						consumed = true;
						sz = CSSUnit.mm;
						break;
					case "em":
						consumed = true;
						sz = CSSUnit.em;
						break;
					case "ex":
						consumed = true;
						sz = CSSUnit.ex;
						break;
					case "pc":
						consumed = true;
						sz = CSSUnit.picas;
						break;
					case "pt":
						consumed = true;
						sz = CSSUnit.points;
						break;
					case "px":
						consumed = true;
						sz = CSSUnit.pixels;
						goto default;
					default:
						addError("Unknown unit " ~ curToken.value, line);
						break;
				}
				break;
			case TokenType.whitespace:
				break;
			default:
				addError("Malformed length/pct unit", line);
		}
		val.unit = sz;
	}

	void parseProperties(Style style)
	{
		requireNextToken();

		while (true)
		{
			while (curToken.type == TokenType.semicolon)
				requireNextToken();

			if (curToken.type == TokenType.curlClose)
				return;

			assertToken(TokenType.identifier);

			string key = curToken.value;
			nextToken();

			if (curToken.type != TokenType.colon)
			{
				addError("Expected ':' after style key '" ~ key ~ "'", line);

				// Skip to end of property declaration
				while (curToken.type != TokenType.semicolon && curToken.type != TokenType.curlClose)
					requireNextToken();
				continue;
			}

			// TODO:
			// Do not throw in parser if possible. Just log.
			// Support for multiply stylesheets and cascading them maybe (e.g. for lang syntax specific sheets)
			switch (key)
			{
				case "font":
					parseFontProperty(style);
					break;
				case "background":
					parseBackgroundProperty(style);
					break;
				case "color":
					parseColor(style._fields._color);
					style._fields._nullFields |= 2;
					requireNextToken();
					break;
				case "background-color":
					parseColor(style._fields._backgroundColor);
					style._fields._nullFields |= 4;
					requireNextToken();
					break;
				case "wordWrap":
					parseWordWrapProperty(style);
					break;
				case "padding":
					parseRectOffset(style._fields._padding);
					requireNextToken();
					break;
				case "background-sprite":
					parseRect(style._fields._backgroundSprite);
					requireNextToken();
					break;
				case "background-sprite-border":
					parseRectOffset(style._fields._backgroundSpriteBorder);
					requireNextToken();
					break;
				case "position":
					parsePositionProperty(style);
					break;
				case "left":
					requireNextToken();
					parseScale(style._fields._edgesOffset.left);
					requireNextToken();
					continue;
				case "top":
					requireNextToken();
					parseScale(style._fields._edgesOffset.top);
					requireNextToken();
					continue;
				case "right":
					requireNextToken();
					parseScale(style._fields._edgesOffset.right);
					requireNextToken();
					continue;
				case "bottom":
					requireNextToken();
					parseScale(style._fields._edgesOffset.bottom);
					requireNextToken();
					continue;
				default:
					auto mgr = sheet.manager;
					auto spec = (cast(StyleSheetManager)mgr).lookupPropertySpecification(key);
					if (spec !is null)
					{
						if (spec.parse(this, style))
							continue;
						requireNextToken();
					}
					else
					{
						addError("Unknown style key '" ~ key ~ "'", line);
						skipToEndOfProperty();
						continue;
					}
			}
		}
	}

	void parseSelector(Rule rule)
	{
		while (true)
		{
			string widgetTypeName = null;
			string widgetName = null;
			string className = null;
			string pseudoClassName = null;

			const bool skipWhitespace = false;
			bool segmentDone = false;

			// A segment can be either #id or .class or widgetname or a combination
			do 
			{
				switch (curToken.type)
				{
					case TokenType.hash:
						requireNextToken(TokenType.identifier, skipWhitespace);
						widgetName = curToken.value;
						requireNextToken();
						break;
					case TokenType.dot:
						requireNextToken(TokenType.identifier, skipWhitespace);
						className = curToken.value;
						requireNextToken();
						break;
					case TokenType.colon:
						requireNextToken(TokenType.identifier, skipWhitespace);
						pseudoClassName = curToken.value;
						requireNextToken();
						break;
					case TokenType.identifier:
						if (curToken.value != "*")
							widgetTypeName = curToken.value;
						requireNextToken();
						break;
					case TokenType.curlOpen, TokenType.greaterThan:
						segmentDone = true;
						break;
					case TokenType.whitespace:
						segmentDone = true;
						break;
					case TokenType.star:
						segmentDone = true;
						requireNextToken();
						break;
					default:
						addError("Unexpected property declaration start token", line);
						throw new Exception("Invalid property declaration start token");
				}
			}
			while (!segmentDone);

			//if (widgetTypeName is null && widgetName is null && className is null && pseudoClassName is null)
			//{
			//    addError("Missing selector for rule", line);
			//    throw new Exception("Invalid selector in stylesheet");
			//}

			if (curToken.whitespace)
				requireNextToken(); // get the { or > token

			switch (curToken.type)
			{
				case TokenType.curlOpen:
					rule.widgetSelectors ~= new WidgetSelector(widgetTypeName, widgetName, className, pseudoClassName);
					return;
				case TokenType.greaterThan:
					rule.widgetSelectors ~= new ChildSelector(widgetTypeName, widgetName, className, pseudoClassName);
					requireNextToken();
					break;
				default:
					rule.widgetSelectors ~= new DescendantSelector(widgetTypeName, widgetName, className, pseudoClassName);
					break;
			}
		}
	}

	void parseKeyFrame(Animation anim)
	{
		assertToken(TokenType.number);

		CSSScale scale; 
		parseScale(scale);
		if (scale.unit != CSSUnit.pct)
		{
			addError("Keyframe offset must be in percentages");
			throw new Exception("Keyframe offset error");
		}
		if (scale.value < 0)
		{
			addError("Keyframe offset cannot be negative");
			throw new Exception("Negative keyframe offset");
		}

		requireNextToken(TokenType.curlOpen);

		auto style = new Style(sheet);
		parseProperties(style);
		anim.addKeyFrame(scale.value, style);
	}

	void parseCssRule()
	{
		requireNextToken(TokenType.identifier);
		if (curToken.value == "keyframes")
		{
			string animationName = requireNextToken(TokenType.identifier).value;
			requireNextToken(TokenType.curlOpen);

			auto anim = new Animation(sheet);

			while (requireNextToken().type != TokenType.curlClose)
				parseKeyFrame(anim);
		}
		else // skip unknown rule
		{
			while (requireNextToken().type != TokenType.curlOpen)
			{ 
				// no op
			}

			int bracketIndent = 1;

			while (bracketIndent)
			{
				requireNextToken();
				if (curToken.type == TokenType.curlOpen)
					bracketIndent++;
				else if (curToken.type == TokenType.curlClose)
					bracketIndent--;
			}
		}
		nextToken();
	}

	void parseRule()
	{

		Rule rule = new Rule;
		rule.style = new Style(sheet);
		parseSelector(rule);
		parseProperties(rule.style);
		nextToken();
		sheet.rules ~= rule;
	}

	bool parse()
	{
		try 
		{
			nextToken();
			while(!curToken.eof)
			{
				if (curToken.type == TokenType.at)
					parseCssRule();
				else
					parseRule();
			}
		}
		catch (Exception e)
		{
			addError(e.msg);
		}
		return !hasErrors;
	}
}

unittest
{
	StyleSheet sheet = new StyleSheet();

	auto parse = new StyleSheetParser("", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.empty, "No rules for empty sheet");

	parse = new StyleSheetParser("Widget {}", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 1 && 
		   sheet.rules[0].widgetSelectors.length == 1 &&
		   sheet.rules[0].widgetSelectors[0].widgetTypeName == "Widget", 
		   "Simple selector and no style definitions");

	parse = new StyleSheetParser("Widget { color: #FF0000 }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 2 && 
		   sheet.rules[1].widgetSelectors.length == 1 &&
		   sheet.rules[1].widgetSelectors[0].widgetTypeName == "Widget" &&
		   sheet.rules[1].style.color == Color.red, 
		   "Simple selector and red color");

	parse = new StyleSheetParser("Widget { color: #FF0000; }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 3 && 
		   sheet.rules[2].widgetSelectors.length == 1 &&
		   sheet.rules[2].widgetSelectors[0].widgetTypeName == "Widget" &&
		   sheet.rules[2].style.color == Color.red, 
		   "Simple selector and red color semicolor end");

	parse = new StyleSheetParser("Widget { color: #FF0000;\n padding : 1 2 3 4;\n wordWrap: true;\n }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 4 && 
		   sheet.rules[3].widgetSelectors.length == 1 &&
		   sheet.rules[3].widgetSelectors[0].widgetTypeName == "Widget" &&
		   sheet.rules[3].style.color == Color.red &&
		   sheet.rules[3].style.wordWrap &&
		   sheet.rules[3].style.padding == RectfOffset(1,2,3,4),
		   "Simple selector and red color and rect and wordWrap	");
}
