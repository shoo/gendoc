/*******************************************************************************
 * Command pipe
 * 
 * Communicate with the launched program commands through stdio pipes.
 */
module gendoc.cmdpipe;

import std.string, std.path, std.parallelism, std.process;
import std.exception, std.algorithm, std.array, std.range;
import dub.internal.vibecompat.data.json;
import gendoc.config, gendoc.modmgr;



/*******************************************************************************
 * Communicate with the launched program through stdio pipes.
 * 
 * gendoc responds to requests from the launched guest program.
 * One request or response communicates via a JSON object without lines.
 * Guest program requests are passed line by line to the standard error output.
 * gendoc responds to requests with one line.
 * The request starts with `::gendoc-request::`, followed by a JSON string.
 * 
 * ```
 * ::gendoc-request::{ "type": "ReqEcho", "value": {"msg": "test"} }
 * ```
 * 
 * The response type corresponds to the request type.
 * 
 * | Request Type          | Response Type        |
 * |:----------------------|:---------------------|
 * | ReqEcho               | ResEcho, ResErr      |
 * | ReqInfo               | ResInfo, ResErr      |
 * 
 * Each piece of information is composed of a JSON object composed of `type` and `value` as follows,
 * and the `value` includes a payload.
 * The following examples include line breaks and indents for readability,
 * but do not break lines in the data actually used.
 * 
 * ```
 * {
 *  "type":  "ReqInfo",
 *  "value": { }
 * }
 * ```
 */
struct CommandPipe
{
private:
	alias Config = gendoc.config.Config;
	string[]            _result;
	string[]            _stderr;
	string[]            _stdout;
	int                 _status;
	const(Config)*      _config;
	const(DubPkgInfo)[] _pkgInfo;
	
	void processing(ProcessPipes pipe)
	{
		
		auto responceTask = scopedTask({
			foreach (line; pipe.stderr.byLine)
			{
				Json json(T)(T val)
				{
					return Json(["type": Json(T.stringof), "value": serializeToJson(val)]);
				}
				try
				{
					enum header = "::gendoc-request::";
					if (!line.startsWith(header))
					{
						_stderr ~= line.chomp().idup;
						_result ~= _stderr[$-1];
						continue;
					}
					auto inputContent = cast(string)(line[header.length..$].idup);
					auto command = parseJson(inputContent);
					switch (command["type"].to!string)
					{
					case "ReqEcho":
						auto req = deserializeJson!ReqEcho(command["value"]);
						pipe.stdin.writeln(json(ResEcho(req.msg)).toString());
						break;
					case "ReqInfo":
						auto req = deserializeJson!ReqInfo(command["value"]);
						pipe.stdin.writeln(json(ResInfo(*_config, _pkgInfo)).toString());
						break;
					default:
						enforce(0, "Unknown request type.");
					}
				}
				catch (Exception e)
				{
					pipe.stdin.writeln(json(ResErr(e.msg)).toString());
				}
				pipe.stdin.flush();
			}
		});
		responceTask.executeInNewThread();
		import std.string;
		foreach (line; pipe.stdout.byLine)
		{
			_stdout ~= line.chomp().idup;
			_result ~= _stdout[$-1];
		}
		responceTask.yieldForce();
		_status = pipe.pid.wait();
	}
	
public:
	///
	this(in ref Config cfg, in DubPkgInfo[] pkgInfo)
	{
		_config  = &cfg;
		_pkgInfo = pkgInfo;
	}
	///
	void run(string[] args, string workDir = null, string[string] env = null)
	{
		processing(pipeProcess(args, Redirect.all, env, std.process.Config.none, workDir));
	}
	/// ditto
	void run(string args, string workDir = null, string[string] env = null)
	{
		processing(pipeShell(args, Redirect.all, env, std.process.Config.none, workDir));
	}
	///
	auto result() const @property
	{
		auto chompLen = _result.retro.count!(a => a.length == 0);
		return _result[0..$-chompLen];
	}
	///
	auto stdout() const @property
	{
		auto chompLen = _stdout.retro.count!(a => a.length == 0);
		return _stdout[0..$-chompLen];
	}
	///
	auto stderr() const @property
	{
		auto chompLen = _stderr.retro.count!(a => a.length == 0);
		return _stderr[0..$-chompLen];
	}
	///
	int status() const @property
	{
		return _status;
	}
}

///
@system unittest
{
	import std.path;
	gendoc.config.Config cfg;
	ModuleManager modmgr;
	modmgr.addSources("root", "v1.2.3", __FILE_FULL_PATH__.buildNormalizedPath("../.."), [__FILE__], null);
	auto pipe = CommandPipe(cfg, modmgr.dubPackages);
	pipe.run("echo xxx");
	pipe.run(["rdmd", "--eval", q{
		stderr.writeln(`test1`);
		stderr.writeln(`::gendoc-request::{ "type": "ReqEcho", "value": {"msg": "test-echo"} }`);
		stderr.writeln(`test2`);
		auto res = stdin.readln();
		writeln(parseJSON(res)["value"]["msg"].str);
		
		stderr.writeln(`::gendoc-request::{ "type": "XXXXX", "value": {"msg": "test"} }`);
		res = stdin.readln();
		writeln(parseJSON(res)["value"]["msg"].str);
		
		stderr.writeln(`::gendoc-request::{ "type": "ReqInfo", "value": {} }`);
		res = stdin.readln();
		writeln(parseJSON(res)["value"]["dubPkgInfos"][0]["packageVersion"].str);
	}]);
	assert(pipe.stderr.equal(["test1", "test2"]));
	assert(pipe.stdout.equal(["xxx", "test-echo", "Unknown request type.", "v1.2.3"]));
	assert(pipe.result.equal(["xxx", "test1", "test2", "test-echo", "Unknown request type.", "v1.2.3"]));
	assert(pipe.status == 0);
}



/*******************************************************************************
 * Test request to return the specified msg without processing.
 * 
 * The main return value is ResEcho.
 * ResErr will be returned if something goes wrong.
 * 
 * Returns:
 * - ResEcho
 * - ResErr
 */
struct ReqEcho
{
	///
	string msg;
}

/*******************************************************************************
 * Main return value of ReqEcho
 */
struct ResEcho
{
	///
	string msg;
}

/*******************************************************************************
 * Request information that gendoc has.
 * 
 * The main return value is ResInfo.
 * ResErr will be returned if something goes wrong.
 * 
 * Returns:
 * - ResInfo
 * - ResErr
 */
struct ReqInfo
{
	
}

/*******************************************************************************
 * Main return value of ReqInfo
 */
struct ResInfo
{
	private alias Config = gendoc.config.Config;
	/// $(REF Config, gendoc, _config)
	Config config;
	/// $(REF DubPkgInfo, gendoc, modmgr)
	DubPkgInfo[] dubPkgInfos;
private:
	this(in ref gendoc.config.Config cfg, in DubPkgInfo[] dpi)
	{
		config = cast()cfg;
		dubPkgInfos = (cast(DubPkgInfo[])dpi[]).dup;
	}
}

/*******************************************************************************
 * Return-value when something wrong.
 */
struct ResErr
{
	///
	string msg;
}
