module extensionapi.common;

// Common shared stuff in deadcodebase
import dccore.attr;
public import dccore.command;
public import dccore.commandparameter;
public import math.rect;
public import math.region;
public import math.smallvector;

// The rest
public import core.thread;
public import std.variant;

import std.traits;
import std.typetuple;

public import extensionapi.types;

version (DeadcodeClient)
{
    public import extensionapi.rpcapi;
}
else
{
    // Exposed through rpcapi
    public import dccore.log;
    public import application;
    public import edit.bufferview;
    public import controls.texteditor : TextEditor;
}


