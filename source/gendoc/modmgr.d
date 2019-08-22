module gendoc.modmgr;

import std.algorithm;
import std.regex;
import std.stdio;



/***************************************************************
 * Source file (D's module) information
 */
struct ModInfo
{
	/// Source file with relative path from source root path, or absolute path as external files.
	string src;
	/// Distination file with relative path from target.
	string dst;
	/// Dub package name
	string dubPkgName;
	/// (D's) Package name (eg.  `hoge/fuga/piyo.d` -> `hoge.fuga` )
	string pkgName;
	/// Module name ( `hoge/fuga/piyo.d` -> `piyo` )
	string modName;
	
	/// Concatinated package and module name (eg. `hoge/fuga/piyo.d` -> `hoge.fuga.piyo` )
	string fullModuleName() @safe const @property
	{
		return pkgName.length > 0 ? pkgName ~ "." ~ modName : modName;
	}
	
	/// Constructor
	this(string srcFile) @safe
	{
		src = srcFile;
	}
}

/***************************************************************
 * Source file (D's package) information
 */
struct PkgInfo
{
	/// name of package (eg. `hoge/fuga/piyo.d` -> `fuga` )
	string    name;
	/// dub package name
	string    dubPkgName;
	/// full package name (eg. `hoge/fuga/piyo.d` -> `hoge.fuga` )
	string    pkgName;
	/// package.d module information if exists.
	ModInfo   packageD;
	/// module informations of package children
	ModInfo[] modules;
	/// package informations of package children
	PkgInfo[] packages;
	/// true if package.d module exists
	bool hasPackageD() @safe @nogc nothrow const @property
	{
		return packageD.src.length > 0;
	}
}

/***************************************************************
 * 
 */
struct PackageAndModuleData
{
private:
	///
	bool _isPackage;
	union
	{
		///
		PkgInfo* _pkg;
		///
		ModInfo*  _mod;
	}
public:
	///
	this(return ref ModInfo modInfo) @safe
	{
		_isPackage = false;
		() @trusted { _mod = &modInfo; }();
	}
	
	///
	this(return ref PkgInfo d) @safe
	{
		_isPackage = true;
		() @trusted { _pkg = &d; }();
	}
	
	///
	string name() @safe const @property
	{
		import std.path: baseName, stripExtension;
		return _isPackage
			? () @trusted {return _pkg.name; }()
			: () @trusted {return _mod.src.baseName.stripExtension; }();
	}
	
	///
	bool isPackage() @safe const @property
	{
		return _isPackage;
	}
	
	///
	bool isModule() @safe const @property
	{
		return !_isPackage;
	}
	
	///
	bool isPackageModule() @safe const @property
	{
		return _isPackage && () @trusted { return _pkg; }().hasPackageD;
	}
	
	///
	ref inout(PkgInfo) packageInfo() @safe inout @property
	{
		assert(isPackage);
		return *(() inout @trusted { return _pkg; } ());
	}
	
	///
	ref inout(ModInfo) moduleInfo() @safe inout @property
	{
		assert(isModule() || isPackageModule());
		if (isModule)
			return *(() inout @trusted { return _mod; } ());
		return (() inout @trusted { return _pkg; }()).packageD;
	}
	
	///
	inout(PackageAndModuleData)[] children() @trusted inout @property
	{
		import std.range, std.algorithm, std.string;
		if (!isPackage)
			return null;
		
		PackageAndModuleData[] datas;
		foreach (ref pkg; () @trusted { return cast(PkgInfo[])packageInfo.packages; }())
			datas ~= PackageAndModuleData(pkg);
		foreach (ref mod; () @trusted { return cast(ModInfo[])packageInfo.modules; }())
			datas ~= PackageAndModuleData(mod);
		return cast(inout)datas;
	}
}



/*******************************************************************************
 * 
 */
struct PackageAndModuleRange
{
private:
	PackageAndModuleData[][] _datas;
	
public:
	/***************************************************************************
	 * 
	 */
	this(PackageAndModuleData[] pkgs)
	{
		_datas = [pkgs];
	}
	/***************************************************************************
	 * 
	 */
	this(PkgInfo[] pkgs)
	{
		PackageAndModuleData[] tmp;
		import std.algorithm;
		foreach (ref pkg; pkgs)
			tmp ~= PackageAndModuleData(pkg);
		tmp.moduleSort();
		_datas = [tmp];
	}
	
	///
	inout(PackageAndModuleData) front() inout @property
	{
		return _datas[$-1][0];
	}
	///
	void popFront()
	{
		auto chdatas = _datas[$-1][0].children;
		
		if (_datas[$-1].length == 1)
		{
			_datas = _datas[0..$-1];
		}
		else
		{
			_datas[$-1] = _datas[$-1][1..$];
		}
		
		if (chdatas.length > 0)
		{
			chdatas.moduleSort();
			_datas ~= [chdatas];
		}
	}
	///
	bool empty() const @property
	{
		return _datas.length == 0;
	}
}



/*******************************************************************************
 * 
 */
struct DubPkgInfo
{
	///
	string   name;
	///
	string   packageVersion;
	///
	PkgInfo  root;
	///
	string   dir;
	///
	string[] options;
	
	///
	this(string dubPkgName, string ver, string rootDir, string[] opts) @safe
	{
		name           = dubPkgName;
		packageVersion = ver;
		root           = PkgInfo(dubPkgName);
		dir            = rootDir;
		options        = opts;
	}
	
	///
	inout(PackageAndModuleRange) entries() inout @trusted
	{
		return cast(inout)PackageAndModuleRange(cast(PkgInfo[])[root]);
	}
	///
	inout(PackageAndModuleData)[] children() inout @trusted
	{
		return cast(inout)PackageAndModuleData(*cast(PkgInfo*)&root).children;
	}
}

/// 
void moduleSort(ref PackageAndModuleData[] datas) @safe
{
	import std.algorithm, std.string;
	std.algorithm.sort!((a, b) => icmp(a.name, b.name) < 0)(datas);
}

/***************************************************************
 * 
 */
struct ModuleManager
{
private:
	string[]         _excludePaths;
	Regex!char[]     _excludePatterns;
	string[]         _excludePackages;
	Regex!char[]     _excludePackagePatterns;
	string           _target;
	DubPkgInfo[] _rootPackages;
	
	void addRootPackage(string pkgName, string pkgVer, string root, in string[] options) @safe
		in (!_rootPackages.canFind!(a => a.name == pkgName))
	{
		_rootPackages ~= DubPkgInfo(pkgName, pkgVer, root, options.dup);
	}
	
	void addModule(string pkgName, string path, ModInfo modInfo) @safe
		in (_rootPackages.canFind!(a => a.name == pkgName))
	{
		import std.path, std.array;
		auto isPkgMod = modInfo.src.baseName.stripExtension() == "package";
		
		static PkgInfo* getBranch(PkgInfo[]* tree, string name)
			in (tree !is null)
			out (r; r !is null)
		{
			foreach (ref branch; *tree)
			{
				if (branch.name == name)
					return () @trusted { return &branch; } ();
			}
			*tree ~= PkgInfo(name);
			return &(*tree)[$-1];
		}
		
		PkgInfo*   pkgSelected = () @trusted { return &getPackageInfo(pkgName); } ();
		PkgInfo[]* pkgTree     = &pkgSelected.packages;
		
		if (path.isAbsolute || path.startsWith(".."))
		{
			pkgSelected = getBranch(pkgTree, "(extra)");
			pkgSelected.dubPkgName = pkgName;
			pkgSelected.pkgName    = "(extra)";
		}
		else
		{
			auto pathSplitted = path.pathSplitter.array;
			foreach (i, p; pathSplitted)
			{
				pkgSelected            = getBranch(pkgTree, p);
				pkgTree                = &pkgSelected.packages;
				pkgSelected.dubPkgName = pkgName;
				pkgSelected.pkgName    = pathSplitted[0..i].join(".");
			}
		}
		
		if (isPkgMod)
		{
			pkgSelected.packageD = modInfo;
		}
		else
		{
			pkgSelected.modules ~= modInfo;
		}
	}
	@safe unittest
	{
		ModuleManager modmgr;
		modmgr.addRootPackage("pkgname", "*", ".", string[].init);
		modmgr.addModule("pkgname", "a/b/c", ModInfo("test.d"));
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "pkgname");
		assert(modmgr._rootPackages[0].root.name == "pkgname");
		assert(modmgr._rootPackages[0].root.packages.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].name == "a");
		assert(modmgr._rootPackages[0].root.packages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].name == "b");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].name == "c");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].modules.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].modules[0].src == "test.d");
		modmgr.addModule("pkgname", "a/b/c", ModInfo("test2.d"));
		modmgr.addModule("pkgname", "a/b/d", ModInfo("package.d"));
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "pkgname");
		assert(modmgr._rootPackages[0].root.packages.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].name == "a");
		assert(modmgr._rootPackages[0].root.packages[0].pkgName == "a");
		assert(modmgr._rootPackages[0].root.packages[0].dubPkgName == "pkgname");
		assert(modmgr._rootPackages[0].root.packages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].name == "b");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].pkgName == "a.b");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].dubPkgName == "pkgname");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages.length == 2);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].name == "c");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[1].name == "d");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].modules.length == 2);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].modules[0].src == "test.d");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[0].modules[1].src == "test2.d");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[1].modules.length == 0);
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[1].packageD.src == "package.d");
		assert(modmgr._rootPackages[0].root.packages[0].packages[0].packages[1].packageD.dubPkgName == "pkgname");
	}
	
	bool _isExclude(string file) @safe
	{
		import std.regex, std.range, std.algorithm, std.array, std.path;
		string[] filepaths;
		foreach (p; file.pathSplitter)
		{
			filepaths ~= chain(filepaths, [p]).join("/");
		}
		return _excludePatterns.any!(r => filepaths.any!(a => a.match(r)))
			|| _excludePaths.any!(p => filepaths.any!(a => a == p));
	}
	
	bool _isExcludePackage(string pkgName) @safe
	{
		return _excludePackages.any!(p => pkgName == p)
			|| _excludePackagePatterns.any!(r => pkgName.match(r));
	}
	
public:
	///
	void addSources(string dubPkgName, string pkgVer, string root, in string[] files, in string[] options) @safe
		in (!hasPackage(dubPkgName))
	{
		import std.file, std.path, std.string, std.array, std.range;
		if (_isExcludePackage(dubPkgName))
			return;
		auto absRoot     = root.absolutePath.buildNormalizedPath;
		auto absRootPath = absRoot.replace("\\", "/");
		addRootPackage(dubPkgName, pkgVer, absRoot, options);
		foreach (f; files)
		{
			ModInfo modInfo;
			auto absSrc     = f.absolutePath.buildNormalizedPath;
			auto relSrc     = absSrc.relativePath(absRoot);
			auto relSrcPath = relSrc.replace("\\", "/");
			if (_isExclude(relSrcPath))
				continue;
			modInfo.dubPkgName = dubPkgName;
			modInfo.src = relSrc;
			if (relSrcPath.isAbsolute || relSrcPath.startsWith(".."))
			{
				auto modPath      = relSrcPath;
				modInfo.dst       = dubPkgName.replace(":", "-") ~ "--_extra_." ~ modPath.baseName.stripExtension ~ ".html";
				modInfo.modName   = modPath.baseName.stripExtension;
				modInfo.pkgName   = "(extra)";
				assert(modPath.baseName.length <= modPath.length);
			}
			else if (absSrc.baseName.stripExtension == "package")
			{
				auto modPath      = relSrcPath.dirName;
				modInfo.dst       = dubPkgName.replace(":", "-") ~ "--" ~ modPath.replace("/", ".") ~ ".html";
				modInfo.modName   = modPath.baseName;
				modInfo.pkgName   = modPath[0..$-modInfo.modName.length].chomp("/").replace("/", ".");
				assert(modInfo.modName.length <= modPath.length);
			}
			else
			{
				auto modPath      = relSrcPath;
				modInfo.dst       = dubPkgName.replace(":", "-") ~ "--" ~ modPath.stripExtension.replace("/", ".") ~ ".html";
				modInfo.modName   = modPath.baseName.stripExtension;
				modInfo.pkgName   = modPath[0..$-modPath.baseName.length].chomp("/").replace("/", ".");
				assert(modPath.baseName.length <= modPath.length);
			}
			auto relSrcDir = relSrc.dirName;
			addModule(dubPkgName, relSrcDir == "." ? null : relSrcDir, modInfo);
		}
	}
	
	///
	bool hasPackage(string dubPkgName) const @safe
	{
		return _rootPackages.canFind!(a => a.name == dubPkgName);
	}
	
	///
	ref inout(PkgInfo) getPackageInfo(string dubPkgName) inout @safe
		in (hasPackage(dubPkgName))
	{
		import std.array;
		return getDubPackageInfo(dubPkgName).root;
	}
	///
	ref inout(DubPkgInfo) getDubPackageInfo(string dubPkgName) inout @safe
		in (hasPackage(dubPkgName))
	{
		import std.array;
		return _rootPackages.find!(a => a.name == dubPkgName).front;
	}
	
	@system unittest
	{
		import std.path;
		ModuleManager modmgr;
		auto filepath = __FILE__;
		auto dir    = filepath.buildNormalizedPath("../..").absolutePath;
		auto fdir   = filepath.dirName.baseName;
		auto fname  = filepath.relativePath(dir);
		
		modmgr.addSources("root", "v1.2.3", dir, [filepath], null);
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "root");
		assert(modmgr._rootPackages[0].packageVersion == "v1.2.3");
		assert(modmgr._rootPackages[0].root.modules.length == 0);
		assert(modmgr._rootPackages[0].root.packages.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].name == fdir);
		assert(modmgr._rootPackages[0].root.packages[0].modules.length == 1);
		assert(modmgr._rootPackages[0].root.packages[0].modules[0].src == fname);
		assert(modmgr._rootPackages[0].root.packages[0].modules[0].dubPkgName == "root");
	}
	
	///
	void clearSources() @safe
	{
		_rootPackages = null;
	}
	
	
	///
	void target(string dstDir) @safe @property
	{
		_target = dstDir;
	}
	
	///
	void exclude(in string[] packages, in string[] packagePatterns, in string[] paths, in string[] patterns)
	{
		_excludePaths = paths.dup;
		_excludePatterns = null;
		_excludePackages = packages.dup;
		_excludePackagePatterns = null;
		foreach (ptn; patterns)
			_excludePatterns ~= regex(ptn);
		foreach (ptn; packagePatterns)
			_excludePackagePatterns ~= regex(ptn);
	}
	
	inout(DubPkgInfo)[] dubPackages() inout @property
	{
		return _rootPackages;
	}
}
