module src.docgen;

/***************************************************************
 * 
 */
struct DocumentGenerator
{
	import std.file, std.path;
	///
	string   compiler;
	///
	string[] options;
	///
	string[] ddocFiles;
	///
	bool     disableMarkdown;
	///
	string   targetDir;
	///
	string   rootDir;
	
	///
	void delegate(string src, string dst, string[] args) preGenerateCallback;
	///
	void delegate(string src, string dst, int result, string output) postGenerateCallback;
	///
	void delegate(string src, string dst) postCopyCallback;
	
	///
	void generate(string target, string source)
	{
		switch (source.extension)
		{
		case ".d":
			_generateD(_fixAbs(targetDir, target), _fixAbs(rootDir, source));
			break;
		case ".dd":
			_generateD(_fixAbs(targetDir, target).stripExtension().setExtension(".html"), _fixAbs(rootDir, source));
			break;
		default:
			_copyFile(_fixAbs(targetDir, target), _fixAbs(rootDir, source));
			break;
		}
	}
	
private:
	static string _fixAbs(string base, string path)
	{
		return path.isAbsolute ? path: base.buildPath(path).absolutePath();
	}
	void _copyFile(string target, string source)
		in (target.isAbsolute)
		in (source.isAbsolute)
	{
		if (!target.dirName.exists)
			target.dirName.mkdirRecurse();
		std.file.copy(source, target);
		if (postCopyCallback !is null)
			postCopyCallback(source.relativePath(rootDir), target.relativePath(targetDir));
	}
	void _generateD(string target, string source)
		in (target.isAbsolute)
		in (source.isAbsolute)
	{
		import std.process: execute;
		auto args = [compiler, "-o-"];
		args ~= options;
		args ~= ["-Df" ~ target, source] ~ ddocFiles;
		if (!disableMarkdown)
			args ~= "-preview=markdown";
		
		if (preGenerateCallback !is null)
			preGenerateCallback(source.relativePath(rootDir), target.relativePath(targetDir), args);
		
		auto result = execute(args);
		
		if (postGenerateCallback !is null)
			postGenerateCallback(source.relativePath(rootDir), target.relativePath(targetDir), result.status, result.output);
	}
}

