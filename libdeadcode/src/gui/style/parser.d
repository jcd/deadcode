module gui.style.parser;

import core.uri;

import gui.resource;
import gui.resources.material : Material, MaterialManager;
import gui.resources.font : Font, FontManager;
import graphics.color : Color;

import gui.style.manager;
import gui.style.style;
import gui.style.stylesheet;
import gui.style.types;

import math;

import std.conv;
import std.path;
import std.range;

import test;
// mixin registerUnittests;

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

	string singleCharToks = "{}():;#@\"'>%*,";

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
		comma,
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
		string textRange; // spanding from start of token (include prefix space) to end of stylesheet text
		string value; // token text

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

		bool asNumber(ref float result) const pure @trusted
		{
			string s = value;
			return
				numberLike &&
				std.format.formattedRead(s, "%s", &result) == 1;
		}

		@property bool eof() const pure nothrow @safe { return type == TokenType.eof; }
		@property bool invalid() const pure nothrow @safe { return type == TokenType.invalid; }
		@property bool whitespace() const pure nothrow @safe { return type == TokenType.whitespace; }
		@property bool numberLike() const pure nothrow @safe { return type == TokenType.number || type == TokenType.dot; }
	}

	int line = 1;
	string spaceChars = " \t\n\r";
	string nonSpaceChars = "^ \t\n\r";
	string tokenChars = "^ \t\n\r{}):;#\"'";
	string numberTokenChars = "[0-9.]";
	string txt;

	Token curToken;
	Token bufferToken;

	StyleSheet sheet;
	URI baseURI;
	FontManager fontManager;
	MaterialManager materialManager;

	@property bool hasErrors() const
	{
		return !errors.empty;
	}

	void addError(string msg, int line = -1, int col = -1) pure nothrow @safe
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
		curToken.type = TokenType.invalid;
		bufferToken.type = TokenType.invalid;
	}

	// A bit of a hack to get nice looking unquoted strings in stylesheets
	//string nextNonWhitespaceString()
	//{
	//    return munch(txt, nonSpaceChars);
	//}

	Token peekToken() @safe
	{
		if (bufferToken.type == TokenType.invalid)
			bufferToken = nextToken();
		return bufferToken;
	}

	// Reset to before tok was parsed. After this curToken is invalid and nextToken should
	// be called before using that again.
	void resetToToken(Token tok) pure nothrow @safe
	{
		txt = tok.textRange;
		curToken.value = null;
		curToken.textRange = null;
		curToken.type = TokenType.invalid;
	}

	void pushBackToken()
	{
		bufferToken = curToken;
	}

	Token nextToken() @safe
	{
		if (nextTokenKeepSpace().type == TokenType.whitespace)
			return nextTokenKeepSpace();
		return curToken;
	}

	Token nextTokenKeepSpace() @trusted
	{
		if (bufferToken.type != TokenType.invalid)
		{
			curToken = bufferToken;
			bufferToken.type = TokenType.invalid;
			return curToken;
		}

		import std.algorithm;
		curToken.textRange = txt[0..$];

		auto space = munch(txt, spaceChars);
		line += space.count('\n');

		if (!space.empty)
		{
			curToken.type = TokenType.whitespace;
			curToken.value = space;
			return curToken;
		}

		//if (!txt.empty && (txt[0] == '}' || txt[0] == '{' || txt[0] == ';' || txt[0] == ':' || txt[0] == '#' || txt[0] == '\'' || txt[0] == '"' || txt[0] == ')'))
		if (txt.empty)
		{
			curToken.type = TokenType.eof;
			curToken.textRange = null;
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

	Token requireNextToken(TokenType requiredType = TokenType.invalid) @safe
	{
		auto lastToken = curToken;
		nextToken();
		if (curToken.type == TokenType.eof)
		{
			addError("Incomplete style rule following " ~ lastToken.value ~ "'", line);
			throw new Exception("Premature end of stylesheet file");
		}
		assertToken(requiredType);
		return curToken;
	}

	Token requireNextTokenKeepSpace(TokenType requiredType = TokenType.invalid) @safe
	{
		auto lastToken = curToken;
		nextTokenKeepSpace();
		if (curToken.type == TokenType.eof)
		{
			addError("Incomplete style rule following " ~ lastToken.value ~ "'", line);
			throw new Exception("Premature end of stylesheet file");
		}
		assertToken(requiredType);
		return curToken;
	}

	float extractOptionalNumber(Token t) const pure @safe
	{
		return t.type == TokenType.dot ? float.nan : t.to!float();
	}

	float requireNextOptionalNumber() @safe
	{
		return extractOptionalNumber(requireNextToken());
	}

	void assertToken(TokenType requiredType) pure @safe
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
				if (style._font is null)
					style.font = fontManager.declare(CustomFontLoader.singleton);

				style._font.path = theURI.toString(); // TODO: make into URI instead?
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
					if (style._font is null)
						style.font = fontManager.declare(CustomFontLoader.singleton);

					style._font.size = v;
					break;
				default:
					assert(0); // cannot happen
					// break;
			}
		}
		pushBackToken();
	}

    void parseAnimationProperty(ref SpriteFrames animFrames)
    {
		while (requireNextToken().type == TokenType.identifier)
		{
			switch (curToken.type)
			{
				case TokenType.identifier:

                    // e.g. offset(16,20,8,2,0.3) meaning offset each frame width 16, height 18.
                    //      The animsheet having 8 columns and 2 rows. Each from should last 0.3 seconds.
                    if (curToken.value != "grid")
					{
						addError("Cannot parse animation type", line);
						skipToEndOfProperty();
						return;
					}

                    if (animFrames is null)
                        animFrames = new SpriteFrames();

                    animFrames.type = SpriteFramesType.grid;

					requireNextToken(TokenType.parenOpen);
					animFrames.columns = requireNextToken(TokenType.number).to!int;
                    requireNextToken(TokenType.comma);
					animFrames.rows = requireNextToken(TokenType.number).to!int;
                    requireNextToken(TokenType.comma);
					animFrames.count = requireNextToken(TokenType.number).to!int;
                    requireNextToken(TokenType.comma);
					animFrames.frameTime = requireNextToken(TokenType.number).to!float;
					requireNextToken(TokenType.parenClose);
                    skipToEndOfProperty();
				    return; // skip everything else for the property
				default:
					assert(0); // cannot happen
					// break;
			}
		}
		pushBackToken();
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
					if (style._background !is null)
						addError("overriding existing material", line);
					style.background = materialManager.declare(theURI);
					skipToEndOfProperty();
					return;

				case ".png":
					// Create a custom material and use a dummy loader for that
					if (style._background is null)
						style.background = materialManager.declare(CustomMaterialLoader.singleton);
					else if (style._background.hasTexture())
						addError("overriding existing texture on material", line);
					style._background.texture = materialManager.textureManager.declare(theURI);
					break;
				case ".shaderprogram":
					// Create a custom material and use a dummy loader for that
					if (style._background is null)
						style.background = materialManager.declare(CustomMaterialLoader.singleton);
					else if (style._background.hasShader())
						addError("overriding existing shader on material", line);

					style._background.shader = materialManager.shaderProgramManager.declare(theURI);
					break;
				default:
					addError("Unsupported file extension for background style " ~ theURI.extension, line);
					break;
			}
		}
		pushBackToken();
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
	}

	void parseVisibilityProperty(Style style)
	{
		requireNextToken(TokenType.identifier);

        // TODO: support "inherit"
        switch (curToken.value)
        {
            case "visible":
                style.visibility = CSSVisibility.visible;
                break;
            case "hidden":
                style.visibility = CSSVisibility.hidden;
                break;
            case "initial":
                style.visibility = CSSVisibility.visible;
                break;
            //case "inherit":
            //    style.visibility = CSSVisibility.visible;
            //    break;
            default:
                addError("Invalid visibility value ", line);
                break;
        }
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
        //r.top = requireNextOptionalNumber();
        //r.left = requireNextOptionalNumber();
        //r.right = requireNextOptionalNumber();
        //r.bottom = requireNextOptionalNumber();

        r.top = requireNextOptionalNumber();
		r.right = requireNextOptionalNumber();
		r.bottom = requireNextOptionalNumber();
		r.left = requireNextOptionalNumber();
	}

    void parseZIndex(ref int i)
    {
        i = cast(int)requireNextOptionalNumber();
    }

	void parsePositionProperty(Style style)
	{
		requireNextToken(TokenType.identifier);
		switch (curToken.value)
		{
			case "static":
				style.position = CSSPosition.static_;
				break;
			case "fixed":
				style.position = CSSPosition.fixed;
				break;
			case "relative":
				style.position = CSSPosition.relative;
				break;
			case "absolute":
				style.position = CSSPosition.absolute;
				break;
			default:
				style.position = CSSPosition.invalid;
				addError(text("Unknown position value '", curToken, "'"), line);
				break;
		}
		skipToEndOfProperty();
	}

	// Parse into val and eat unit specifier as well
	void parseScale(ref CSSScale val)
	{
        if (curToken.value == "fit")
        {
            val.unit = CSSUnit.fit;
            val.value = 1;
            return;
        }
        else if (curToken.value == "auto")
        {
            val.unit = CSSUnit.automatic;
            val.value = 1;
            return;
        }

		assertToken(TokenType.number);
		val.value = curToken.value.to!float();

		bool consumed = false;
		CSSUnit sz = CSSUnit.pixels;

		switch (requireNextTokenKeepSpace(TokenType.invalid).type)
		{
			case TokenType.pct:
				sz = CSSUnit.pct;
				val.value /= 100;
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
						break;
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
					requireNextToken();
					break;
				case "background":
					parseBackgroundProperty(style);
					requireNextToken();
					break;
				case "color":
					parseColor(style._color);
					style._nullFields |= 2;
					requireNextToken();
					break;
				case "background-color":
					parseColor(style._backgroundColor);
					style._nullFields |= 4;
					requireNextToken();
					break;
				case "wordWrap":
					parseWordWrapProperty(style);
                    style._nullFields |= 1;
					requireNextToken();
					break;
				case "visibility":
					parseVisibilityProperty(style);
					requireNextToken();
					break;
				case "padding":
					parseRectOffset(style._padding);
					requireNextToken();
					break;
				case "z-index":
					parseZIndex(style._zIndex);
                    style._nullFields |= 8;
					requireNextToken();
					break;
				case "background-sprite":
					parseRect(style._backgroundSprite);
					requireNextToken();
					break;
				case "background-sprite-border":
					parseRectOffset(style._backgroundSpriteBorder);
					requireNextToken();
					break;
				case "background-sprite-animation":
					parseAnimationProperty(style._backgroundSpriteAnimation);
					requireNextToken();
					break;
				case "position":
					parsePositionProperty(style);
					requireNextToken();
					break;
				case "left":
					requireNextToken();
					parseScale(style._left);
					requireNextToken();
					continue;
				case "top":
					requireNextToken();
					parseScale(style._top);
					requireNextToken();
					continue;
				case "right":
					requireNextToken();
					parseScale(style._right);
					requireNextToken();
					break;
				case "bottom":
					requireNextToken();
					parseScale(style._bottom);
					requireNextToken();
					break;
				case "width":
					requireNextToken();
					parseScale(style._width);
					requireNextToken();
					break;
				case "min-width":
					requireNextToken();
					parseScale(style._minWidth);
					requireNextToken();
					break;
				case "max-width":
					requireNextToken();
					parseScale(style._maxWidth);
					requireNextToken();
					break;
				case "height":
					requireNextToken();
					parseScale(style._height);
					requireNextToken();
					break;
				case "min-height":
					requireNextToken();
					parseScale(style._minHeight);
					requireNextToken();
					break;
				case "max-height":
					requireNextToken();
					parseScale(style._maxHeight);
					requireNextToken();
					break;
				default:
					auto mgr = sheet.manager;
					auto spec = (cast(StyleSheetManager)mgr).lookupPropertySpecification(key);
					if (spec !is null)
					{
						bool parsedOne = false;
						spec.clear(style);
						while (spec.parse(this, style))
						{
							parsedOne = true;
							if (!spec.multi || peekToken.type != TokenType.comma)
								break;
							nextToken();
						}

						if (!parsedOne)
						{
							addError("Could not parse value of " ~ spec.id);
							throw new Exception("Cannot parse spec " ~ spec.id);
						}
					}
					else
					{
						addError("Unknown style key '" ~ key ~ "'", line);
						skipToEndOfProperty();
					}
					requireNextToken();
			}
		}
	}

	void parseSelector(ref Selectors selectors)
	{
		requireNextToken();

		while (true)
		{
			string widgetTypeName = null;
			string widgetName = null;
			string[] classNames = null;
			string pseudoClassName = null;

			bool segmentDone = false;

			// A segment can be either #id or .class or widgetname or a combination
			do
			{
				switch (curToken.type)
				{
					case TokenType.hash:
						requireNextTokenKeepSpace(TokenType.identifier);
						widgetName = curToken.value;
						requireNextTokenKeepSpace();
						break;
					case TokenType.dot:
						requireNextTokenKeepSpace(TokenType.identifier);
						classNames ~= curToken.value;
						requireNextTokenKeepSpace();
						break;
					case TokenType.colon:
						requireNextTokenKeepSpace(TokenType.identifier);
						pseudoClassName = curToken.value;
						requireNextTokenKeepSpace();
						break;
					case TokenType.identifier:
						if (curToken.value != "*")
							widgetTypeName = curToken.value;
						requireNextTokenKeepSpace();
						break;
					case TokenType.curlOpen, TokenType.greaterThan:
						segmentDone = true;
						break;
					case TokenType.whitespace:
						segmentDone = true;
						break;
					case TokenType.star:
						requireNextTokenKeepSpace();
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
					selectors ~= new StylableSelector(widgetTypeName, widgetName, classNames, pseudoClassName);
					return;
				case TokenType.greaterThan:
					selectors ~= new ChildSelector(widgetTypeName, widgetName, classNames, pseudoClassName);
					requireNextToken();
					break;
				default:
					selectors ~= new DescendantSelector(widgetTypeName, widgetName, classNames, pseudoClassName);
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
		requireNextToken(TokenType.at);
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
		parseSelector(rule.selectors);
		parseProperties(rule.style);
		sheet.rules ~= rule;
	}

	bool parse()
	{
		try
		{
			peekToken();
			while(!curToken.eof)
			{
				if (curToken.type == TokenType.at)
					parseCssRule();
				else
					parseRule();
				peekToken();
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
		   sheet.rules[0].selectors.length == 1 &&
		   sheet.rules[0].selectors[0].stylableTypeName == "Widget",
		   "Simple selector and no style definitions");

	parse = new StyleSheetParser("Widget { color: #FF0000 }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 2 &&
		   sheet.rules[1].selectors.length == 1 &&
		   sheet.rules[1].selectors[0].stylableTypeName == "Widget" &&
		   sheet.rules[1].style.color == Color.red,
		   "Simple selector and red color");

	parse = new StyleSheetParser("Widget { color: #FF0000; }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 3 &&
		   sheet.rules[2].selectors.length == 1 &&
		   sheet.rules[2].selectors[0].stylableTypeName == "Widget" &&
		   sheet.rules[2].style.color == Color.red,
		   "Simple selector and red color semicolor end");

	parse = new StyleSheetParser("Widget { color: #FF0000;\n padding : 1 2 3 4;\n wordWrap: true;\n }", sheet, new URI(""), null, null);
	parse.parse();
    Rule r = sheet.rules[3];
	Assert(sheet.rules.length == 4 &&
		   sheet.rules[3].selectors.length == 1 &&
		   sheet.rules[3].selectors[0].stylableTypeName == "Widget" &&
		   sheet.rules[3].style.color == Color.red &&
		   sheet.rules[3].style.wordWrap &&
		   sheet.rules[3].style.padding == RectfOffset(4,1,2,3),
		   "Simple selector and red color and rect and wordWrap	");
}
