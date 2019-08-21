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
		import std;
		Package bkupPkg = dub.project.rootPackage;
		if (pkg)
			dub.loadPackage(pkg);
		scope (exit) if (pkg)
			dub.loadPackage(bkupPkg);
		dub.project.reinit();
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
			path    = lists[3].filter!(a => a.startsWith("-I") && a[2..$].exists).front[2..$];
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
				auto subpkg = dub.packageManager.getSubPackage(dub.project.rootPackage, spkg.recipe.name, false);
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
		auto tmppkg = dub.packageManager.getOrLoadPackage(NativePath(absDir), NativePath.init, true);
		dub.loadPackage();
		loadPackage(dub, null,
			archType,
			buildType,
			configName,
			compiler);
	}

}



/*******************************************************************************
 * 
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
	///
	@optional
	string[] excludePackagePatterns = [
		"(?:(?<=[^:]+/)|^)_[^/]+$",
		":docs?$"];
	
	///
	void fixPath(string dirPath)
	{
		import std.path;
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
		if (!target.isAbsolute)
			target = buildPath(dirPath, target);
	}
	
	///
	bool loadConfig(string path)
	{
		import std.file, std.path, std.exception;
		string jsonContent;
		static immutable settingFileDefaultName = "gendoc.json";
		static immutable settingDirDefaultName  = ".gendoc";
		static immutable settingFileInDirDefaultName  = "settings.json";
		
		bool _loadFile(string p)
		{
			import dub.internal.utils;
			if (!p.exists || !p.isFile)
				return false;
			this.deserializeJson!GendocConfig(jsonFromFile(NativePath(p)));
			return true;
		}
		
		bool _isExistsDir(string p)
		{
			return p.exists && p.isDir;
		}
		
		bool _loadDir(string p, bool enableRawDocs)
		{
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
					return true;
				}
			}
			sourceDocsDir = p.buildPath("source_docs");
			if (_isExistsDir(sourceDocsDir))
			{
				ddocs      = [ddocDir];
				sourceDocs = [sourceDocsDir];
				return true;
			}
			return false;
		}
		bool _fixPath(string p)
		{
			fixPath(p);
			return true;
		}
		
		if (path.length == 0)
		{
			// パス無しの場合、デフォルトのフォルダを検索
			// 1.1. "gendoc.json"読み込みトライ
			if (_loadFile(settingFileDefaultName))
				return true;
			// 1.2. ディレクトリからの読み込みトライ
			if (settingDirDefaultName.exists && settingDirDefaultName.isDir)
			{
				// 1.2.1. "settings.json" or "gendoc.json" 読み込みトライ
				if (_loadFile(settingDirDefaultName.buildPath("settings.json"))
				 || _loadFile(settingDirDefaultName.buildPath("gendoc.json")))
					return _fixPath(settingDirDefaultName);
				// 1.2.2. "ddoc", "docs" or "source_docs" 読み込みトライ
				if (_loadDir(settingDirDefaultName, true))
					return true;
			}
		}
		else
		{
			// 2.パス有りの場合
			// 2.1. ファイル読み込みトライ
			if (_loadFile(path))
				return _fixPath(path.dirName);
			// 2.2. フォルダ以下の "settings.json" or "gendoc.json" 読み込みトライ
			if (_loadFile(path.buildPath("settings.json"))
			 || _loadFile(path.buildPath("gendoc.json")))
				return _fixPath(path);
			// 2.3. "ddoc", "source_docs" 読み込みトライ
			if (_isExistsDir(path) && _loadDir(path, false))
				return true;
		}
		return false;
	}
	
	///
	void setup(string root, string configFile, string[] optDdocs, string[] optSourceDocs, string optTarget)
	{
		import std.algorithm, std.array, std.path, std.file, std.exception;
		if (configFile.length > 0)
		{
			// ファイルの指定があった場合
			loadConfig(root.buildPath(configFile)).enforce("Cannot load configuration: " ~ root.buildPath(configFile));
		}
		else
		{
			// デフォルトから読み込み
			if (!loadConfig(null))
				loadConfig(thisExePath.dirName);
		}
		
		if (optDdocs.length > 0)
			ddocs = optDdocs.map!(
				a => a.isAbsolute ? a : root.buildPath(a)).array;
		if (optSourceDocs.length > 0)
			sourceDocs = optSourceDocs.map!(
				a => a.isAbsolute ? a : root.buildPath(a)).array;
		if (optTarget.length > 0)
			optTarget = optTarget.isAbsolute ? optTarget : root.buildPath(optTarget);
		
		// default settings
		if (ddocs.length == 0 && root.buildPath("ddoc").exists)
			ddocs = [root.buildPath("ddoc")];
		if (sourceDocs.length == 0 && root.buildPath("source_docs").exists)
			sourceDocs = [root.buildPath("source_docs")];
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
