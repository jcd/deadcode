module extensionapi.remotecommand;

import dccore.command : Command, CompletionEntry;
import dccore.commandparameter : CommandParameter, CommandParameterDefinition, CommandParameterDefinitions;
import io.tcp : TCPClient;
import extensionapi.rpc; /// : RPCObjectLookup, RPC, registerRPC;

mixin registerRPC;

class RemoteCommand : Command
{
    private
    {
        TCPClient _client;
        extensionapi.rpc.RPCObjectLookup _lookup;
        string _name;
    }

    this(TCPClient cl, extensionapi.rpc.RPCObjectLookup lo, string cmdName, CommandParameterDefinition[] paramDefs)
    {
        _client = cl;
        _lookup = lo;
        _name = cmdName;
        setCommandParameterDefinitions(CommandParameterDefinitions.create(paramDefs));
    }

    @property const(TCPClient) client() const
    {
        return _client;
    }

    override @property string name() const
    {
        return _name;
    }

    final override bool canExecute(CommandParameter[] data)
	{
		return true;
	}

    final override void execute(CommandParameter[] data)
    {
        _client.callRemoteCommand(_lookup, _name, data);
    }

    final override bool executeWithMissingArguments(ref CommandParameter[] data)
    {
        return false; /* false => not handled by method */
    }

	final override void undo(CommandParameter[] data) { }

    final override int getCompletionSessionID() { return -1; /* no session support */ }
    final override bool beginCompletionSession(int sessionID) { return false; }
    final override void endCompletionSession() {}

    final override CompletionEntry[] getCompletions(CommandParameter[] data)
    {
        return null;
    }
}

@RPC
class RemoteCommandRegistrar
{
    import dccore.command : CommandManager;

    private CommandManager _commandManager;
    TCPClient client;

    @RPC
    int id;

    private extensionapi.rpc.RPCObjectLookup _lookup;

    this(CommandManager mgr, extensionapi.rpc.RPCObjectLookup lo)
    {
        _commandManager = mgr;
        _lookup = lo;
    }

    @RPC
    void addRemoteCommand(string name, CommandParameterDefinition[] paramDefs)
    {
        auto c = new RemoteCommand(client, _lookup, name, paramDefs);
        _commandManager.add(c);
    }
}
