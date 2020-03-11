/*******************************************************************************
 * Document generator
 * 
 * Passes module information such as paths or compilation options to the compiler,
 * and generate JSON and HTML files. And also convert mustache files.
 */
module gendoc.generator;


import std.file, std.path, std.algorithm, std.range, std.array, std.exception;

import dub.internal.vibecompat.inet.path;
import dub.internal.vibecompat.data.json;
import dub.internal.utils;

import gendoc.modmgr;



/*******************************************************************************
 * 
 */
private struct JsonModuleData
{
	///
	@optional
	string name;
	///
	string file;
	///
	@optional
	string comment;
}

/*******************************************************************************
 * 
 */
private JsonModuleData[] getModuleDatas(string jsonfile)
{
	import std.file, std.path, std.exception;
	if (jsonfile.length == 0 || !jsonfile.exists || !jsonfile.isFile)
		return null;
	return deserializeJson!(JsonModuleData[])(jsonFromFile(NativePath(jsonfile)));
}


/*******************************************************************************
 * 
 */
struct MustashImportOptions
{
	///
	@optional
	string         file;
	///
	@optional
	string[]       imports;
	///
	@optional
	string         contents;
	///
	@optional
	string[string] map;
	///
	@optional
	string[]       useSections;
}

/*******************************************************************************
 * 
 */
private Json parseOption(string opt)
{
	import std.string;
	auto lines = (opt ~ "\n").splitLines;
	if (lines.length == 0)
		return Json.init;
	try
	{
		if (lines[0].stripLeft.startsWith("{", "[", "\""))
			return parseJson(opt);
	}
	catch (Exception e)
	{
	}
	return Json(opt);
}

/*******************************************************************************
 * 
 */
private MustashImportOptions getMustashImportOptions(Json json)
{
	if (json.type == Json.Type.null_)
	{
		return MustashImportOptions.init;
	}
	else if (json.type == Json.Type.array)
	{
		import std.getopt;
		auto args = json.get!(Json[]).map!(a => a.to!string).array;
		if (args.length == 0)
			return MustashImportOptions.init;
		MustashImportOptions ret;
		args.getopt(
			"m|map",        &ret.map,
			"i|import",     &ret.imports,
			"u|use",        &ret.useSections);
		ret.file = args[0];
		return ret;
	}
	else if (json.type == Json.Type.object)
	{
		return json.deserializeJson!MustashImportOptions();
	}
	else
	{
		MustashImportOptions ret;
		ret.contents = json.to!string();
		return ret;
	}
}

/// ditto
private MustashImportOptions getMustashImportOptions(string opt)
{
	return getMustashImportOptions(parseOption(opt));
}



/*******************************************************************************
 * 
 */
struct MustashCommandOptions
{
	///
	@optional
	string[]       args;
	///
	@optional
	string[string] env;
	///
	@optional
	string         workDir;
}

/*******************************************************************************
 * 
 */
private MustashCommandOptions getMustashCommandOptions(Json json)
{
	if (json.type == Json.Type.null_)
	{
		return MustashCommandOptions.init;
	}
	else if (json.type == Json.Type.array)
	{
		import std.getopt;
		auto args = [""] ~ json.get!(Json[]).map!(a => a.to!string).array;
		if (args.length == 0)
			return MustashCommandOptions.init;
		MustashCommandOptions ret;
		args.getopt(
			"a|args",             &ret.args,
			"e|env|environment",  &ret.env,
			"d|workDir|work|dir", &ret.workDir);
		return ret;
	}
	else if (json.type == Json.Type.object)
	{
		return json.deserializeJson!MustashCommandOptions();
	}
	else
	{
		import std.string;
		MustashCommandOptions ret;
		ret.args = json.to!string().splitLines.map!(a => a.strip).filter!(a => a.length > 0).array;
		return ret;
	}
}

/// ditto
private MustashCommandOptions getMustashCommandOptions(string opt)
{
	return getMustashCommandOptions(parseOption(opt));
}

/***************************************************************
 * 
 */
struct DocumentGenerator
{
private:
	import std.file, std.path, std.algorithm;
	import mustache;
	
	alias Mustache        = MustacheEngine!string;
	alias MustacheContext = Mustache.Context;
	
	string _tempDir;
	
	Mustache _mustache;
	
	string _mustacheFindPath(string name, string[] dirs)
	{
		string _makeFileBasename(string n)
		{
			if (n.endsWith("." ~ _mustache.ext))
				return n;
			return n ~ "." ~ _mustache.ext;
		}
		string _makeFilename(string dir, string n)
		{
			return dir.buildPath(_makeFileBasename(n));
		}
		if (_makeFileBasename(name).exists)
			return _makeFileBasename(name);
		foreach (file; dirs.map!(a => _makeFilename(a, name)).filter!(a => a.exists))
			return file;
		return _makeFilename(_mustache.path, name);
	}
	
	string _mustacheRenderChildren(PackageAndModuleData[] datas, string caller, string options)
	{
		if (datas.length == 0)
			return null;
		
		string ret;
		
		// オプションを解析
		auto opt = getMustashImportOptions(options);
		
		// mustacheのデータを定義
		foreach (ref dat; datas)
		() {
			auto ctx = new MustacheContext;
			foreach (k, v; opt.map)
				ctx[k] = v;
			foreach (e; opt.useSections)
				ctx.useSection(e);
			auto children = dat.children.dup;
			children.moduleSort();
			if (dat.isPackage)
			{
				ctx.useSection("is_package");
				ctx["name"] = dat.packageInfo.name;
				if (dat.isPackageModule)
				{
					ctx.useSection("has_package_d");
					ctx["page_url"]         = dat.packageInfo.packageD.dst;
					ctx["package_name"]     = dat.packageInfo.packageD.pkgName;
					ctx["module_name"]      = dat.packageInfo.packageD.modName;
					ctx["full_module_name"] = dat.packageInfo.packageD.fullModuleName;
					ctx["source_path"]      = dat.packageInfo.packageD.src;
					ctx["dub_package_name"] = dat.packageInfo.packageD.dubPkgName;
					ctx["module_title"]     = dat.packageInfo.packageD.title;
				}
				else
				{
					ctx.useSection("no_package_d");
					ctx["page_url"]         = "";
					ctx["package_name"]     = dat.packageInfo.pkgName;
					ctx["module_name"]      = "";
					ctx["full_module_name"] = "";
					ctx["source_path"]      = "";
					ctx["dub_package_name"] = dat.packageInfo.dubPkgName;
					ctx["module_title"]     = "";
				}
			}
			else
			{
				ctx.useSection("is_module");
				ctx["name"]             = dat.moduleInfo.modName;
				ctx["page_url"]         = dat.moduleInfo.dst;
				ctx["package_name"]     = dat.moduleInfo.pkgName;
				ctx["module_name"]      = dat.moduleInfo.modName;
				ctx["full_module_name"] = dat.moduleInfo.fullModuleName;
				ctx["source_path"]      = dat.moduleInfo.src;
				ctx["dub_package_name"] = dat.moduleInfo.dubPkgName;
				ctx["module_title"]     = dat.moduleInfo.title;
			}
			auto importDirs = opt.imports ~ [caller.dirName];
			auto finder = (string n) => _mustacheFindPath(n, importDirs);
			auto datCaller = opt.file.length > 0 ? finder(opt.file) : caller;
			ctx["children"]    = (string str) => _mustacheRenderChildren(children, datCaller, str);
			ctx["command"]     = (string str) => _mustacheRenderCommand(datCaller, str);
			ctx["rdmd"]        = (string str) => _mustacheRenderEvalD(datCaller, str);
			ctx["environment"] = (string str) => _mustacheRenderEnv(datCaller, str);
			_mustache.findPath = finder;
			// mustacheのレンダリング
			if (opt.file.length > 0)
			{
				ret ~= _mustache.render(opt.file, ctx);
			}
			else
			{
				ret ~= _mustache.renderString(opt.contents, ctx);
			}
		} ();
		return ret;
	}
	
	string _mustacheRenderCommand(string caller, string options)
	{
		import std.process, std.string;
		import gendoc.misc;
		string ret;
		// オプションを解析
		auto opt = getMustashCommandOptions(options);
		
		bool mapFunc(ref string arg, MacroType type)
		{
			if (auto val = environment.get(arg, null))
			{
				arg = val;
				return true;
			}
			return false;
		}
		// マクロ展開
		foreach (k, ref v; opt.env)
			v = v.expandMacro(&mapFunc);
		foreach (ref a; opt.args)
			a = a.expandMacro(&mapFunc);
		opt.workDir = opt.workDir.expandMacro(&mapFunc);
		
		// コマンド呼び出し
		if (opt.args.length == 1)
		{
			ret = commandProcessor(opt.args[0], opt.workDir, opt.env);
		}
		else
		{
			ret = executeProcessor(opt.args, opt.workDir, opt.env);
		}
		return ret;
	}
	
	string _mustacheRenderEvalD(string caller, string dsrc)
	{
		// rdmd呼び出し
		return executeProcessor(["rdmd", "--eval", dsrc], caller.dirName, null);
	}
	
	string _mustacheRenderEnv(string caller, string key)
	{
		import std.process;
		return environment.get(key);
	}
	
	string _mustacheRenderDubPackages(DubPkgInfo[] projects, string dir, string name)
	{
		if (projects.length == 0)
			return null;
		
		auto ctx = new MustacheContext;
		ctx["project_name"]    = projects[0].name;
		ctx["project_version"] = projects[0].packageVersion;
		ctx["command"]         = (string str) => _mustacheRenderCommand(_mustacheFindPath(name, null), str);
		ctx["rdmd"]            = (string str) => _mustacheRenderEvalD(_mustacheFindPath(name, null), str);
		ctx["environment"]     = (string str) => _mustacheRenderEnv(_mustacheFindPath(name, null), str);
		
		foreach (p; projects)
		() {
			auto children  = p.children.dup;
			children.moduleSort();
			auto sc = ctx.addSubContext("dub_pkg_info");
			sc["name"]        = p.name;
			sc["version"]     = p.packageVersion;
			sc["dir"]         = p.dir;
			sc["children"]    = (string str) => _mustacheRenderChildren(children, _mustacheFindPath(name, null), str);
			sc["command"]     = (string str) => _mustacheRenderCommand(_mustacheFindPath(name, null), str);
			sc["rdmd"]        = (string str) => _mustacheRenderEvalD(_mustacheFindPath(name, null), str);
			sc["environment"] = (string str) => _mustacheRenderEnv(_mustacheFindPath(name, null), str);
		} ();
		
		_mustache.path = dir;
		_mustache.findPath = null;
		return _mustache.render(name, ctx);
	}
	
	static string _fixAbs(string base, string path)
	{
		return path.isAbsolute ? path: base.buildPath(path).absolutePath();
	}
	void _copyFile(string target, string source)
		in (target.isAbsolute)
		in (source.isAbsolute)
	{
		if (!target.dirName.exists)
			target.dirName.mkdirRecurse();
		std.file.copy(source, target);
		if (postCopyCallback !is null)
			postCopyCallback(source.relativePath(rootDir), target.relativePath(targetDir));
	}
	
	void _singleFileCompilation(DubPkgInfo dubpkg)
	{
		auto modules = dubpkg.entries.filter!(
			a => (a.isModule() || a.isPackageModule) && a.moduleInfo.src.extension.startsWith(".d"));
		foreach (m; modules.map!(a => a.moduleInfo))
			_generateD(dubpkg.name, _fixAbs(targetDir, m.dst), _fixAbs(rootDir, m.src), dubpkg.options);
	}
	
	void _defaultCompilation(DubPkgInfo dubpkg)
	{
		auto modules = dubpkg.entries.filter!(
			a => a.isModule() && a.moduleInfo.src.extension.startsWith(".d"));
		_generateD(dubpkg.name, modules.map!(a => a.moduleInfo).array, dubpkg.options);
		auto pkgMods = dubpkg.entries.filter!(
			a => a.isPackageModule() && a.moduleInfo.src.extension.startsWith(".d"));
		foreach (m; pkgMods.map!(a => a.moduleInfo))
			_generateD(dubpkg.name, _fixAbs(targetDir, m.dst), _fixAbs(rootDir, m.src), dubpkg.options);
	}
	
	void _ldcCompilation(DubPkgInfo dubpkg)
	{
		auto modules = dubpkg.entries.filter!(
			a => (a.isModule() || a.isPackageModule()) && a.moduleInfo.src.extension.startsWith(".d"));
		_generateD_ldc(dubpkg.name, modules.map!(a => a.moduleInfo).array, dubpkg.options);
	}
	
	string[] _copyTempDsrcs(string tempSrcDir, ModInfo[] files)
	{
		string[] tmpSrcs;
		foreach (ref f; files)
		{
			auto tf = tempSrcDir.buildPath(f.dst.baseName.stripExtension() ~ f.src.extension);
			std.file.copy(rootDir.buildPath(f.src), tf);
			tmpSrcs ~= tf;
		}
		return tmpSrcs;
	}
	
	void _generateD(string dubPkgName, string target, string source, string[] options)
		in (target.isAbsolute)
		in (source.isAbsolute)
	{
		import std.process: execute;
		auto args = [compiler, "-o-"];
		args ~= options;
		args ~= ["-Df" ~ target, source] ~ ddocFiles;
		if (!disableMarkdown)
			args ~= "-preview=markdown";
		ModInfo modInfo;
		modInfo.src = source.relativePath(rootDir);
		modInfo.dst = target.relativePath(targetDir);
		if (preGenerateCallback !is null)
			preGenerateCallback(null, [modInfo], args);
		
		auto result = execute(args);
		
		if (postGenerateCallback !is null)
			postGenerateCallback(null, [modInfo], result.status, result.output);
	}
	
	void _generateD(string dubPkgName, ModInfo[] files, string[] options)
	{
		import std.array;
		import std.process: execute;
		bool remtmpdir = _tempDir.length == 0;
		if (remtmpdir)
			createTemporaryDir();
		scope (exit) if (remtmpdir)
			removeTemporaryDir();
		auto tmpSrcs = _copyTempDsrcs(_tempDir, files);
		
		auto argsApp = appender!(string[]);
		argsApp ~= [compiler, "-o-"];
		argsApp ~= ["-Dd" ~ targetDir];
		argsApp ~= options;
		argsApp ~= ddocFiles;
		argsApp ~= tmpSrcs;
		if (!disableMarkdown)
			argsApp ~= "-preview=markdown";
		
		if (preGenerateCallback !is null)
			preGenerateCallback(dubPkgName, files, argsApp.data);
		
		auto result = execute(argsApp.data);
		
		if (postGenerateCallback !is null)
			postGenerateCallback(dubPkgName, files, result.status, result.output);
	}
	
	void _generateD_ldc(string dubPkgName, ModInfo[] files, string[] options)
	{
		import std.array;
		import std.process: execute;
		bool remtmpdir = _tempDir.length == 0;
		if (remtmpdir)
			createTemporaryDir();
		scope (exit) if (remtmpdir)
			removeTemporaryDir();
		
		auto tempDstJson = _tempDir.buildPath(".gendocwork.json");
		auto argsApp = appender!(string[]);
		auto srcfiles = files.map!(a => _fixAbs(rootDir, a.src).buildNormalizedPath()).array;
		argsApp ~= [compiler, "-o-", "-oq"];
		argsApp ~= ["-Dd" ~ _tempDir, "-X", "-Xf" ~ tempDstJson];
		argsApp ~= options;
		argsApp ~= ddocFiles;
		argsApp ~= srcfiles;
		if (!disableMarkdown)
			argsApp ~= "-preview=markdown";
		
		if (preGenerateCallback !is null)
			preGenerateCallback(dubPkgName, files, argsApp.data);
		
		auto result = execute(argsApp.data);
		
		if (postGenerateCallback !is null)
			postGenerateCallback(dubPkgName, files, result.status, result.output);
		
		auto jsModDatas = getModuleDatas(tempDstJson);
		auto restSrcFiles = files.dup;
		
		string toFullModName(string f)
		{
			return f.buildNormalizedPath.stripExtension.pathSplitter.join(".");
		}
		foreach(m; jsModDatas)
		{
			auto tmpfile = m.name.length > 0
			             ? _fixAbs(_tempDir, m.name ~ ".html")
			             : m.file.isAbsolute
			               ? _fixAbs(_tempDir, toFullModName(m.file.relativePath(rootDir)) ~ ".html")
			               : _fixAbs(_tempDir, toFullModName(m.file) ~ ".html");
			enforce(tmpfile.exists);
			auto idx = restSrcFiles.countUntil!(
				a => filenameCmp(_fixAbs(rootDir, a.src).buildNormalizedPath(), m.file.buildNormalizedPath()) == 0);
			enforce(idx != restSrcFiles.length);
			_copyFile(_fixAbs(targetDir, restSrcFiles[idx].dst), tmpfile);
			restSrcFiles = std.algorithm.remove(restSrcFiles, idx);
		}
	}
public:
	///
	string   compiler;
	///
	string[] ddocFiles;
	///
	bool     disableMarkdown;
	///
	string   targetDir;
	///
	string   rootDir;
	
	///
	void delegate(string dubPkgName, ModInfo[] modInfo, string[] args) preGenerateCallback;
	///
	void delegate(string dubPkgName, ModInfo[] modInfo, int result, string output) postGenerateCallback;
	///
	void delegate(string src, string dst) postCopyCallback;
	///
	string delegate(string[] args, string workdir, string[string] env) executeProcessor;
	///
	string delegate(string args, string workdir, string[string] env) commandProcessor;
	
	///
	void createTemporaryDir()
	{
		import std.uuid;
		_tempDir = tempDir().buildPath(".gendocwork-" ~ randomUUID.toString);
		_tempDir.mkdirRecurse();
	}
	
	///
	void removeTemporaryDir()
	{
		_tempDir.rmdirRecurse();
		_tempDir = null;
	}
	
	///
	string temporaryDir() @safe @nogc nothrow pure const @property
	{
		return _tempDir;
	}
	
	/***************************************************************************
	 * Convert from mustache file
	 * 
	 * Returns:
	 *     Converted file contents
	 */
	string convertFromMustache(DubPkgInfo[] info, string dir, string mustacheName)
	{
		return _mustacheRenderDubPackages(info, dir, mustacheName);
	}
	
	/***************************************************************************
	 * Generate file from mustache file
	 * 
	 * Returns:
	 *     File name of generated
	 */
	string generateFromMustache(DubPkgInfo[] info, string dir, string mustacheName)
	{
		auto converted = convertFromMustache(info, dir, mustacheName);
		auto filename = _tempDir.buildPath(mustacheName);
		std.file.write(filename, converted);
		return filename;
	}
	
	/***************************************************************************
	 * Generate ddoc file from mustache file
	 * 
	 * The generated ddoc file is added automatically
	 */
	void generateDdoc(DubPkgInfo[] info, string dir, string mustacheName)
		in (mustacheName.extension == ".ddoc")
	{
		ddocFiles ~= generateFromMustache(info, dir, mustacheName);
	}
	
	/***************************************************************************
	 * Generate JSON file from d source file through syntax compilation
	 */
	void generateJson(DubPkgInfo dubpkg)
	{
		import std.algorithm;
		import std.string;
		import std.process: execute;
		
		auto modules = dubpkg.entries.filter!(
			a => (a.isModule() || a.isPackageModule()) && a.moduleInfo.src.extension == ".d").array;
		auto files = modules.map!(a => a.moduleInfo).array;
		if (files.length == 0)
			return;
		
		auto argsApp = appender!(string[]);
		rootDir = dubpkg.dir;
		auto target = targetDir.buildPath(dubpkg.name.replace(":", "-") ~ ".json");
		auto srcfiles = files.map!(a => _fixAbs(rootDir, a.src).buildNormalizedPath()).array;
		argsApp ~= [compiler, "-o-", "-X", "-Xf" ~ target, "-D"];
		
		if (compiler.endsWith("ldc2", "ldc2.exe", "ldc") > 0)
		{
			auto dummyHtml = _tempDir.buildPath(target.baseName ~ ".html");
			argsApp ~= ("-Dd" ~ dummyHtml);
		}
		else
		{
			auto dummyHtml = _tempDir.buildPath(target.baseName ~ ".html");
			argsApp ~= ("-Df" ~ dummyHtml);
		}
		argsApp ~= dubpkg.options;
		argsApp ~= srcfiles;
		if (!disableMarkdown)
			argsApp ~= "-preview=markdown";
		
		auto result = execute(argsApp.data);
		enforce(result.status == 0, format!"Generate json failed: %-(%-s %) -> %s"(argsApp.data, result.output));
		enforce(target.exists, format!"Generate json failed: %s"(target));
		
		auto jsModDatas = getModuleDatas(target);
		foreach(m; modules)
		{
			auto tmpfile = _fixAbs(rootDir, m.moduleInfo.src).buildNormalizedPath();
			auto idx = jsModDatas.countUntil!(
				a => filenameCmp(a.file.buildNormalizedPath(), tmpfile) == 0);
			enforce(idx != -1);
			// タイトルの取り出し
			// splitLinesでLF,CR,CRLFの区切りの違いを無視して行単位で区切る。
			// 先頭行があれば、先頭行をstripしたものをタイトルとする
			auto commentLines = jsModDatas[idx].comment.splitLines;
			if (commentLines.length > 0)
				m.moduleInfo.title = commentLines.front.strip;
			jsModDatas = std.algorithm.remove(jsModDatas, idx);
		}
	}
	
	///
	void generate(string target, string source, string[] options)
	{
		switch (source.extension)
		{
		case ".d":
			_generateD(null, _fixAbs(targetDir, target), _fixAbs(rootDir, source), options);
			break;
		case ".dd":
			auto absTargetFile = _fixAbs(targetDir, target).stripExtension().setExtension(".html");
			_generateD(null, absTargetFile, _fixAbs(rootDir, source), options);
			break;
		default:
			_copyFile(_fixAbs(targetDir, target), _fixAbs(rootDir, source));
			break;
		}
	}
	
	/// ditto
	void generate(DubPkgInfo dubpkg, bool singleFile = false)
	{
		rootDir = dubpkg.dir;
		
		// オプションで単ファイル方式が選択されている場合はそれを最優先。これはリトライしない。
		if (singleFile)
		{
			_singleFileCompilation(dubpkg);
		}
		else
		{
			try
			{
				if (compiler.endsWith("ldc2", "ldc2.exe", "ldc") > 0)
				{
					// コンパイラがldcだった場合。失敗したら単ファイル方式でリトライ。
					_ldcCompilation(dubpkg);
				}
				else
				{
					// コンパイラがldc意外だった場合のデフォルトの挙動。失敗したら単ファイル方式でリトライ。
					_defaultCompilation(dubpkg);
				}
			}
			catch (Exception e)
			{
				// リトライ
				_singleFileCompilation(dubpkg);
			}
		}
	}
}

