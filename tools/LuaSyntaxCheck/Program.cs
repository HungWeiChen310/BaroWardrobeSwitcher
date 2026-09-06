using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;

if (args.Length == 0)
{
    Console.Error.WriteLine("Usage: LuaSyntaxCheck [--execute] <file-or-directory> [...]");
    return 64;
}

bool execute = args[0] == "--execute";
string[] paths = execute ? args.Skip(1).ToArray() : args;
if (paths.Length == 0)
{
    Console.Error.WriteLine("At least one Lua path is required.");
    return 64;
}

var files = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
foreach (string argument in paths)
{
    string path = Path.GetFullPath(argument);
    if (File.Exists(path))
    {
        files.Add(path);
    }
    else if (Directory.Exists(path))
    {
        foreach (string file in Directory.EnumerateFiles(path, "*.lua", SearchOption.AllDirectories))
        {
            files.Add(file);
        }
    }
    else
    {
        Console.Error.WriteLine($"Path not found: {path}");
        return 66;
    }
}

int failures = 0;
foreach (string file in files)
{
    try
    {
        string source = File.ReadAllText(file);
        var script = new Script(CoreModules.Preset_Complete);
        if (execute)
        {
            script.Options.ScriptLoader = new FileSystemScriptLoader();
            script.Globals["MeasureWardrobeWorkload"] = DynValue.NewCallback((_, arguments) =>
            {
                GC.Collect();
                long allocated = GC.GetAllocatedBytesForCurrentThread();
                long started = System.Diagnostics.Stopwatch.GetTimestamp();
                script.Call(arguments[1]);
                double milliseconds = System.Diagnostics.Stopwatch.GetElapsedTime(started).TotalMilliseconds;
                long bytes = GC.GetAllocatedBytesForCurrentThread() - allocated;
                Console.WriteLine($"BENCH {arguments[0].String}: {milliseconds:F3} ms; {bytes} allocated bytes");
                return DynValue.Nil;
            });
            script.DoFile(file);
        }
        else
        {
            script.LoadString(source, codeFriendlyName: file);
        }
        Console.WriteLine($"PASS {file}");
    }
    catch (SyntaxErrorException exception)
    {
        failures++;
        Console.Error.WriteLine($"FAIL {file}: {exception.DecoratedMessage}");
    }
    catch (InterpreterException exception)
    {
        failures++;
        Console.Error.WriteLine($"FAIL {file}: {exception.DecoratedMessage}");
        foreach (var frame in exception.CallStack ?? [])
        {
            Console.Error.WriteLine($"  {frame.Name}: source {frame.Location?.SourceIdx}, line {frame.Location?.FromLine}");
        }
    }
}

return failures == 0 ? 0 : 1;
