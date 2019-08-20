module src.docgen;


import std.file, std.path, std.algorithm, std.range, std.array, std.exception;

import dub.internal.vibecompat.inet.path;
import dub.internal.vibecompat.data.json;
import dub.internal.utils;

import src.modmgr;



/*******************************************************************************
 * 
 */
private struct JsonModuleData
{
	///
	string name;
	///
	string file;
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
			"m|map",      &ret.map,
			"u|use",      &ret.useSections);
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
	}
	return MustashImportOptions.init;
}

/// ditto
private MustashImportOptions getMustashImportOptions(string opt)
{
	return getMustashImportOptions(parseOption(opt));
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
	
	string _mustashRenderChildren(PackageAndModuleData[] datas, string options)
	{
		if (datas.length == 0)
			return null;
		
		string ret;
		
		// オプションを解析
		auto opt = getMustashImportOptions(options);
		auto ctx = new MustacheContext;
		foreach (k, v; opt.map)
			ctx[k] = v;
		foreach (e; opt.useSections)
			ctx.useSection(e);
		
		// mustacheのデータを定義
		foreach (ref dat; datas)
		() {
			auto children = dat.children;
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
				}
				else
				{
					ctx.useSection("no_package_d");
					ctx["page_url"]         = "";
					ctx["package_name"]     = "";
					ctx["module_name"]      = "";
					ctx["full_module_name"] = "";
					ctx["source_path"]      = "";
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
			}
			ctx["children"] = (string str) => _mustashRenderChildren(children, str);
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
	
	string _mustashRenderDubPackages(DubPkgInfo[] projects, string dir, string name)
	{
		if (projects.length == 0)
			return null;
		
		auto ctx = new MustacheContext;
		
		foreach (p; projects)
		() {
			auto children  = p.children;
			auto sc = ctx.addSubContext("dub_pkg_info");
			sc["name"]     = p.name;
			sc["version"]  = p.packageVersion;
			sc["dir"]      = p.dir;
			sc["children"] = (string str) => _mustashRenderChildren(children, str);
		} ();
		
		_mustache.path = dir;
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
			a => (a.isModule() || a.isPackageModule) && a.moduleInfo.src.extension.startsWith(".d"));
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
		foreach(m; jsModDatas)
		{
			auto tmpfile = _fixAbs(_tempDir, m.name ~ ".html");
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
	void createTemporaryDir()
	{
		import std.uuid;
		if (targetDir.length > 0)
		{
			_tempDir = targetDir.buildPath(".gendocwork-" ~ randomUUID.toString);
		}
		else
		{
			_tempDir = tempDir().buildPath(".gendocwork-" ~ randomUUID.toString);
		}
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
	
	///
	void generateDdoc(DubPkgInfo[] info, string dir, string mustacheName)
	{
		auto ddocContent = _mustashRenderDubPackages(info, dir, mustacheName);
		auto filename = _tempDir.buildPath(mustacheName);
		std.file.write(filename, ddocContent);
		ddocFiles ~= filename;
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

