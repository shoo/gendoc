/*******************************************************************************
 * Manage configs and commands
 * 
 * Mediation of gendoc configuration file and command line arguments.
 * Also get dub package informations.
 */
module gendoc.config;

import dub.dub, dub.project, dub.package_, dub.generators.generator, dub.compilers.compiler;
import dub.internal.vibecompat.core.log, dub.internal.vibecompat.data.json, dub.internal.vibecompat.inet.path;

/*******************************************************************************
 * 
 */
struct PackageConfig
{
	///
	string   path;
	///
	string   name;
	///
	string[] files;
	///
	string[] options;
	///
	string   packageVersion;
	///
	PackageConfig[] subPackages;
	
	/***************************************************************************
	 * 
	 */
	void loadPackage(
		Dub dub,
		Package pkg,
		string archType,
		string buildType,
		string configName,
		string compiler)
	{
		import std.algorithm, std.array, std.file, std.path;
		Package bkupPkg = dub.project.rootPackage;
		if (pkg)
			dub.loadPackage(pkg);
		scope (exit) if (pkg)
			dub.loadPackage(bkupPkg);
		if (!dub.project.hasAllDependencies)
			dub.upgrade(UpgradeOptions.select);
		
		dub.project.validate();
		
		auto compilerData = getCompiler(compiler);
		BuildSettings buildSettings;
		auto buildPlatform = compilerData.determinePlatform(buildSettings, compiler, archType);
		
		GeneratorSettings settings;
		if (pkg)
			settings.config = pkg.getDefaultConfiguration(buildPlatform);
		else
			settings.config = dub.project.getDefaultConfiguration(buildPlatform);
		settings.force     = true;
		settings.buildType = buildType;
		settings.compiler  = compilerData;
		settings.platform  = buildPlatform;
		name    = pkg ? pkg.name : dub.project.rootPackage.name;
		if (dub.project.rootPackage.getBuildSettings(settings.config).targetType != TargetType.none)
		{
			auto lists = dub.project.listBuildSettings(settings,
				["dflags", "versions", "debug-versions",
				"import-paths", "string-import-paths", "options",
				"source-files"],
				ListBuildSettingsFormat.commandLineNul).map!(a => a.split("\0")).array;
			// -oq, -od が付与されているゴミが紛れ込む場合がある。dubのバグか？回避する。
			auto importDirs = lists[3].filter!(a => a.startsWith("-I") && a[2..$].exists);
			path    = importDirs.empty
				? pkg ? pkg.path.toNativeString() : dub.project.rootPackage.path.toNativeString()
				: importDirs.front[2..$];
			options = lists[0].reduce!((a, b) => a.canFind(b) ? a : a ~ [b])(lists[1..6].join);
			files   = lists[6].filter!(a => a.exists && canFind([".d", ".dd", ".di"], a.extension)).array;
			packageVersion = pkg
				? pkg.version_.toString()
				: dub.project.rootPackage.version_.toString();
		}
		foreach (spkg; dub.project.rootPackage.subPackages)
		{
			PackageConfig pkgcfg;
			if (spkg.recipe.name.length > 0)
			{
				auto basepkg = dub.packageManager.getPackage(name, packageVersion);
				auto subpkg = dub.packageManager.getSubPackage(basepkg, spkg.recipe.name, false);
				pkgcfg.loadPackage(dub, subpkg,
					archType, buildType, configName, compiler);
			}
			else
			{
				auto tmppkgpath = dub.rootPath ~ NativePath(spkg.path);
				auto subpkg = dub.packageManager.getOrLoadPackage(tmppkgpath, NativePath.init, true);
				pkgcfg.loadPackage(dub, subpkg,
					archType, buildType, configName, compiler);
			}
			subPackages ~= pkgcfg;
		}
	}
	
	/// ditto
	void loadPackage(
		string dir,
		string archType,
		string buildType,
		string configName,
		ref string compiler)
	{
		import std.algorithm, std.string, std.array, std.path;
		setLogLevel(LogLevel.error);
		auto absDir = dir.absolutePath.buildNormalizedPath;
		auto dub = new Dub(absDir);
		if (compiler.length == 0)
			compiler = dub.defaultCompiler;
		if (archType.length == 0)
			archType = dub.defaultArchitecture;
		dub.loadPackage();
		loadPackage(dub, null,
			archType,
			buildType,
			configName,
			compiler);
	}
	
	@system unittest
	{
		import std.file;
		if ("testcases/case002".exists)
		{
			PackageConfig cfg;
			string compiler;
			cfg.loadPackage("testcases/case002", "x86_64", "debug", null, compiler);
		}
	}
}

private string _getHomeDirectory()
{
	import std.file, std.path;
	version (Posix)
	{
		return expandTilde("~");
	}
	else version (Windows)
	{
		import core.runtime;
		import core.sys.windows.windows, core.sys.windows.shlobj;
		wchar[MAX_PATH+1] dst;
		auto mod = LoadLibraryW("Shell32.dll");
		if (!mod)
			return getcwd;
		
		alias SHGetFolderPathProc = extern (Windows) HRESULT function(HWND, int, HANDLE, DWORD, LPWSTR);
		auto getFolderPath = cast(SHGetFolderPathProc)GetProcAddress(cast(HMODULE)mod, "SHGetFolderPathW");
		if (getFolderPath is null)
			return getcwd;
		if (getFolderPath(null, CSIDL_PROFILE, null, 0, dst.ptr) == S_OK)
		{
			import std.algorithm, std.conv;
			auto idx = dst.ptr.lstrlen();
			if (idx < dst.length)
				return dst[0..idx].to!string();
		}
		return getcwd;
	}
}

/*******************************************************************************
 * Gendoc's configuration data structure
 */
struct GendocConfig
{
	///
	@optional
	string[] ddocs;
	///
	@optional
	string[] sourceDocs;
	///
	@optional
	string   target;
	///
	@optional
	string[] excludePaths;
	///
	@optional
	string[] excludePatterns = [
		"(?:(?<=/)|^)\\.[^/.]+$",
		"(?:(?<=[^/]+/)|^)_[^/]+$",
		"(?:(?<=[^/]+/)|^)internal(?:\\.d)?$"];
	///
	@optional
	string[] excludePackages;
	/// {"keyName": ["dub_package_name_regex_pattern1", "dub_package_name_regex_pattern2"]}
	@optional
	string[][string] combinedDubPackagePatterns;
	///
	@optional
	string[] excludePackagePatterns = [
		"(?:(?<=[^:]+/)|^)_[^/]+$",
		":docs?$"];
	
	///
	@optional
	bool enableGenerateJSON = true;
	
	///
	void fixPath(string dirPath)
	{
		import std.algorithm, std.path, std.file, std.process;
		import gendoc.misc;
		ddocs      = ddocs.remove!(a => a.length == 0);
		sourceDocs = sourceDocs.remove!(a => a.length == 0);
		auto map = [
			"GENDOC_DIR":  thisExePath.dirName.absolutePath,
			"GENDOC_SD_DIR": thisExePath.dirName.buildPath("source_docs").exists
				? thisExePath.dirName.buildPath("source_docs")
				: thisExePath.dirName.buildPath("../etc/.gendoc/docs").exists
					? thisExePath.dirName.buildNormalizedPath("../etc/.gendoc/docs")
					: thisExePath.dirName.absolutePath,
			"GENDOC_DD_DIR": thisExePath.dirName.buildPath("ddoc").exists
				? thisExePath.dirName.buildPath("source_docs")
				: thisExePath.dirName.buildPath("../etc/.gendoc/ddoc").exists
					? thisExePath.dirName.buildNormalizedPath("../etc/.gendoc/ddoc")
					: thisExePath.dirName.absolutePath,
			"PROJECT_DIR": dirPath.absolutePath,
			"WORK_DIR":    getcwd.absolutePath];
		bool mapFunc(ref string arg, MacroType type)
		{
			if (auto val = map.get(arg, null))
			{
				arg = val;
				return true;
			}
			if (auto val = environment.get(arg, null))
			{
				arg = val;
				return true;
			}
			return false;
		}
		foreach (ref d; ddocs)
			d = d.expandMacro(&mapFunc);
		foreach (ref d; sourceDocs)
			d = d.expandMacro(&mapFunc);
		target = target.expandMacro(&mapFunc);
		
		foreach (ref d; ddocs)
		{
			if (!d.isAbsolute)
				d = buildPath(dirPath, d);
		}
		foreach (ref d; sourceDocs)
		{
			if (!d.isAbsolute)
				d = buildPath(dirPath, d);
		}
		if (target.length > 0 && !target.isAbsolute)
			target = buildPath(dirPath, target);
	}
	
	///
	private bool _loadConfigFromFile(string p)
	{
		debug import std.stdio;
		import dub.internal.utils;
		import std.file, std.path;
		if (!p.exists || !p.isFile)
			return false;
		debug writeln("Configuration loaded from: " ~ p);
		this.deserializeJson!GendocConfig(jsonFromFile(NativePath(p)));
		fixPath(p.dirName);
		return true;
	}
	
	///
	private bool _isExistsDir(string p)
	{
		import std.file, std.path;
		return p.exists && p.isDir;
	}
	
	///
	private bool _loadConfigFromDir(string p, bool enableRawDocs)
	{
		debug import std.stdio;
		import std.file, std.path;
		auto ddocDir = p.buildPath("ddoc");
		if (!_isExistsDir(ddocDir))
			return false;
		string sourceDocsDir;
		if (enableRawDocs)
		{
			sourceDocsDir = p.buildPath("docs");
			if (_isExistsDir(sourceDocsDir))
			{
				ddocs      = [ddocDir];
				sourceDocs = [sourceDocsDir];
				debug writeln("Configuration loaded from: " ~ p);
				return true;
			}
		}
		sourceDocsDir = p.buildPath("source_docs");
		if (_isExistsDir(sourceDocsDir))
		{
			ddocs      = [ddocDir];
			sourceDocs = [sourceDocsDir];
			debug writeln("Configuration loaded from: " ~ p);
			return true;
		}
		return false;
	}
	
	/***************************************************************************
	 * Load configuration from specifiered path
	 * 
	 */
	bool loadConfig(string path)
	{
		import std.file, std.path;
		// 1.1. (--gendocConfig=<jsonfile>)
		if (_loadConfigFromFile(path))
			return true;
		
		// 1.2. (--gendocConfig=<directory>)/settings.json
		if (_loadConfigFromFile(path.buildPath("settings.json")))
			return true;
		
		// 1.3. (--gendocConfig=<directory>)/gendoc.json
		if (_loadConfigFromFile(path.buildPath("gendoc.json")))
			return true;
		
		// 1.4. (--gendocConfig=<directory>)/ddoc and (--gendocConfig=<directory>)/docs
		// 1.5. (--gendocConfig=<directory>)/ddoc and (--gendocConfig=<directory>)/source_docs
		if (_loadConfigFromDir(path, true))
			return true;
		
		return false;
	}
	
	/// ditto
	bool loadDefaultConfig(string root)
	{
		import std.file, std.path;
		// 2.1. ./.gendoc.json
		if (_loadConfigFromFile(root.buildPath(".gendoc.json")))
			return true;
		
		// 2.2. ./gendoc.json
		if (_loadConfigFromFile(root.buildPath("gendoc.json")))
			return true;
		
		// 2.3. ./.gendoc/settings.json
		if (_loadConfigFromFile(root.buildPath(".gendoc/settings.json")))
			return true;
		
		// 2.4. ./.gendoc/gendoc.json
		if (_loadConfigFromFile(root.buildPath(".gendoc/gendoc.json")))
			return true;
		
		// 2.5.  ./.gendoc/ddoc and ./.gendoc/docs
		// 2.6. ./.gendoc/ddoc and ./.gendoc/source_docs
		if (_loadConfigFromDir(root.buildPath(".gendoc"), true))
			return true;
		
		// 2.7. ./ddoc and ./source_docs
		// (docs may be a target)
		if (_loadConfigFromDir(root, false))
			return true;
		
		auto homeDir = _getHomeDirectory();
		
		
		// 3.1. $(HOME)/.gendoc.json
		if (_loadConfigFromFile(homeDir.buildPath(".gendoc.json")))
			return true;
		
		// 3.2. $(HOME)/gendoc.json
		if (_loadConfigFromFile(homeDir.buildPath("gendoc.json")))
			return true;
		
		// 3.3. $(HOME)/.gendoc/settings.json
		if (_loadConfigFromFile(homeDir.buildPath(".gendoc/settings.json")))
			return true;
		
		// 3.4. $(HOME)/.gendoc/gendoc.json
		if (_loadConfigFromFile(homeDir.buildPath(".gendoc/gendoc.json")))
			return true;
		
		// 3.5. $(HOME)/.gendoc/ddoc and $(HOME)/.gendoc/docs
		// 3.6. $(HOME)/.gendoc/ddoc and $(HOME)/.gendoc/sourcec_docs
		if (_loadConfigFromDir(homeDir.buildPath(".gendoc"), true))
			return true;
		
		auto gendocExeDir = thisExePath.dirName;
		
		// 4.1. (gendocExeDir)/gendoc.json
		if (_loadConfigFromFile(gendocExeDir.buildPath(".gendoc.json")))
			return true;
		
		// 4.2. (gendocExeDir)/gendoc.json
		if (_loadConfigFromFile(gendocExeDir.buildPath("gendoc.json")))
			return true;
		
		// 4.3. (gendocExeDir)/.gendoc/settings.json
		if (_loadConfigFromFile(gendocExeDir.buildPath(".gendoc/settings.json")))
			return true;
		
		// 4.4. (gendocExeDir)/.gendoc/gendoc.json
		if (_loadConfigFromFile(gendocExeDir.buildPath(".gendoc/gendoc.json")))
			return true;
		
		// 4.5. (gendocExeDir)/.gendoc/ddoc and (gendocExeDir)/.gendoc/docs
		// 4.6. (gendocExeDir)/.gendoc/ddoc and (gendocExeDir)/.gendoc/source_docs
		if (_loadConfigFromDir(gendocExeDir.buildPath(".gendoc"), true))
			return true;
		
		// 4.7. (gendocExeDir)/ddoc and (gendocExeDir)/source_docs
		// (docs may be a gendoc's document target)
		if (_loadConfigFromDir(gendocExeDir, false))
			return true;
		
		auto gendocEtcDir = gendocExeDir.dirName.buildPath("etc");
		
		// 5.1. (gendocEtcDir)/gendoc.json
		if (_loadConfigFromFile(gendocEtcDir.buildPath(".gendoc.json")))
			return true;
		
		// 5.2. (gendocEtcDir)/gendoc.json
		if (_loadConfigFromFile(gendocEtcDir.buildPath("gendoc.json")))
			return true;
		
		// 5.3. (gendocEtcDir)/.gendoc/settings.json
		if (_loadConfigFromFile(gendocEtcDir.buildPath(".gendoc/settings.json")))
			return true;
		
		// 5.4. (gendocEtcDir)/.gendoc/gendoc.json
		if (_loadConfigFromFile(gendocEtcDir.buildPath(".gendoc/gendoc.json")))
			return true;
		
		// 5.5. (gendocEtcDir)/.gendoc/ddoc and (gendocEtcDir)/.gendoc/docs
		// 5.6. (gendocEtcDir)/.gendoc/ddoc and (gendocEtcDir)/.gendoc/source_docs
		if (_loadConfigFromDir(gendocEtcDir.buildPath(".gendoc"), true))
			return true;
		
		return false;
	}
	
	///
	void setup(string root, string configFile, string[] optDdocs, string[] optSourceDocs, string optTarget)
	{
		import std.algorithm, std.array, std.path, std.file, std.exception;
		if (configFile.length > 0)
		{
			// 1.コマンドライン引数によってファイルの指定があった場合
			auto filepath = root.buildPath(configFile);
			// コマンドラインの指定があるのに構成が見つからない場合はエラー
			loadConfig(filepath).enforce("Cannot load configuration: " ~ filepath);
		}
		else
		{
			// 2.コマンドライン引数がない場合はデフォルトから読み込み
			loadDefaultConfig(root);
		}
		
		if (optDdocs.length > 0)
			ddocs = optDdocs.map!(
				a => a.isAbsolute ? a : root.buildPath(a)).array;
		if (optSourceDocs.length > 0)
			sourceDocs = optSourceDocs.map!(
				a => a.isAbsolute ? a : root.buildPath(a)).array;
		if (optTarget.length > 0)
			target = optTarget.isAbsolute ? optTarget : root.buildPath(optTarget);
		
		// default settings
		if (ddocs.length == 0 && root.buildPath("ddoc").exists)
			ddocs = [root.buildPath("ddoc")];
		if (ddocs.length == 0 && thisExePath.dirName.buildPath("ddoc").exists)
			ddocs = [thisExePath.dirName.buildPath("ddoc")];
		if (sourceDocs.length == 0 && root.buildPath("source_docs").exists)
			sourceDocs = [root.buildPath("source_docs")];
		if (sourceDocs.length == 0 && thisExePath.dirName.buildPath("source_docs").exists)
			sourceDocs = [thisExePath.dirName.buildPath("source_docs")];
		if (target.length == 0)
			target = root.buildPath("docs");
		
		// check
		foreach (ref d; ddocs)
		{
			enforce(d.exists && d.isDir, "ddoc directory is missing: " ~ d);
			enforce(filenameCmp(target.absolutePath.buildNormalizedPath, d.absolutePath.buildNormalizedPath) != 0,
				"ddoc dir cannot be same to target: " ~ target);
		}
		foreach (ref d; sourceDocs)
		{
			enforce(d.exists && d.isDir, "source_docs directory is missing: " ~ d);
			enforce(filenameCmp(target.absolutePath.buildNormalizedPath, d.absolutePath.buildNormalizedPath) != 0,
				"source_docs dir cannot be same to target: " ~ target);
		}
	}
}



/*******************************************************************************
 * 
 */
struct Config
{
	import std.getopt;
	///
	string compiler;
	///
	PackageConfig packageData;
	///
	GendocConfig gendocData;
	///
	bool singleFile;
	///
	bool quiet;
	///
	bool varbose;
	/***************************************************************************
	 * 
	 */
	GetoptResult setup(string[] commandlineArgs)
	{
		import std.file, std.path;
		
		string configFile;
		Config tmp;
		bool saveConfig;
		string archType;
		string buildType = "debug";
		string configName;
		string root = ".";
		
		string   gendocConfig;
		string[] ddocs;
		string[] sourceDocs;
		string   target;
		
		auto ret = commandlineArgs.getopt(
			config.caseSensitive,
			config.bundling,
			"a|arch",           "Archtecture of dub project.",                            &archType,
			"b|build",          "Build type of dub project.",                             &buildType,
			"c|config",         "Configuration of dub project.",                          &configName,
			"compiler",         "Specifies the compiler binary to use (can be a path).",  &compiler,
			"gendocDdocs",      "Ddoc sources of document files.",                        &ddocs,
			"gendocSourceDocs", "Source of document files.",                              &sourceDocs,
			"gendocTarget",     "Target directory of generated documents.",               &target,
			"gendocConfig",     "Configuration file of gendoc.",                          &configFile,
			"root",             "Path to operate in instead of the current working dir.", &root,
			"singleFile",       "Single file generation mode.",                           &singleFile,
			"v|varbose",        "Display varbose messages.",                              &varbose,
			"q|quiet",          "Non-display messages.",                                  &quiet
		);
		
		packageData.loadPackage(root, archType, buildType, configName, compiler);
		gendocData.setup(root, configFile, ddocs, sourceDocs, target);
		
		return ret;
	}
}
