module gui.keybinding;

import gui.command;
import gui.keycode;
import graphics._;

import std.conv;
import std.exception;
import std.range : empty;
import std.variant;
import std.string;

import derelict.sdl2.sdl;

class KeySequence
{
	struct Key
	{
		SDL_Keycode keyCode;
		KeyMod  mod;
	
		bool match(ref const Key s) 
		{ 
			// Modifiers need special treatment because e.g. lctrl is a subset of ctrl
			if (keyCode != s.keyCode) 
				return false;
			
			switch (mod)
			{
				case KeyMod.SHIFT:
					return s.mod == KeyMod.LSHIFT || s.mod == KeyMod.RSHIFT;
					break;
				case KeyMod.CTRL:
					return s.mod == KeyMod.LCTRL || s.mod == KeyMod.RCTRL;
					break;
				case KeyMod.ALT:
					return s.mod == KeyMod.LALT || s.mod == KeyMod.RALT;
					break;
				case KeyMod.GUI:
					return s.mod == KeyMod.LGUI || s.mod == KeyMod.RGUI;
					break;
				default:
					return mod == s.mod;
			}
		}
	}
	
	Key[] sequence;
	
	/** Create a key sequence from a string 
	 * 
	 * The string can contain normal characters and the special tokens:
	 * * <ctrl>
	 * * <alt>
	 * * <shift>
	 * * <space>
	 * * <enter>
	 * * <pushMode> prefix
	 * * <popMode>
	 */
	this(string seq)
	{
		import std.array;
		auto toks = split(strip(seq));
		KeyMod mod = KeyMod.NONE;
		
		KeyMod stringToKeyMod(string s)
		{
			switch (s)
			{
			case "<ctrl>":
				return KeyMod.CTRL;
			case "<lctrl>":
				return KeyMod.RCTRL;
			case "<rctrl>":
				return KeyMod.LCTRL;
			case "<alt>":
				return KeyMod.ALT;
			case "<lalt>":
				return KeyMod.LALT;
			case "<ralt>":
				return KeyMod.RALT;
			case "<shift>":
				return KeyMod.SHIFT;
			case "<lshift>":
				return KeyMod.LSHIFT;
			case "<rshift>":
				return KeyMod.RSHIFT;
			default: 
				return KeyMod.NONE;
			}
		}	
			
		while (!toks.empty)
		{
			auto tok = toks[0];
			toks = toks[1..$];
			if (tok.empty)
				continue;
			
			auto m = stringToKeyMod(tok);
			if (m != KeyMod.NONE)
			{
				mod = mod | m;
			
				// next token must be a +
				enforceEx!Exception(!toks.empty && toks[0] == "+", text("Missing + after ", tok , " in \"", seq , "\""));
				toks = toks[1..$];
				enforceEx!Exception(toks.length >= 1, text("Missing key control sequence terminating character after \"", tok, " + \""));
				continue;
			}
			
			if (tok.length != 1)
			{
				// Everything but single chars must be inside <...>
				enforceEx!Exception(tok[0] == '<' && tok[tok.length-1] == '>', text("Space needed between tokens \"", tok, "\""));
				tok = tok.chompPrefix("<").chomp(">");
			}
			sequence ~= Key(stringToKeyCode(tok), mod);
			mod = KeyMod.NONE;
		}
		//std.stdio.writeln(sequence);
	}
		
	unittest 
	{
		
	}
		
	@property size_t length() const pure nothrow @safe
	{
		return sequence.length;
	}

	@property void length(size_t l) 
	{
		sequence.length = l;
	}
	
	void add(SDL_Keycode code, KeyMod mod)
	{
		sequence ~= Key(code, mod);
	}
	
	void clear()
	{
		sequence.length = 0;
	}
	
	/** Check if a key sequence matches this key binding.
	 * 
	 * Params:
	 * 		seq the sequence to match
	 * 		prefixMatchAllowed if seq is a prefix of the bindings key sequence then setting this to true will take that as a match
	 * 
	 * Returns:
	 * 		true if a key sequence matches
	 */
	bool match(KeySequence seq, bool prefixMatchAllowed)
	{
		if (!prefixMatchAllowed && seq.length != sequence.length)
			return false;
		//std.stdio.writeln(seq.sequence);
		foreach (i, k; seq.sequence)
		{
			if (i == sequence.length)
				return false; // incoming sequence too long. Should not happen!
			
			if (!sequence[i].match(k))
				return false;			
		}
		return !seq.sequence.empty;
	}
}

class KeyBinding
{
	KeySequence sequence;
	Command command;
	
	this(KeySequence seq, Command com)
	{
		this.sequence = seq;
		this.command = com;
	}
	
	this(string seq, Command com)
	{
		this.sequence = new KeySequence(seq);
		this.command = com;
	}

	/** Check if a key sequence matches this key binding.
	 * 
	 * Params:
	 * 		seq the sequence to match
	 * 		prefixMatchAllowed if seq is a prefix of the bindings key sequence then setting this to true will take that as a match
	 * 
	 * Returns:
	 * 		true if a key sequence matches
	 */
	bool match(KeySequence seq, bool prefixMatchAllowed = false)
	{
		return sequence.match(seq, prefixMatchAllowed);
	}
}

class KeyBindingsSet
{
	KeyBinding[] set;
	
	/** Check if a key sequence matches any key binding.
	 * 
	 * Params:
	 * 		seq the sequence to match
	 * 		prefixMatchAllowed if seq is a prefix of the bindings key sequence then setting this to true will take that as a match
	 * 
	 * Returns:
	 * 		the list of matching key bindings
	 */
	KeyBinding[] match(KeySequence seq, bool prefixMatchAllowed = false)
	{
		KeyBinding[] res;
		foreach (kb; set)
			if (kb.match(seq, prefixMatchAllowed))
				res ~= kb;
		return res;
		
	/*
		import std.array;
		return array(std.algorithm.filter!( (a) => { return a.match(seq, prefixMatchAllowed); } )(set));
	*/
	}

	/** Set the key binding for a command
	 * 
	 * This will overwrite any existing key binding for the specified command if 
	 * already present.
	 * If the key sequence is already used by another key binding then the
	 * the key sequence will be used by both key bindings after this call. This 
	 * means that both commands is executed on key sequence matches.
	 */
	void setKeyBinding()(KeyBinding b) //if ( is(T : KeyBinding) ) )
	{
		// Check if a binding for the command is already set and remove that one if so.
		auto r = std.algorithm.find!"a.command == b.command"(set, b);
		
		if (r.empty)
			set ~= b;
		else
			r[0] = b;
	}
	
	/// ditto
	void setKeyBinding(T)(T seq, Command com) if ( is(T : string) || is(T : KeySequence))
	{
		setKeyBinding(new KeyBinding(seq, com));
	}	

	/// ditto
	void setKeyBinding()(string seq, string commandName) 
	{
		auto s = new KeySequence(seq);
		auto com = CommandManager.singleton.lookup(commandName);
		if (com is null)
		{
			std.stdio.writeln("Warning: no commmand named ", commandName, " for binding to \"", seq, "\"");
			// Make a delayed binding Command
			static class DelayedBindingCommand : Command
			{
				Command cmd;
				this(string name)
				{
					super(name, "Delayed binding command");
				}
				
				override bool canExecute(Variant data)
				{
					std.stdio.writeln("fdsafdsa");
					cmd = cmd is null ? CommandManager.singleton.lookup(name) : cmd;
					return cmd !is null && cmd.canExecute(data);
				}
				
				override void execute(Variant data)
				{
					cmd = cmd is null ? CommandManager.singleton.lookup(name) : cmd;
					if (cmd is null) return;
					cmd.execute(data);
				}
			}
			com = new DelayedBindingCommand(commandName);
		}
		setKeyBinding(s, com);
	}
}

class KeyBindingStack
{
	KeyBindingsSet[] stack;
	
	/** Current active key bindings 
	 */
	private @property ref KeyBindingsSet keyBindings()
	{
		return stack[$];
	}
	
	/** Push a new KeyBindings set at the new active one
	 * 
	 * This can be pop() later on to restore the old one.
 	 */
	void push(KeyBindingsSet b)
	{
		stack ~= b;
	}
	
	/** Pop the active key bindings of stack
	 * 
	 * This will restore the previous key bindings as the active
	 */
	void pop()
	{
		stack.length = stack.length - 1;
	}

	/** Check if a key sequence matches any key binding.
	 * 
	 * Params:
	 * 		seq the sequence to match
	 * 		prefixMatchAllowed if seq is a prefix of the bindings key sequence then setting this to true will take that as a match
	 * 
	 * Returns:
	 * 		the list of matching key bindings
	 */
	KeyBinding[] match(KeySequence seq, bool prefixMatchAllowed = false)
	{
		return stack[0].match(seq, prefixMatchAllowed);
	}
	
	/** Set the key binding for a command
	 * 
	 * This will overwrite any existing key binding for the specified command if 
	 * already present.
	 * If the key sequence is already used by another key binding then the
	 * the key sequence will be used by both key bindings after this call. This 
	 * means that both commands is executed on key sequence matches.
	 */
	void setKeyBinding()(KeyBinding b) //if ( is(T : KeyBinding) ) )
	{
		stack[0].setKeyBinding(b);
	}
	
	/// ditto
	void setKeyBinding(T)(T seq, Command com) if ( is(T : string) || is(T : KeySequence))
	{
		stack[0].setKeyBinding(seq, com);
	}

	/// ditto
	void setKeyBinding()(string seq, string commandName) 
	{
		stack[0].setKeyBinding(seq, commandName);
	}
}
