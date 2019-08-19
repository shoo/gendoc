module src.docgen;


import std.file, std.path, std.algorithm, std.range, std.array, std.exception;

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
	import dub.internal.vibecompat.data.json;
	import std.file, std.path, std.exception;
	if (jsonfile.length == 0 || !jsonfile.exists || !jsonfile.isFile)
		return null;
	auto jsonContent = std.file.readText(jsonfile);
	if (jsonContent.length > 0)
	{
		auto json = parseJson(jsonContent);
		return deserializeJson!(JsonModuleData[])(json);
	}
	return null;
}


/***************************************************************
 * 
 */
struct DocumentGenerator
{
	import std.file, std.path, std.algorithm;
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
	
private:
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
		auto tempSrcDir = targetDir.buildPath(".gendocwork_html");
		scope (exit)
			std.file.rmdirRecurse(tempSrcDir);
		tempSrcDir.mkdirRecurse();
		auto tmpSrcs = _copyTempDsrcs(tempSrcDir, files);
		
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
		auto tempDstDir = targetDir.buildPath(".gendocwork_html");
		auto tempDstJson = tempDstDir.buildPath(".gendocwork.json");
		scope (exit)
			std.file.rmdirRecurse(tempDstDir);
		tempDstDir.mkdirRecurse();
		
		auto argsApp = appender!(string[]);
		auto srcfiles = files.map!(a => _fixAbs(rootDir, a.src).buildNormalizedPath()).array;
		argsApp ~= [compiler, "-o-", "-oq"];
		argsApp ~= ["-Dd" ~ tempDstDir, "-X", "-Xf" ~ tempDstJson];
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
			auto tmpfile = _fixAbs(tempDstDir, m.name ~ ".html");
			auto idx = restSrcFiles.countUntil!(
				a => filenameCmp(_fixAbs(rootDir, a.src).buildNormalizedPath(), m.file.buildNormalizedPath()) == 0);
			enforce(idx != restSrcFiles.length);
			_copyFile(_fixAbs(targetDir, restSrcFiles[idx].dst), tmpfile);
			restSrcFiles = std.algorithm.remove(restSrcFiles, idx);
		}
	}
}

