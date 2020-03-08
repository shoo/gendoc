/***************************************************************
 * Features for unit testing
 * 
 * Fine-tune the output destination of coverage, etc.
 */
module ut;

// dub specifies the directory to store the coverage in the source code
// By importing, determine the execution order of module constructor and overwrite settings
import dub.dub;

debug shared static this()
{
	import core.stdc.stdio;
	setvbuf(stdout, null, _IONBF, 0);
}
///
version (D_Coverage)
{
	private extern (C) void dmd_coverDestPath( string pathname );
	private extern (C) void dmd_coverSourcePath( string pathname );
	private extern (C) void dmd_coverSetMerge( bool flag );
	
	private struct CovOpt
	{
		string dir;
		bool   merge;
	}
	
	private CovOpt getCovOptFromString(string str)
	{
		import std.string, std.getopt, std.algorithm, std.array;
		CovOpt ret;
		auto args = [""] ~ str.splitLines.map!(a => a.strip).filter!(a => a.length > 0).array;
		args.getopt(
			config.caseSensitive,
			config.bundling,
			config.passThrough,
			"d|dir|coverage_dir", &ret.dir,
			"m|merge|coverage_merge", &ret.merge);
		return ret;
	}
	
	@system unittest
	{
		auto opt = getCovOptFromString(`
			-d=xxx
			`);
		assert(opt.dir == "xxx");
		assert(!opt.merge);
		opt = getCovOptFromString(`
			--dir=cov
			--xxx
			-m
			`);
		assert(opt.dir == "cov");
		assert(opt.merge);
		opt = getCovOptFromString(null);
		assert(opt.dir.length == 0);
		assert(!opt.merge);
		
		opt = getCovOptFromString(`-md=xxx`);
		assert(opt.dir == "xxx");
		assert(opt.merge);
		
	}
	
	private CovOpt getCovOpt(string[] searchDirs = ["."], string[] searchFileNames = [".coverageopt"])
	{
		import std.file, std.path;
		CovOpt ret;
		foreach (d; searchDirs)
		{
			foreach (f; searchFileNames)
			{
				auto filepath = d.buildPath(f);
				if (filepath.exists && filepath.isFile)
				{
					ret = getCovOptFromString(readText(filepath));
					break;
				}
			}
			if (ret.dir.length == 0 && d.exists && d.isDir)
			{
				ret.dir = d;
				break;
			}
		}
		return ret;
	}
	
	@system unittest
	{
		import std.file, std.path;
		auto opt = getCovOpt(["."], ["nul"]);
		assert(opt.dir == ".");
		assert(!opt.merge);
		
		auto dir = "._._._workdir_._._";
		auto file = ".dat";
		dir.mkdir();
		scope (exit)
			dir.rmdirRecurse();
		dir.buildPath(file).write("-d=dir");
		opt = getCovOpt([dir], [file]);
		assert(opt.dir == "dir");
		assert(!opt.merge);
	}
	
	private CovOpt getCovOpt(string[string] env)
	{
		import std.algorithm, std.string;
		CovOpt ret;
		if (auto p = "COVERAGE_DIR" in env)
			ret.dir = strip(*p);
		if (auto p = "COVERAGE_MERGE" in env)
			ret.merge = ["merge", "true", "yes"].any!(a => a == *p );
		return ret;
	}
	
	@system unittest
	{
		auto opt = getCovOpt(["COVERAGE_DIR": "xxx", "COVERAGE_MERGE": "yes"]);
		assert(opt.dir == "xxx" && opt.merge);
		
		opt = getCovOpt(["COVERAGE_DIR": "aaa", "COVERAGE_MERGE": "true"]);
		assert(opt.dir == "aaa" && opt.merge);
		
		opt = getCovOpt(["COVERAGE_MERGE": "merge"]);
		assert(opt.dir.length == 0 && opt.merge);
		
		opt = getCovOpt(["COVERAGE_DIR": "xxx", "COVERAGE_MERGE": "aaa"]);
		assert(opt.dir == "xxx" && !opt.merge);
		
		opt = getCovOpt(["COVERAGE_DIR": "xxx"]);
		assert(opt.dir == "xxx" && !opt.merge);
	}
	
	private CovOpt getCovOpt(string[string] env, string[] searchDirs, string[] searchFileNames)
	{
		auto opt = getCovOpt(env);
		if (opt.dir.length > 0)
			return opt;
		return getCovOpt(searchDirs, searchFileNames);
	}
	
	@system unittest
	{
		auto opt = getCovOpt(["xx": "yy"], ["."], [".xxx"]);
		assert(opt.dir == ".");
		opt = getCovOpt(["COVERAGE_DIR": "yy"], ["."], [".xxx"]);
		assert(opt.dir == "yy");
	}
	
	
	private CovOpt getCovOpt()
	{
		import std.process, std.path, std.file;
		return getCovOpt(environment.toAA, [".",
			thisExePath.dirName.buildPath("cov"),
			thisExePath.dirName.buildPath(".cov"),
			"cov", ".cov", "."], [".coverageopt"]);
	}
	
	shared static this()
	{
		import std.file, std.path;
		auto covopt = getCovOpt();
		if (covopt.dir.length > 0)
		{
			enum rootDir = __FILE_FULL_PATH__.dirName.dirName.buildNormalizedPath();
			if (!covopt.dir.exists) mkdirRecurse(covopt.dir);
			dmd_coverSetMerge(covopt.merge);
			dmd_coverSourcePath(rootDir);
			dmd_coverDestPath(covopt.dir);
		}
	}
}
