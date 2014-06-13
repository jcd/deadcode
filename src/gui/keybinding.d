module gui.keybinding;

import gui.keycode;
import gui.ruleset;
import graphics._;

import std.conv;
import std.exception;
import std.format;
import std.range : empty;
import std.variant;
import std.string;

import derelict.sdl2.sdl;

/** KeySequence 
*/
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
			
			//int xor = ~(mod ^ s.mod);

			//bool modMatches = KeyMod.LSHIFT & xor 

			// Match matrix
			
			// mod/s.mod | LSHIFT | RSHIFT | SHIFT | NONE
			// LSHIFT    | yes    | no     | yes   | no
			// RSHIFT    | no     | yes    | yes   | no
			// SHIFT     | yes    | yes    | yes   | no
			// none      | no     | no     | no    | yes
			
			auto shiftNeeded = mod & KeyMod.SHIFT;
			auto shiftGotten = s.mod & KeyMod.SHIFT;
			auto shiftMatch = shiftNeeded & shiftGotten || shiftNeeded == shiftGotten;

			auto ctrlNeeded = mod & KeyMod.CTRL;
			auto ctrlGotten = s.mod & KeyMod.CTRL;
			auto ctrlMatch = ctrlNeeded & ctrlGotten || ctrlNeeded == ctrlGotten;

			auto altNeeded = mod & KeyMod.ALT;
			auto altGotten = s.mod & KeyMod.ALT;
			auto altMatch = altNeeded & altGotten || altNeeded == altGotten;

			auto guiNeeded = mod & KeyMod.GUI;
			auto guiGotten = s.mod & KeyMod.GUI;
			auto guiMatch = guiNeeded & guiGotten || guiNeeded == guiGotten;

			return shiftMatch && ctrlMatch && altMatch && guiMatch;
/*
			bool modMatches = ((KeyMod.LSHIFT & mod) == (KeyMod.LSHIFT & s.mod) ||
							   (KeyMod.RSHIFT & mod) == (KeyMod.RSHIFT & s.mod)) &&
							  ((KeyMod.LCTRL & mod) == (KeyMod.LCTRL & s.mod) ||
							   (KeyMod.RCTRL & mod) == (KeyMod.RCTRL & s.mod)) &&
							  ((KeyMod.LALT & mod) == (KeyMod.LALT & s.mod) ||
							   (KeyMod.RALT & mod) == (KeyMod.RALT & s.mod)) &&
							  ((KeyMod.LGUI & mod) == (KeyMod.LGUI & s.mod) ||
							   (KeyMod.RGUI & mod) == (KeyMod.RGUI & s.mod));
			return modMatches;
	*/		
			/*
			switch (mod)
			{
				case KeyMod.SHIFT:
					return s.mod == KeyMod.LSHIFT || s.mod == KeyMod.RSHIFT || s.mod == KeyMod.SHIFT;
				case KeyMod.CTRL:
					return s.mod == KeyMod.LCTRL || s.mod == KeyMod.RCTRL ||  s.mod == KeyMod.CTRL;
				case KeyMod.ALT:
					return s.mod == KeyMod.LALT || s.mod == KeyMod.RALT || s.mod == KeyMod.ALT;
				case KeyMod.GUI:
					return s.mod == KeyMod.LGUI || s.mod == KeyMod.RGUI || s.mod == KeyMod.GUI;
				default:
					return mod == s.mod;
			}
			*/
		}

		string toString() const
		{
			return text(mod, " ", cast(char)keyCode);
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

	override string toString() const
	{
		string res;
		string delim;
		foreach (k; sequence)
		{
			res ~= delim ~ k.toString();	
			delim = ", ";
		}
		return res;
	}
}

class KeyBinding
{
	KeySequence sequence;
	string command;
	Variant args;
	RuleSet rules;

	this(KeySequence seq, string com, Variant inargs, RuleSet val = null)
	{
		sequence = seq;
		command = com;
		args = inargs;
		rules = val;
	}
	
	this(string seq, string com, Variant inargs, RuleSet val = null)
	{
		sequence = new KeySequence(seq);
		command = com;
		args = inargs;
		rules = val;
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

	bool validate(RuleEnv env)
	{
		return rules is null || rules.test(env);
	}
}

class KeyBindingsSet
{
	private
	{
		KeyBinding[] set;
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
		KeyBinding[] res;
		foreach (kb; set)
		{
			if (kb.match(seq, prefixMatchAllowed))
				res ~= kb;
		}
		return res;
		
	/*
		import std.array;
		return array(std.algorithm.filter!( (a) => { return a.match(seq, prefixMatchAllowed); } )(set));
	*/
	}

	void removeKeyBinding(KeySequence seq)
	{
		KeyBinding[] newSet;
		newSet.length = set.length;
		newSet.length = 0;
		foreach (kb; set)
		{
			if (!kb.match(seq, false))
				newSet ~= kb; 
		}
		set = newSet;
	}

	/** Set the key binding for a command
	 * 
	 * This will overwrite any existing key binding for the specified command if 
	 * already present.
	 * If the key sequence is already used by another key binding then the
	 * the key sequence will be used by both key bindings after this call. This 
	 * means that both commands is executed on key sequence matches.
	 */
	void setKeyBinding(KeyBinding b) //if ( is(T : KeyBinding) ) )
	{
		set ~= b;
		/*
		// Check if a binding for the command is already set and remove that one if so.
		auto r = std.algorithm.find!"a.command == b.command"(set, b);
		
		if (r.empty)
			set ~= b;
		else
			r[0] = b;
			*/
	}
	
	/// ditto
	void setKeyBinding(string seq, string com, Variant args = Variant(), RuleSet val = null)
	{
		setKeyBinding(new KeyBinding(seq, com, args, val));
	}	
	
	/// ditto
	// TODO: Make into template when 2.065 is reached
	void setKeyBinding(string seq, string com, string arg, RuleSet val = null)
	{
		setKeyBinding(new KeyBinding(seq, com, Variant(arg), val));
	}	

	/// ditto
	void setKeyBinding(string seq, string com, RuleSet val)
	{
		setKeyBinding(new KeyBinding(seq, com, Variant(), val));
	}	

	// ditto
	void setKeyBinding(KeySequence seq, string com, Variant args = Variant(), RuleSet val = null) 
	{
		setKeyBinding(new KeyBinding(seq, com, args, val));
	}	

	/// ditto
	/*
	void setKeyBinding(string seq, string commandName, Variant args = Variant(), RuleSet val = null) 
	{
		auto s = new KeySequence(seq);

		auto com = commandManager.lookup(commandName);
		if (com !is null)
		{
			setKeyBinding(seq, com, args, val);
		}
		else
		{
			// Lazy lookup
			// Make a delayed binding Command
			class DelayedBindingCommand : Command
			{

				// Remember if binding has been done. This instance may be called
				// anyway in case someone got a reference to it somehow.
				bool _delayedBindingDone;

				this()
				{
					super(commandName, "Delayed binding command for " ~ commandName);
					_delayedBindingDone = false;
				}

				private Command createBinding()
				{
					auto comm = commandManager.lookup(commandName);
					if (comm is null)
						return null;

					if (_delayedBindingDone)
						return comm;

					// remove existing entry in the set
					removeKeyBinding(s);
					setKeyBinding(s, comm, args, val);
					_delayedBindingDone = true;
					return comm;
				}

				override bool canExecute(Variant data)
				{
					auto comm = createBinding();
					if (comm is null)
						return false;
					return comm.canExecute(data);
					// This instance of this class will no be used for following bindings to the sequence since
					// we just overwrote the entry
				}
				
				override void execute(Variant data)
				{
					auto comm = createBinding();
					if (comm is null)
						return;
					comm.execute(data);
					// This instance of this class will no be used for following bindings to the sequence since
					// we just overwrote the entry
				}
			}
			//}
			setKeyBinding(s, new DelayedBindingCommand());
		}
	}
	*/
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
	void setKeyBinding(T)(T seq, string com) if ( is(T : string) || is(T : KeySequence))
	{
		stack[0].setKeyBinding(seq, com);
	}

	/*
	/// ditto
	void setKeyBinding()(string seq, string commandName) 
	{
		stack[0].setKeyBinding(seq, commandName);
	}
	*/
}
