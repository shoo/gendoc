// Written in the D programming language

/++
	This is a program for simplifying ddoc generation.

	It ensures that the names of the generated .html files include the full
	module path (with underscores instead of dots) rather than simply being
	named after the modules (since just using the module names results in
	connflicts if any packages have modules with the same name).

	It also provides an easy way to exclude files from ddoc generation. Any
	modules or packages with the name internal are excluded as well as any
	files that are passed on the command line. And package.d files have their
	corresponding .html files renamed to match the package name.

	Also, the program generates a .ddoc file intended for use in a navigation
	bar on the side of the documentation (similar to what dlang.org has) uses
	it in the ddoc generation (it's deleted afterwards). The navigation bar
	contains the full module hierarchy to allow for easy navigation among the
	modules in the project. Of course, the other .ddoc files have to actually
	use the MODULE_MENU macro in the generated .ddoc file, or the documentation
	won't end up with a navigation bar.

	The program assumes a layout similar to dub in that the source files are
	expected to be in a directory called "source", and the generated
	documentation goes in the "docs" directory (which is deleted before
	documentation generation to ensure a clean build).

	It's expected that any .ddoc files being used will be in the "ddoc"
	directory, which isn't a dub thing, but they have to go somewhere.

	In addition, the program expects there to be a "source_docs" directory. Any
	.dd files that are there will have corresponding .html files generated for
	them (e.g. for generating index.html), and any other files or directories
	(e.g. a "css" or "js" folder) will be copied over to the "docs" folder.

	Note that this program does assume that all module names match their file
	names and that all package names match their folder names.

	Copyright: Copyright 2017 - 2018
	License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Author:   Jonathan M Davis, SHOO
  +/
module src.main;

import std;

import src.config;
import src.docgen;
import src.modmgr;

int main(string[] args)
{
	src.config.Config cfg;
	DocumentGenerator generator;
	ModuleManager     modmgr;
	try
	{
		auto getoptInfo = cfg.setup(args);
		if (getoptInfo.helpWanted)
		{
			import std.getopt;
			defaultGetoptPrinter("Usage: gendoc [options]\nOptions:", getoptInfo.options);
			return 0;
		}
		
		cfg.gendocData.ddocs.all!(a => a.exists).enforce("ddoc directory is missing");
		cfg.gendocData.sourceDocs.all!(a => a.exists).enforce("source_docs directory is missing");
		
		modmgr.exclude(cfg.gendocData.excludePaths, cfg.gendocData.excludePatterns);
		
		if(!cfg.gendocData.target.exists)
			mkdir(cfg.gendocData.target);
		foreach (de; cfg.gendocData.target.dirEntries(SpanMode.shallow))
		{
			if (de.name.startsWith(cfg.gendocData.target.buildPath(".")))
				continue;
			if (de.isDir)
			{
				rmdirRecurse(de);
			}
			else
			{
				remove(de.name);
			}
		}
		modmgr.target = cfg.gendocData.target;
		
		void addPkg(PackageConfig pkgcfg)
		{
			modmgr.addSources(
				pkgcfg.name,
				pkgcfg.packageVersion,
				pkgcfg.path,
				pkgcfg.files,
				pkgcfg.options);
			foreach (subpkg; pkgcfg.subPackages)
				addPkg(subpkg);
		}
		addPkg(cfg.packageData);
		
		auto moduleListDdoc = modmgr.getModuleListDdoc();
		auto moduleListDdocFile = "moduleListDdoc.ddoc";
		import std.file;
		std.file.write(moduleListDdocFile, moduleListDdoc);
		scope(exit)
			std.file.remove(moduleListDdocFile);
		
		generator.compiler = cfg.compiler;
		
		if (!cfg.quiet)
		{
			generator.preGenerateCallback = (string src, string dst, string[] args)
			{
				if (cfg.varbose)
				{
					writef("Generate %s\n    from %s\n    with args: %s\n    ...",
						generator.targetDir.buildPath(dst),
						generator.rootDir.buildPath(src),
						args);
				}
				else
				{
					writef("Generate %s ...", dst);
				}
			};
			
			generator.postGenerateCallback = (string src, string dst, int status, string resMsg)
			{
				if (status == 0)
				{
					writeln(" done.");
				}
				else
				{
					if (cfg.varbose)
					{
						writefln(" Failed\n    with code = 0x%08x msg: %s", status, resMsg);
					}
					else
					{
						writeln(" Failed.");
					}
					throw new Exception(resMsg);
				}
			};
			
			generator.postCopyCallback = (string src, string dst)
			{
				if (cfg.varbose)
				{
					writefln("Copy     %s\n    from %s\n    ... done.",
						generator.targetDir.buildPath(dst),
						generator.rootDir.buildPath(src));
				}
				else
				{
					writefln("Copy     %s ... done.", dst);
				}
			};
		}
		
		// set *.ddoc
		foreach (dir; cfg.gendocData.ddocs)
		{
			foreach (de; dir.dirEntries("*.ddoc", SpanMode.shallow))
				generator.ddocFiles ~= de.name;
		}
		generator.ddocFiles ~= moduleListDdocFile;
		
		// set source_doc (*.dd|*.js|*.css|*.*)
		generator.options = cfg.packageData.options;
		foreach (sdocs; cfg.gendocData.sourceDocs)
		{
			auto absSrcDir = sdocs.absolutePath.buildNormalizedPath;
			generator.rootDir   = absSrcDir;
			generator.targetDir = cfg.gendocData.target.absolutePath.buildNormalizedPath;
			foreach (de; absSrcDir.dirEntries(SpanMode.depth))
			{
				if (de.isDir)
					continue;
				generator.generate(relativePath(de.name, absSrcDir), de.name);
			}
		}
		
		// d sources
		foreach (e; modmgr.entries)
		{
			if (e.isPackage)
				continue;
			auto f = e.fileInfo;
			generator.rootDir = f.rootDir;
			generator.generate(f.dst, f.src);
		}
		
		
		
		/+
		auto ddocFiles = getDdocFiles(ddocDir);
		processSourceDocsDir(compiler, sourceDocsDir, docsDir, ddocFiles, flgMarkdown);
		foreach (sourceDir; sourceDirs)
			processSourceDir(compiler, sourceDir, docsDir, &isExclude, ddocFiles, flgMarkdown);
		+/
	}
	catch(Exception e)
	{
		import std.stdio : stderr, writeln;
		stderr.writeln(e.msg);
		return -1;
	}

	return 0;
}
/+
///
void processSourceDocsDir(string compiler, string sourceDir, string targetDir, string[] ddocFiles,
						  bool flgMarkdown)
{
	import std.file : copy;

	foreach(de; dirEntries(sourceDir, SpanMode.shallow))
	{
		auto target = buildPath(targetDir, de.baseName);
		if(de.isDir)
		{
			mkdir(target);
			processSourceDocsDir(compiler, de.name, target, ddocFiles, flgMarkdown);
		}
		else if(de.isFile)
		{
			if(de.name.extension == ".dd")
				genDdoc(compiler, sourceDir, de.name, target.setExtension(".html"), ddocFiles, flgMarkdown);
			else
				copy(de.name, target);
		}
	}
}

///
void processSourceDir(string compiler, string sourceDir, string target, bool delegate(string) isExclude,
					  string[] ddocFiles, bool flgMarkdown, int depth = 0)
{
	import std.algorithm : endsWith;

	if(depth == 0 && !target.endsWith("/"))
		target ~= "/";

	foreach(de; dirEntries(sourceDir, SpanMode.shallow))
	{
		auto name = de.baseName;
		if(isExclude(de.name.stripSourceDir(sourceDir)))
			continue;
		auto nextTarget = name == "package.d" ? target : format("%s%s%s", target, depth == 0 ? "" : "_", name);
		if(de.isDir)
			processSourceDir(compiler, de.name, nextTarget, isExclude, ddocFiles, flgMarkdown, depth + 1);
		else if(de.isFile)
			genDdoc(compiler, sourceDir, de.name, nextTarget.setExtension(".html"), ddocFiles, flgMarkdown);
	}
}
///
string[] getExtCompileArgsFromDub(string compiler, string sourceDir)
{
	import std.algorithm: filter;
	import std.process: execute;
	import std.string: split;
	import std.file: exists, isDir;
	import std.path: absolutePath, relativePath, buildPath, buildNormalizedPath;
	string[] ret;
	
	auto absSrcDir = sourceDir.absolutePath.buildNormalizedPath;
	auto dubDir = absSrcDir;
	while (dubDir.exists && dubDir.isDir)
	{
		if (buildPath(dubDir, "dub.json").exists || buildPath(dubDir, "dub.sdl").exists)
		{
			dubDir = absSrcDir.buildNormalizedPath(relativePath(dubDir, absSrcDir));
			break;
		}
		immutable newDir = dubDir.buildNormalizedPath("..");
		if (newDir == dubDir)
		{
			dubDir = null;
			break;
		}
		dubDir = newDir;
	}
	
	if (dubDir.exists && dubDir.isDir)
	{
		auto result = execute(["dub", "describe", "--data-0", "--data",
			"dflags,versions,debug-versions,import-paths,string-import-paths,import-files",
			"--root", dubDir, "--compiler", compiler]);
		if (result.status != 0)
			throw new Exception("compile failed:\n" ~ result.output);
		ret ~= result.output.split("\0").filter!(a => a.length != 0).array;
	}
	else
	{
		ret ~= "-I" ~ sourceDir;
	}
	return ret;
}

///
string[] getSourceDirs(string[] sourceRootPaths, string[] sourceDirPatterns, bool delegate(string) isExclude)
{
	import std.regex: regex, match, Regex;
	import std.algorithm: any, canFind;
	import std.array: array;
	import std.path: filenameCmp;
	string[] ret;
	Regex!char[] rSourceDirPatterns;
	foreach (ptn; sourceDirPatterns)
		rSourceDirPatterns ~= regex(ptn);
	void addPath(string p, string r)
	{
		foreach (de; dirEntries(p, SpanMode.shallow))
		{
			if (!de.isDir)
				continue;
			auto dirname = de.name.stripSourceDir(r);
			if (ret.canFind(dirname))
				continue;
			immutable inCond = rSourceDirPatterns.any!(r => dirname.match(r));
			immutable exCond = isExclude(dirname);
			if ( inCond && !exCond)
				ret ~= dirname;
			if (inCond || exCond)
				continue;
			addPath(de.name, r);
		}
	}
	
	foreach (p; sourceRootPaths)
		addPath(p, p);
	
	return ret;
}

///
string[] getDdocFiles(string ddocDir)
{
	import std.algorithm : map;
	return dirEntries(ddocDir, SpanMode.shallow).map!(a => a.name)().array();
}
+/
