module src.modmgr;

import std.algorithm;
import std.regex;
import std.stdio;



/***************************************************************
 * 
 */
struct ModInfo
{
	///
	string src;
	///
	string dst;
	///
	string pkgName;
	///
	string modName;
	
	///
	string fullModuleName() @safe const @property
	{
		return pkgName.length > 0 ? pkgName ~ "." ~ modName : modName;
	}
	
	///
	this(string srcFile) @safe
	{
		src = srcFile;
	}
	
	///
	invariant()
	{
		import std.path;
		assert(!src.isAbsolute);
		assert(!dst.isAbsolute);
	}
}

/***************************************************************
 * 
 */
struct PkgInfo
{
	///
	string        name;
	///
	ModInfo    packageD;
	///
	ModInfo[]  modules;
	///
	PkgInfo[] packages;
	///
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
		tmp.sort();
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
			chdatas.sort();
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

// 
private void sort(ref PackageAndModuleData[] datas) @safe
{
	import std.algorithm, std.string;
	std.algorithm.sort!((a, b) => icmp(a.name, b.name) < 0)(datas);
}

// 
private void putModuleMenuPkg(R)(ref R lines, PkgInfo data, size_t depth = 0, bool isDubPkg = false) @safe
{
	import std.array : replicate;
	import std.format : formattedWrite;
	
	auto outerIndent = "    ".replicate(depth);
	
	lines.formattedWrite!"%s$(%s %s,\n"(outerIndent,
		isDubPkg ? "MENU_DUBPKG" : "MENU_PKG",
		data.name);
	if (data.hasPackageD)
	{
		auto innerIndent = "    ".replicate(depth + 1);
		lines.formattedWrite!"%s$(MENU_MODULE %s, package)\n"(innerIndent, data.packageD.dst);
	}
	
	lines.putModuleMenuPkgChildren(data, depth + 1);
	
	lines.formattedWrite!"%s)\n"(outerIndent);
}

// 
private void putModuleMenuPkgChildren(R)(ref R lines, PkgInfo data, size_t depth = 0) @safe
{
	lines.putModuleMenu(PackageAndModuleData(data).children, depth);
}

// 
private void putModuleMenuMod(R)(ref R lines, ModInfo data, size_t depth = 0) @safe
{
	import std.array : replicate;
	import std.format : formattedWrite;
	
	auto innerIndent = "    ".replicate(depth);
	
	lines.formattedWrite!"%s$(MENU_MODULE %s, %s)\n"(innerIndent, data.dst, data.modName);
}

// 
private void putModuleMenu(R)(ref R lines, PackageAndModuleData data, size_t depth = 0) @safe
{
	if (data.isPackage)
	{
		lines.putModuleMenuPkg(data.packageInfo, depth);
	}
	else
	{
		lines.putModuleMenuMod(data.moduleInfo, depth);
	}
}
// 
private void putModuleMenu(R)(ref R lines, PackageAndModuleData[] datas, size_t depth = 0) @safe
{
	auto ary = datas[].dup;
	ary.sort();
	foreach (data; ary)
		lines.putModuleMenu(data, depth);
}


/*******************************************************************************
 * 
 */
private void putModuleIndexPkg(R)(ref R lines, PkgInfo pkg, size_t depth = 0, bool isDubPkg = false) @safe
{
	import std.array : replicate;
	import std.format : formattedWrite;
	
	auto outerIndent = "    ".replicate(depth);
	
	lines.formattedWrite!"%s$(%s %s,\n"(outerIndent,
		isDubPkg ? "INDEX_DUBPKG" : "INDEX_PKG",
		pkg.name);
	
	if(pkg.hasPackageD)
		lines.formattedWrite!"    $(INDEX_MODULE %s, %s)\n"(
			pkg.packageD.dst, pkg.packageD.fullModuleName);
	
	lines.putModuleIndexPkgChildren(pkg, depth + 1);
	
	lines.formattedWrite!"%s)\n"(outerIndent);
}

/// ditto
private void putModuleIndexPkgChildren(R)(ref R lines, PkgInfo pkg, size_t depth = 0) @safe
{
	lines.putModuleIndex(PackageAndModuleData(pkg).children, depth);
}

/// ditto
private void putModuleIndexMod(R)(ref R lines, ModInfo file, size_t depth = 0) @safe
{
	import std.format: formattedWrite;
	import std.array : replicate;
	auto innerIndent = "    ".replicate(depth);
	
	lines.formattedWrite!"%s$(INDEX_MODULE %s, %s)\n"(innerIndent,
		file.dst, file.fullModuleName);
}

/// ditto
private void putModuleIndex(R)(ref R lines, PackageAndModuleData data, size_t depth = 0) @safe
{
	if (data.isPackage)
	{
		lines.putModuleIndexPkg(data.packageInfo, depth);
	}
	else
	{
		lines.putModuleIndexMod(data.moduleInfo, depth);
	}
}
/// ditto
private void putModuleIndex(R)(ref R lines, PackageAndModuleData[] datas, size_t depth = 0) @safe
{
	auto ary = datas[].dup;
	ary.sort();
	foreach (data; ary)
		lines.putModuleIndex(data, depth);
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
	
	void addRootPackage(string pkgName, string pkgVer, string root, string[] options) @safe
		in (!_rootPackages.canFind!(a => a.name == pkgName))
	{
		_rootPackages ~= DubPkgInfo(pkgName, pkgVer, root, options);
	}
	
	void addModule(string pkgName, string path, ModInfo modInfo) @safe
		in (_rootPackages.canFind!(a => a.name == pkgName))
	{
		import std.path;
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
		}
		else
		{
			foreach (p; path.pathSplitter)
			{
				pkgSelected = getBranch(pkgTree, p);
				pkgTree = &pkgSelected.packages;
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
		modmgr.addModule(["a", "b", "c"], ModInfo("test.d"));
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "a");
		assert(modmgr._rootPackages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].packages[0].name == "b");
		assert(modmgr._rootPackages[0].packages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].packages[0].packages[0].name == "c");
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules.length == 1);
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules[0].src == "test.d");
		modmgr.addModule(["a", "b", "c"], ModInfo("test2.d"));
		modmgr.addModule(["a", "b", "d"], ModInfo("package.d"));
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "a");
		assert(modmgr._rootPackages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].packages[0].name == "b");
		assert(modmgr._rootPackages[0].packages[0].packages.length == 2);
		assert(modmgr._rootPackages[0].packages[0].packages[0].name == "c");
		assert(modmgr._rootPackages[0].packages[0].packages[1].name == "d");
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules.length == 2);
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules[0].src == "test.d");
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules[1].src == "test2.d");
		assert(modmgr._rootPackages[0].packages[0].packages[1].modules.length == 0);
		assert(modmgr._rootPackages[0].packages[0].packages[1].packageD.src == "package.d");
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
	void addSources(string dubPkgName, string pkgVer, string root, string[] files, string[] options) @safe
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
			modInfo.src = relSrc;
			if (relSrcPath.isAbsolute || relSrcPath.startsWith(".."))
			{
				auto modPath    = relSrcPath;
				modInfo.dst       = dubPkgName.replace(":", "-") ~ "--_extra_." ~ modPath.baseName.stripExtension ~ ".html";
				modInfo.modName   = modPath.baseName.stripExtension;
				assert(modPath.baseName.length <= modPath.length);
				modInfo.pkgName   = "(extra)";
			}
			else if (absSrc.baseName.stripExtension == "package")
			{
				auto modPath    = relSrcPath.dirName;
				modInfo.dst       = dubPkgName.replace(":", "-") ~ "--" ~ modPath.replace("/", ".") ~ ".html";
				modInfo.modName   = modPath.baseName;
				assert(modInfo.modName.length <= modPath.length);
				modInfo.pkgName   = modPath[0..$-modInfo.modName.length].chomp("/").replace("/", ".");
			}
			else
			{
				auto modPath    = relSrcPath;
				modInfo.dst       = dubPkgName.replace(":", "-") ~ "--" ~ modPath.stripExtension.replace("/", ".") ~ ".html";
				modInfo.modName   = modPath.baseName.stripExtension;
				assert(modPath.baseName.length <= modPath.length);
				modInfo.pkgName   = modPath[0..$-modPath.baseName.length].chomp("/").replace("/", ".");
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
		assert(modmgr._rootPackages[0].modules.length == 0);
		assert(modmgr._rootPackages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].packages[0].name == fdir);
		assert(modmgr._rootPackages[0].packages[0].modules.length == 1);
		assert(modmgr._rootPackages[0].packages[0].modules[0].src == fname);
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
	void exclude(string[] packages, string[] packagePatterns, string[] paths, string[] patterns)
	{
		_excludePaths = paths;
		_excludePatterns = null;
		_excludePackages = packages;
		_excludePackagePatterns = null;
		foreach (ptn; patterns)
			_excludePatterns ~= regex(ptn);
		foreach (ptn; packagePatterns)
			_excludePackagePatterns ~= regex(ptn);
	}
	
	///
	string getModuleListDdoc() @safe
	{
		import std.array, std.format;
		auto lines = appender!string;
		lines.put("MODULE_MENU=\n");
		foreach (pkg; _rootPackages)
			lines.putModuleMenuPkg(pkg.root, 1, true);
		lines.put("_=\n");

		lines.put("\n");
		lines.put("MODULE_INDEX=\n");
		foreach (pkg; _rootPackages)
			lines.putModuleIndexPkg(pkg.root, 1, true);
		lines.put("_=\n");
		
		if (_rootPackages.length > 0)
		{
			lines.formattedWrite!"PROJECT_NAME=%s\n_=\n\n"(_rootPackages[0].name);
			lines.formattedWrite!"PROJECT_VERSION=%s\n_=\n\n"(_rootPackages[0].packageVersion);
		}
		return lines.data;
	}
	
	inout(DubPkgInfo)[] dubPackages() inout @property
	{
		return _rootPackages;
	}
}

