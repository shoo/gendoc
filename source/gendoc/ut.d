module gendoc.ut;

version (gendoc_app):
debug shared static this()
{
	import core.stdc.stdio;
	setvbuf(stdout, null, _IONBF, 0);
}
///
version (D_Coverage) version(unittest)
{
	private extern (C) void dmd_coverDestPath( string pathname );
	private extern (C) void dmd_coverSetMerge( bool flag );
	shared static this()
	{
		import std.file, std.path;
		import core.internal.parseoptions : rt_configOption;
		auto covemerge =  rt_configOption("coverage_merge", null, true);
		auto covdir =  rt_configOption("coverage_dir", null, true);
		covdir = covdir.length == 0 ? thisExePath.dirName.buildPath("cov") : null;
		if (covdir.length > 0)
		{
			if (!covdir.exists) mkdir(covdir);
			dmd_coverSetMerge(covemerge.length > 0 ? covemerge == "merge" : false);
			dmd_coverDestPath(covdir);
		}
	}
}
