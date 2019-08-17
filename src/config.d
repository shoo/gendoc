module src.config;

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
		
		auto lists = dub.project.listBuildSettings(settings,
			["dflags", "versions", "debug-versions",
			"import-paths", "string-import-paths", "options",
			"source-files"],
			ListBuildSettingsFormat.commandLineNul).map!(a => a.split("\0")).array;
		name    = pkg ? pkg.name : dub.project.rootPackage.name;
		path    = lists[3][0][2..$];
		options = lists[0..6].join;
		files   = lists[6];
		packageVersion = pkg
			? pkg.version_.toString()
			: dub.project.rootPackage.version_.toString();
		
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
		string compiler)
	{
		import std.algorithm, std.string, std.array, std.path;
		setLogLevel(LogLevel.error);
		auto absDir = dir.absolutePath.buildNormalizedPath;
		auto dub = new Dub(absDir);
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
	string[] ddocs;
	///
	string[] sourceDocs;
	///
	string   target;
	///
	string[] excludePaths;
	///
	string[] excludePatterns = [
		"(?:(?<=/)|^)\\.[^/]+$",
		"(?:(?<=[^/]+/)|^)_[^/]+$",
		"(?:(?<=[^/]+/)|^)internal(?:\\.d)?$"];
	///
	string[] excludePackages;
	///
	string[] excludePackagePatterns = [
		"(?:(?<=[^:]+/)|^)_[^/]+$",
		":docs?$"];
	
	///
	void loadConfig(string path)
	{
		import std.file, std.path, std.exception;
		string jsonContent;
		if (path.length > 0
			&& path.exists)
		{
			if (path.isFile)
			{
				jsonContent = std.file.readText(path);
			}
			else
			{
				auto filepath = path.buildPath("gendoc.json");
				enforce(filepath.exists && filepath.isFile, "Cannot find gendoc.json in directory: " ~ path);
				jsonContent = std.file.readText(filepath);
			}
		}
		else if (path.length == 0)
		{
			auto filepath = "gendoc.json";
			if (filepath.exists && filepath.isFile)
				jsonContent = std.file.readText(filepath);
		}
		else
		{
			// 何もしない
		}
		if (jsonContent.length > 0)
		{
			auto json = parseJson(jsonContent);
			this = deserializeJson!GendocConfig(json);
		}
	}
	
	///
	void setup(string root, string configFile, string[] optDdocs, string[] optSourceDocs, string optTarget)
	{
		import std.algorithm, std.array, std.path, std.file;
		loadConfig(configFile.length > 0 ? root.buildPath(configFile) : null);
		
		if (optDdocs.length > 0)
			ddocs ~= optDdocs.map!(
				a => a.isAbsolute ? a : root.buildPath(a)).array;
		if (optSourceDocs.length > 0)
			sourceDocs ~= optSourceDocs.map!(
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
	}
}



/*******************************************************************************
 * 
 */
struct Config
{
	import std.getopt;
	///
	string compiler = "dmd";
	///
	PackageConfig packageData;
	///
	GendocConfig gendocData;
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
		string archType = "x86_64";
		string buildType = "debug";
		string configName;
		string root     = ".";
		
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
			"v|varbose",        "Display varbose messages.",                              &varbose,
			"q|quiet",          "Non-display messages.",                                  &quiet
		);
		
		packageData.loadPackage(root, archType, buildType, configName, compiler);
		gendocData.setup(root, configFile, ddocs, sourceDocs, target);
		
		return ret;
	}
}
