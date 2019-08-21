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
		
		modmgr.exclude(
				cfg.gendocData.excludePackages,
				cfg.gendocData.excludePackagePatterns,
				cfg.gendocData.excludePaths,
				cfg.gendocData.excludePatterns);
		
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
		
		generator.createTemporaryDir();
		scope(exit)
			generator.removeTemporaryDir();
		
		generator.compiler = cfg.compiler;
		
		if (!cfg.quiet)
		{
			generator.preGenerateCallback = (string pkgName, ModInfo[] modInfo, string[] args)
			{
				if (cfg.varbose)
				{
					writef("Generate %s ------------------\n", pkgName);
					foreach (m; modInfo)
					{
						writef("  |from: %s\n", generator.rootDir.buildPath(m.src));
						writef("  |  to: %s\n", generator.targetDir.buildPath(m.dst));
					}
					writef("    with args:\n%-(        %-s\n%)\n    ...", args);
				}
				else
				{
					writef("Generate %s ...", pkgName);
				}
			};
			
			generator.postGenerateCallback = (string pkgName, ModInfo[] modInfo, int status, string resMsg)
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
					writefln("Copyfrom %s\n      to %s\n    ... done.",
						generator.targetDir.buildPath(src),
						generator.rootDir.buildPath(dst));
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
			foreach (de; dir.dirEntries("*.ddoc.mustache", SpanMode.shallow))
			{
				auto absDir = dir.absolutePath.buildNormalizedPath();
				auto absFile = de.name.absolutePath.buildNormalizedPath();
				generator.generateDdoc(modmgr.dubPackages, absDir, absFile.relativePath(absDir).stripExtension);
			}
		}
		
		generator.targetDir = cfg.gendocData.target.absolutePath.buildNormalizedPath;
		foreach (pkg; modmgr.dubPackages)
			generator.generate(pkg, cfg.singleFile);
		
		// set source_doc (*.dd|*.js|*.css|*.*)
		foreach (sdocs; cfg.gendocData.sourceDocs)
		{
			auto absSrcDir = sdocs.absolutePath.buildNormalizedPath;
			generator.rootDir   = absSrcDir;
			foreach (de; absSrcDir.dirEntries(SpanMode.depth))
			{
				import std.algorithm: endsWith;
				if (de.isDir)
					continue;
				auto targetFile = relativePath(de.name, absSrcDir);
				switch (de.name.endsWith(".mustache"))
				{
				case 1:
					auto absFile = de.name.absolutePath.buildNormalizedPath();
					auto mustachName = absFile.relativePath(absSrcDir).stripExtension;
					auto srcFile = generator.generateFromMustache(modmgr.dubPackages, absSrcDir, mustachName);
					generator.generate(targetFile, srcFile, cfg.packageData.options);
					break;
				default:
					generator.generate(targetFile, de.name, cfg.packageData.options);
					break;
				}
			}
		}
	}
	catch(Exception e)
	{
		import std.stdio : stderr, writeln;
		stderr.writeln(e.msg);
		return -1;
	}

	return 0;
}
