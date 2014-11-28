module util.build;

import std.process;
import std.stdio;
version(OFF):

import std.array;
import std.algorithm;
//string dmdPath = "dmd.exe ";
string dmdPath = "C:\\D\\dmd2-src\\src\\dmd\\src\\dmd.exe ";
// Standard imports
const string[] baseImportPaths = ["C:\\D\\dmd2-src\\src\\druntime\\import", "C:\\D\\dmd2-src\\src\\phobos"];

// Derelicts
const string derelictPath = "C:\\Users\\jonasd\\Documents\\Projects\\Derelict3\\";
const string derelictLibPath = derelictPath ~ "lib\\";
const string derelictImportPath = derelictPath ~ "import";
const string[] libFiles = [ "DerelictGL3.lib", "DerelictUtil.lib", "DerelictSDL2.lib" ];

const string[] importPaths = baseImportPaths ~ derelictImportPath;

// Project base files
const string[] baseFiles = [ 
	"main.d", "system.d", "gui.d", "graphics\\_.d", "math.d", "editor.d", "font.d", "smallvector.d", "smallmatrix.d", "dbg.d", "behavior\\emacs.d", "behavior\\behavior.d", "command.d", "keybinding.d", "editorcommands.d", "render.d", "widget.d", "widgetfeature.d", "color.d", "style.d", "region.d", "buffer.d", "bufferview.d", "models.d", "styledtext.d"
    //"main.d", "widget.d"
                            ];

string flags = " -debug -unittest -property -gc ";

string objDir = "-odobj\\Debug";
string outDir = "C:\\Users\\jonasd\\Documents\\Projects\\dteam\\ded\\bin\\Debug\\";
string outFile = "ded.exe";


void buildIt()
{
	string cmd = dmdPath ~ flags;
	cmd ~= " ";
	cmd ~= baseFiles.toCmdFiles();
	cmd ~= " ";
	cmd ~= libFiles.toCmdFiles(derelictLibPath);
	cmd ~= " ";
	cmd ~= importPaths.toCmdFiles("-I");
	cmd ~= " ";
	cmd ~= quote(objDir);
	cmd ~= " ";
	cmd ~= quote("-of" ~ outDir ~ outFile);
	cmd ~= "  " ;
	std.stdio.writeln(cmd);
	string res = shell(cmd);
	std.stdio.writeln(res);
}

string quote(string v)
{
	return "\"" ~ v ~ "\"";
}

string toCmdFiles(const string[] paths, string prefixPath = null)
{
	return map!((string v) { return quote(prefixPath ~ v); })(paths).join(" ");
}

version (CMDLINEBUILD)
{
	int main(string[] argv)
	{
		buildIt();
	}
}

//dmd.exe -debug -gc "main.d" "gui.d" "graphics.d" "math.d" "editor.d" "font.d" "smallvector.d" "smallmatrix.d" "dbg.d" "behavior\emacs.d" "behavior\behavior.d" "command.d" "keybinding.d" "editorcommands.d" "render.d" "widget.d" "widgetfeature.d" "color.d" "style.d" "region.d" "buffer.d" "bufferview.d" "models.d" "styledtext.d" "C:\Users\jonasd\Documents\Projects\Derelict3\lib\DerelictGL3.lib" "C:\Users\jonasd\Documents\Projects\Derelict3\lib\DerelictUtil.lib" "C:\Users\jonasd\Documents\Projects\Derelict3\lib\DerelictSDL2.lib" 
//"-IC:\D\dmd2\src\phobos" "-IC:\D\dmd2\src\druntime\import" "-IC:\Users\jonasd\Documents\Projects\Derelict3\import" 
//"-odobj\Debug" "-ofC:\Users\jonasd\Documents\Projects\dteam\ded\bin\Debug\ded.exe" -property -unittest
