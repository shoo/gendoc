/***************************************************************
 * Features for unit testing
 * 
 * Fine-tune the output destination of coverage, etc.
 */
module ut;

debug static this()
{
	import core.runtime, core.stdc.stdio;
	import std.file, std.path;
	setvbuf(stdout, null, _IONBF, 0);
	version (coverage)
	{
		enum rootDir = __FILE__.dirName.dirName.buildNormalizedPath();
		enum covDir  = rootDir.buildNormalizedPath(".cov");
		dmd_coverDestPath(covDir);
		dmd_coverSourcePath(rootDir);
		dmd_coverSetMerge(true);
	}
}
