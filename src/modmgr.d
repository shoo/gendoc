module src.modmgr;

import std.algorithm;
import std.regex;
import std.stdio;

import src.config;

/***************************************************************
 * 
 */
struct FileInfo
{
	///
	string rootDir;
	///
	string src;
	///
	string dst;
	///
	string pkgName;
	///
	string modName;
	///
	string[] options;
	
	///
	string fullModuleName() @safe const @property
	{
		return pkgName.length != 0 ? pkgName ~ "." ~ modName : modName;
	}
	
	///
	this(string srcFile) @safe
	{
		src = srcFile;
	}
}

/***************************************************************
 * 
 */
struct PackageInfo
{
	///
	string        name;
	///
	string        packageVersion;
	///
	FileInfo      packageD;
	///
	FileInfo[]    modules;
	///
	PackageInfo[] packages;
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
	///
	bool isPackage;
	union
	{
		///
		PackageInfo* pkg;
		///
		FileInfo*   file;
	}
	///
	this(return ref FileInfo d) @safe
	{
		isPackage = false;
		() @trusted { file = &d; }();
	}
	///
	this(return ref PackageInfo d) @safe
	{
		isPackage = true;
		() @trusted { pkg = &d; }();
	}
	///
	string name() @safe const @property
	{
		import std.path: baseName, stripExtension;
		return isPackage
			? () @trusted {return pkg.name; }()
			: () @trusted {return file.src.baseName.stripExtension; }();
	}
	
	ref inout(PackageInfo) packageInfo() @safe inout @property
	{
		assert(isPackage);
		return *(() inout @trusted { return pkg; } ());
	}
	
	ref inout(FileInfo) fileInfo() @safe inout @property
	{
		assert(!isPackage);
		return *(() inout @trusted { return file; } ());
	}
	
	///
	inout(PackageAndModuleData)[] children() @trusted inout @property
	{
		import std.range, std.algorithm, std.string;
		if (!isPackage)
			return null;
		
		PackageAndModuleData[] datas;
		foreach (ref pkg; () @trusted { return cast(PackageInfo[])packageInfo.packages; }())
			datas ~= PackageAndModuleData(pkg);
		foreach (ref f; () @trusted { return cast(FileInfo[])packageInfo.modules; }())
			datas ~= PackageAndModuleData(f);
		return cast(inout)datas;
	}
}

/***************************************************************
 * 
 */
void sort(ref PackageAndModuleData[] datas) @safe
{
	import std.algorithm, std.string;
	std.algorithm.sort!((a, b) => icmp(a.name, b.name) < 0)(datas);
}

/***************************************************************
 * 
 */
void putModuleMenuPkg(R)(ref R lines, PackageInfo data, size_t depth = 0) @safe
{
	import std.array : replicate;
	import std.format : formattedWrite;
	
	auto outerIndent = "    ".replicate(depth);
	
	lines.formattedWrite!"%s$(MENU_PKG %s,\n"(outerIndent, data.name);
	if (data.hasPackageD)
	{
		auto innerIndent = "    ".replicate(depth + 1);
		lines.formattedWrite!"%s$(A %s, $(SPAN, package))\n"(innerIndent, data.packageD.dst);
	}
	
	lines.putModuleMenuPkgChildren(data, depth + 1);
	
	lines.formattedWrite!"%s)\n"(outerIndent);
}

/// ditto
void putModuleMenuPkgChildren(R)(ref R lines, PackageInfo data, size_t depth = 0) @safe
{
	lines.putModuleMenu(PackageAndModuleData(data).children, depth);
}

/// ditto
void putModuleMenuMod(R)(ref R lines, FileInfo data, size_t depth = 0) @safe
{
	import std.array : replicate;
	import std.format : formattedWrite;
	
	auto innerIndent = "    ".replicate(depth);
	
	lines.formattedWrite!"%s$(A %s, $(SPAN, %s))\n"(innerIndent, data.dst, data.modName);
}

/// ditto
void putModuleMenu(R)(ref R lines, PackageAndModuleData data, size_t depth = 0) @safe
{
	if (data.isPackage)
	{
		lines.putModuleMenuPkg(data.packageInfo, depth);
	}
	else
	{
		lines.putModuleMenuMod(data.fileInfo, depth);
	}
}
/// ditto
void putModuleMenu(R)(ref R lines, PackageAndModuleData[] datas, size_t depth = 0) @safe
{
	auto ary = datas[].dup;
	ary.sort();
	foreach (data; ary)
		lines.putModuleMenu(data, depth);
}


/*******************************************************************************
 * 
 */
void putModuleIndexPkg(R)(ref R lines, PackageInfo pkg, size_t depth = 0) @safe
{
	import std.format: formattedWrite;
	
	if(pkg.hasPackageD)
		lines.formattedWrite!"    $(A %s, $(SPANC module_index, %s))$(DDOC_BLANKLINE)\n"(
			pkg.packageD.dst, pkg.packageD.fullModuleName);
	
	lines.putModuleIndexPkgChildren(pkg, depth + 1);
}

/// ditto
void putModuleIndexPkgChildren(R)(ref R lines, PackageInfo pkg, size_t depth = 0) @safe
{
	lines.putModuleIndex(PackageAndModuleData(pkg).children, depth);
}

/// ditto
void putModuleIndexMod(R)(ref R lines, FileInfo file, size_t depth = 0) @safe
{
	import std.format: formattedWrite;
	lines.formattedWrite!"    $(A %s, $(SPANC module_index, %s))$(DDOC_BLANKLINE)\n"(
		file.dst, file.fullModuleName);
}

/// ditto
void putModuleIndex(R)(ref R lines, PackageAndModuleData data, size_t depth = 0) @safe
{
	if (data.isPackage)
	{
		lines.putModuleIndexPkg(data.packageInfo, depth);
	}
	else
	{
		lines.putModuleIndexMod(data.fileInfo, depth);
	}
}
/// ditto
void putModuleIndex(R)(ref R lines, PackageAndModuleData[] datas, size_t depth = 0) @safe
{
	auto ary = datas[].dup;
	ary.sort();
	foreach (data; ary)
		lines.putModuleIndex(data, depth);
}


/*******************************************************************************
 * 
 */
struct PackageAndModuleRange
{
private:
	PackageAndModuleData[][] _datas;
	
	this(PackageInfo[] pkgs)
	{
		PackageAndModuleData[] tmp;
		import std.algorithm;
		foreach (ref pkg; pkgs)
			tmp ~= PackageAndModuleData(pkg);
		tmp.sort();
		_datas = [tmp];
	}
public:
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




/***************************************************************
 * 
 */
struct ModuleManager
{
private:
	Regex!char[]  _excludePatterns;
	string        _target;
	PackageInfo[] _rootPackages;
	string[]      _excludePaths;
	
	void addRootPackage(string pkgName, string pkgVer = "*") @safe
		in (!_rootPackages.canFind!(a => a.name == pkgName))
	{
		_rootPackages ~= PackageInfo(pkgName, pkgVer);
	}
	
	void addModule(R)(R path, FileInfo fInfo) @safe
	{
		import std.path;
		PackageInfo[]* pkgTree = &_rootPackages;
		PackageInfo* pkgSelected;
		auto isPkgMod = fInfo.src.baseName.stripExtension() == "package";
		foreach (p; path)
		{
			bool found;
			foreach (ref branch; *pkgTree)
			{
				if (branch.name == p)
				{
					found = true;
					pkgSelected = () @trusted { return &branch; } ();
					break;
				}
			}
			if (!found)
			{
				*pkgTree ~= PackageInfo(p);
				pkgSelected = &(*pkgTree)[$-1];
			}
			assert(pkgSelected !is null);
			pkgTree = &pkgSelected.packages;
		}
		if (isPkgMod)
		{
			pkgSelected.packageD    = fInfo;
		}
		else
		{
			pkgSelected.modules ~= fInfo;
		}
	}
	@safe unittest
	{
		ModuleManager modmgr;
		modmgr.addModule(["a", "b", "c"], FileInfo("test.d"));
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "a");
		assert(modmgr._rootPackages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].packages[0].name == "b");
		assert(modmgr._rootPackages[0].packages[0].packages.length == 1);
		assert(modmgr._rootPackages[0].packages[0].packages[0].name == "c");
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules.length == 1);
		assert(modmgr._rootPackages[0].packages[0].packages[0].modules[0].src == "test.d");
		modmgr.addModule(["a", "b", "c"], FileInfo("test2.d"));
		modmgr.addModule(["a", "b", "d"], FileInfo("package.d"));
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
		import std.regex, std.algorithm;
		return _excludePatterns.any!(r => file.match(r))
			|| _excludePaths.any!(p => file == p);
	}
	
public:
	///
	void addSources(string dubPkgName, string pkgVer, string root, string[] files, string[] options) @safe
		in (!hasPackage(dubPkgName))
	{
		import std.file, std.path, std.string, std.array, std.range;
		addRootPackage(dubPkgName, pkgVer);
		auto absRoot     = root.absolutePath.buildNormalizedPath;
		auto absRootPath = absRoot.replace("\\", "/");
		foreach (f; files)
		{
			FileInfo fInfo;
			auto absSrc     = f.absolutePath.buildNormalizedPath;
			auto relSrc     = absSrc.relativePath(absRoot);
			auto relSrcPath = relSrc.replace("\\", "/");
			if (_isExclude(relSrcPath))
				continue;
			fInfo.rootDir   = absRoot;
			fInfo.src       = relSrc;
			fInfo.options   = options;
			if (absSrc.baseName.stripExtension == "package")
			{
				auto modPath    = relSrcPath.dirName;
				fInfo.dst       = modPath.replace("/", "_").setExtension(".html");
				fInfo.modName   = modPath.baseName;
				assert(fInfo.modName.length <= modPath.length);
				fInfo.pkgName   = modPath[0..$-fInfo.modName.length].chomp("/").replace("/", ".");
			}
			else
			{
				auto modPath    = relSrcPath;
				fInfo.dst       = modPath.stripExtension.replace("/", "_").setExtension(".html");
				fInfo.modName   = modPath.baseName.stripExtension;
				assert(modPath.baseName.length <= modPath.length);
				fInfo.pkgName   = modPath[0..$-modPath.baseName.length].chomp("/").replace("/", ".");
			}
			auto relSrcDir = relSrc.dirName;
			if (relSrcDir == ".")
			{
				addModule([dubPkgName], fInfo);
			}
			else
			{
				addModule(chain([dubPkgName], relSrcDir.pathSplitter), fInfo);
			}
		}
	}
	
	///
	bool hasPackage(string dubPkgName) const @safe
	{
		return _rootPackages.canFind!(a => a.name == dubPkgName);
	}
	
	///
	ref inout(PackageInfo) getPackageInfo(string dubPkgName) inout @safe
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
		
		modmgr.addSources("root", dir, [filepath], null);
		assert(modmgr._rootPackages.length == 1);
		assert(modmgr._rootPackages[0].name == "root");
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
	void exclude(string[] paths, string[] patterns)
	{
		_excludePaths = paths;
		_excludePatterns = null;
		foreach (ptn; patterns)
			_excludePatterns ~= regex(ptn);
	}
	
	///
	string getModuleListDdoc(bool enableDubPackageInfo = true) @safe
	{
		import std.array, std.format;
		auto lines = appender!string;
		lines.put("MODULE_MENU=\n");
		if (enableDubPackageInfo)
		{
			foreach (pkg; _rootPackages)
				lines.putModuleMenuPkg(pkg, 1);
		}
		else
		{
			foreach (pkg; _rootPackages)
				lines.putModuleMenuPkgChildren(pkg, 1);
		}
		lines.put("_=\n");

		lines.put("\n");
		lines.put("MENU_PKG=$(LIC expand-container open, $(AC expand-toggle, #, $(SPAN, $1))$(ITEMIZE $+))\n");
		lines.put("_=\n");

		lines.put("\n");
		lines.put("MODULE_INDEX=\n");
		if (enableDubPackageInfo)
		{
			foreach (pkg; _rootPackages)
				lines.putModuleIndexPkg(pkg, 1);
		}
		else
		{
			foreach (pkg; _rootPackages)
				lines.putModuleIndexPkgChildren(pkg, 1);
		}
		lines.put("_=\n");
		
		if (_rootPackages.length > 0)
		{
			lines.formattedWrite!"PROJECT_NAME=%s\n_=\n\n"(_rootPackages[0].name);
			lines.formattedWrite!"PROJECT_VERSION=%s\n_=\n\n"(_rootPackages[0].packageVersion);
		}
		return lines.data;
	}
	
	inout(PackageAndModuleRange) entries() inout @property
	{
		return cast(inout)PackageAndModuleRange(cast(PackageInfo[])_rootPackages);
	}
}

