import std;

///
struct Defines
{
static:
	/// ドキュメントジェネレータを指定します。
	/// gendocのバージョンが更新されたら変更してください。
	immutable documentGenerator = "gendoc";
	
	/// テスト対象にするサブパッケージを指定します。
	/// サブパッケージが追加されたらここにも追加してください。
	immutable integrationTestCaseDir = "testcases";
	
	/// テスト対象にするサブパッケージを指定します。
	/// サブパッケージが追加されたらここにも追加してください。
	immutable subPkgs = ["candydoc"];
}

///
struct Config
{
	///
	string os;
	///
	string arch;
	///
	string compiler;
	///
	string hostArch;
	///
	string targetArch;
	///
	string hostCompiler;
	///
	string targetCompiler;
	///
	string archiveSuffix;
	///
	string scriptDir = __FILE__.dirName();
	///
	string projectName;
	///
	string refName;
}
///
__gshared Config config;

///
int main(string[] args)
{
	string mode;
	import core.stdc.stdio;
	setvbuf(stdout, null, _IONBF, 0);
	
	version (Windows)      {config.os = "windows";}
	else version (linux)   {config.os = "linux";}
	else version (OSX)     {config.os = "osx";}
	else static assert(0, "Unsupported OS");
	
	version (Windows)      {config.archiveSuffix = ".zip";}
	else version (linux)   {config.archiveSuffix = ".tar.gz";}
	else version (OSX)     {config.archiveSuffix = ".tar.gz";}
	else static assert(0, "Unsupported OS");
	
	version (D_LP64)      {config.arch = "x86_64";}
	else                  {config.arch = "x86";}
	
	version (DigitalMars) {config.compiler = "dmd";}
	else version (LDC)    {config.compiler = "ldc2";}
	else version (GNU)    {config.compiler = "gdc";}
	else static assert(0, "Unsupported Compiler");
	
	config.projectName = environment.get("GITHUB_REPOSITORY").chompPrefix(environment.get("GITHUB_ACTOR") ~ "/");
	config.refName = getRefName();
	
	config.hostArch       = config.arch;
	config.targetArch     = config.arch;
	config.hostCompiler   = config.compiler;
	config.targetCompiler = config.compiler;
	
	string tmpHostArch, tmpTargetArch, tmpHostCompiler, tmpTargetCompiler;
	string[] exDubOpts;
	
	args.getopt(
		"a|arch",          &config.arch,
		"os",              &config.os,
		"host-arch",       &tmpHostArch,
		"target-arch",     &tmpTargetArch,
		"c|compiler",      &config.compiler,
		"host-compiler",   &tmpHostCompiler,
		"target-compiler", &tmpTargetCompiler,
		"archive-suffix",  &config.archiveSuffix,
		"m|mode",          &mode,
		"exdubopts",       &exDubOpts);
	
	config.hostArch = tmpHostArch ? tmpHostArch : config.arch;
	config.targetArch = tmpTargetArch ? tmpTargetArch : config.arch;
	config.hostCompiler = tmpHostCompiler ? tmpHostCompiler : config.compiler;
	config.targetCompiler = tmpTargetCompiler ? tmpTargetCompiler : config.compiler;
	
	switch (mode.toLower)
	{
	case "unit-test":
	case "unittest":
	case "ut":
		unitTest(exDubOpts);
		break;
	case "integration-test":
	case "integrationtest":
	case "tt":
		integrationTest(exDubOpts);
		break;
	case "create-release-build":
	case "createreleasebuild":
	case "release-build":
	case "releasebuild":
	case "build":
		createReleaseBuild(exDubOpts);
		break;
	case "create-archive":
	case "createarchive":
		createArchive();
		break;
	case "create-document":
	case "createdocument":
	case "create-document-test":
	case "createdocumenttest":
	case "generate-document":
	case "generatedocument":
	case "generate-document-test":
	case "generatedocumenttest":
	case "gendoc":
	case "docs":
	case "doc":
		generateDocument();
		break;
	case "all":
		unitTest(exDubOpts);
		integrationTest(exDubOpts);
		createReleaseBuild(exDubOpts);
		createArchive();
		generateDocument();
		break;
	default:
		enforce(0, "Unknown mode: " ~ mode);
		break;
	}
	return 0;
}

///
void unitTest(string[] exDubOpts = null)
{
	string[string] env;
	auto covdir = config.scriptDir.buildNormalizedPath("../.cov");
	if (!covdir.exists)
		mkdirRecurse(covdir);
	env["COVERAGE_DIR"]   = covdir.absolutePath();
	env["COVERAGE_MERGE"] = "true";
	// Win64の場合はlibcurl.dllの64bit版を使うため、dmdのbin64にパスを通す
	if (config.os == "windows" && config.targetArch == "x86_64" && config.hostCompiler == "dmd")
	{
		auto bin64dir = searchDCompiler().dirName.buildPath("../bin64");
		if (bin64dir.exists && bin64dir.isDir)
			env.setPaths([bin64dir] ~ getPaths());
	}
	writeln("#######################################");
	writeln("## Unit Test                         ##");
	writeln("#######################################");
	exec(["dub",
		"test",
		"-a",              config.hostArch,
		"--coverage",
		"--compiler",      config.hostCompiler] ~ exDubOpts,
		null, env);
}

///
void generateDocument()
{
	string[string] env;
	// Win64の場合はlibcurl.dllの64bit版を使うため、dmdのbin64にパスを通す
	if (config.os == "windows" && config.targetArch == "x86_64" && config.hostCompiler == "dmd")
	{
		auto bin64dir = searchDCompiler().dirName.buildPath("../bin64");
		if (bin64dir.exists && bin64dir.isDir)
			env.setPaths([bin64dir] ~ getPaths());
	}
	exec(["dub", "run", Defines.documentGenerator, "-y",
		"--",
		"-a=x86_64", "-b=release", "-c=default"], null, env);
}

///
void createReleaseBuild(string[] exDubOpts = null)
{
	exec(["dub",
		"build",
		"-a",              config.hostArch,
		"-b=unittest-cov",
		"-c=default",
		"--compiler",      config.hostCompiler] ~ exDubOpts);
}


///
void integrationTest(string[] exDubOpts = null)
{
	string[string] env = [null: null];
	env.clear();
	// Win64の場合はlibcurl.dllの64bit版を使うため、dmdのbin64にパスを通す
	if (config.os == "windows" && config.targetArch == "x86_64" && config.hostCompiler == "dmd")
	{
		auto bin64dir = searchDCompiler().dirName.buildPath("../bin64");
		if (bin64dir.exists && bin64dir.isDir)
			env.setPaths([bin64dir] ~ getPaths());
	}
	auto covdir = config.scriptDir.buildNormalizedPath("../.cov").absolutePath();
	if (!covdir.exists)
		mkdirRecurse(covdir);
	env["COVERAGE_DIR"]   = covdir.absolutePath();
	env["COVERAGE_MERGE"] = "true";
	
	bool dirTest(string entry)
	{
		auto getRunOpts()
		{
			struct Opt
			{
				string name;
				string workdir;
				string[] dubExArgs;
				string[] args;
				string[string] env;
			}
			if (entry.buildPath(".no_run").exists)
				return Opt[].init;
			if (!entry.buildPath(".run_opts").exists)
				return [Opt("default", entry, [], [], env)];
			Opt[] ret;
			import std.file: read;
			auto jvRoot = parseJSON(cast(string)read(entry.buildPath(".run_opts")));
			foreach (i, jvOpt; jvRoot.array)
			{
				auto dat = Opt(text("run", i), entry, [], [], env);
				if ("name" in jvOpt && jvOpt["name"].type == JSONType.string)
					dat.name = jvOpt["name"].str;
				if ("workdir" in jvOpt && jvOpt["workdir"].type == JSONType.string)
					dat.workdir = isAbsolute(jvOpt["workdir"].str)
					            ? jvOpt["workdir"].str
					            : entry.buildNormalizedPath(jvOpt["workdir"].str);
				if ("args" in jvOpt)
				{
					foreach (arg; jvOpt["args"].array)
						dat.args ~= arg.str;
				}
				if ("dubExArgs" in jvOpt)
				{
					foreach (arg; jvOpt["dubExArgs"].array)
						dat.dubExArgs ~= arg.str;
				}
				if ("env" in jvOpt)
				{
					foreach (k, v; jvOpt["env"].object)
					{
						enforce(v.type == JSONType.string);
						dat.env[k] = v.str;
					}
				}
				ret ~= dat;
			}
			return ret;
		}
		if (entry.isDir)
		{
			auto no_build    = entry.buildPath(".no_build").exists;
			auto no_test     = entry.buildPath(".no_test").exists;
			auto no_coverage = entry.buildPath(".no_coverage").exists;
			auto runOpts     = getRunOpts();
			auto dubCommonArgs = [
				"-a",         config.targetArch,
				"--compiler", config.targetCompiler] ~ exDubOpts;
			if (!no_build)
				exec(["dub", "build", "-b=release"] ~ dubCommonArgs, entry, env);
			if (!no_test)
				exec(["dub", "test"]  ~ dubCommonArgs ~ (!no_coverage ? ["--coverage"] : null), entry, env);
			foreach (runOpt; runOpts)
				exec(["dub", "run"]
					~ (runOpt.dubExArgs.length > 0 ? dubCommonArgs ~ runOpt.dubExArgs : dubCommonArgs)
					~ (!no_coverage ? ["-b=cov"] : ["-b=debug"])
					~ (runOpt.args.length > 0 ? ["--"] ~ runOpt.args : []), runOpt.workdir, runOpt.env);
			return !(no_build && no_test && runOpts.length == 0);
		}
		else switch (entry.extension)
		{
		case ".d":
			// rdmd
			exec(["rdmd", entry], entry.dirName, env);
			break;
		case ".sh":
			// $SHELLまたはbashがあれば
			if (auto sh = environment.get("SHELL"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			if (auto sh = searchPath("bash"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			break;
		case ".bat":
			// %COMSPEC%があれば
			if (auto sh = environment.get("COMSPEC"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			break;
		case ".ps1":
			// pwsh || powershellがあれば
			if (auto sh = searchPath("pwsh"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			else if (auto sh = searchPath("powershell"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			break;
		case ".py":
			// python || python3があれば
			if (auto sh = searchPath("python"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			else if (auto sh = searchPath("python3"))
			{
				exec([sh, entry], entry.dirName, env);
				return true;
			}
			break;
		default:
			// なにもしない
		}
		return false;
	}
	bool subPkgTest(string pkgName)
	{
		//exec(["dub", "build", ":" ~ pkgName, "-b=release"] ~ exDubOpts, null, env);
		exec(["dub", "test", ":" ~ pkgName, "--coverage"] ~ exDubOpts, null, env);
		//exec(["dub", "run", ":" ~ pkgName, "-b=cov"] ~ exDubOpts, null, env);
		return true;
	}
	
	struct Result
	{
		string name;
		bool executed;
		Exception exception;
	}
	
	Result[] dirTests;
	Result[] subpkgTests;
	if (Defines.integrationTestCaseDir.exists)
	{
		writeln("#######################################");
		writeln("## Test Directory Entries            ##");
		writeln("#######################################");
		foreach (de; dirEntries(Defines.integrationTestCaseDir, SpanMode.shallow))
		{
			auto res = Result(de.name.baseName);
			try
				res.executed = dirTest(de.name);
			catch (Exception e)
				res.exception = e;
			dirTests ~= res;
		}
	}
	if (Defines.subPkgs.length)
	{
		writeln("#######################################");
		writeln("## Test SubPackages                  ##");
		writeln("#######################################");
		foreach (pkgName; Defines.subPkgs)
		{
			auto res = Result(pkgName);
			try
				res.executed = subPkgTest(pkgName);
			catch (Exception e)
				res.exception = e;
			subpkgTests ~= res;
		}
	}
	
	if (dirTests.length > 0 || subpkgTests.length > 0)
	{
		writeln("#######################################");
		writeln("## Integration Test Summary          ##");
		writeln("#######################################");
	}
	if (dirTests.length > 0)
	{
		writeln("##### Test Summary of Directory Entries");
		writefln("Failed:    %s / %s", dirTests.count!(a => a.executed && a.exception), dirTests.length);
		writefln("Succeeded: %s / %s", dirTests.count!(a => a.executed && !a.exception), dirTests.length);
		writefln("Skipped:   %s / %s", dirTests.count!(a => !a.executed), dirTests.length);
		foreach (res; dirTests)
		{
			if (!res.executed)
				continue;
			if (res.exception)
			{
				writefln("[X] %s: %s", res.name, res.exception.msg);
			}
			else
			{
				writefln("[O] %s", res.name);
			}
		}
	}
	if (subpkgTests.length > 0)
	{
		writeln("##### Test Summary of SubPackages");
		writefln("Failed:    %s / %s", subpkgTests.count!(a => a.executed && a.exception), subpkgTests.length);
		writefln("Succeeded: %s / %s", subpkgTests.count!(a => a.executed && !a.exception), subpkgTests.length);
		writefln("Skipped:   %s / %s", subpkgTests.count!(a => !a.executed), subpkgTests.length);
		foreach (res; subpkgTests)
		{
			if (!res.executed)
				continue;
			if (res.exception)
			{
				writefln("[X] %s: %s", res.name, res.exception.msg);
			}
			else
			{
				writefln("[O] %s", res.name);
			}
		}
	}
	
}


///
void createArchive()
{
	import std.file;
	if (!"build".exists)
		return;
	auto archiveName = format!"%s-%s-%s-%s%s"(
		config.projectName, config.refName, config.os, config.arch, config.archiveSuffix);
	scope (success)
		writeln("::set-output name=ARCNAME::", archiveName);
	version (Windows)
	{
		auto zip = new ZipArchive;
		foreach (de; dirEntries("build", SpanMode.depth))
		{
			if (de.isDir)
				continue;
			auto m = new ArchiveMember;
			m.expandedData = cast(ubyte[])std.file.read(de.name);
			m.name = de.name.absolutePath.relativePath(absolutePath("build"));
			m.time = de.name.timeLastModified();
			m.fileAttributes = de.name.getAttributes();
			m.compressionMethod = CompressionMethod.deflate;
			zip.addMember(m);
		}
		std.file.write(archiveName, zip.build());
	}
	else
	{
		string abs(string file, string base)
		{
			return file.absolutePath.relativePath(absolutePath(base));
		}
		void mv(string from, string to)
		{
			if (from.isDir)
				return;
			if (!to.dirName.exists)
				mkdirRecurse(to.dirName);
			std.file.rename(from, to);
		}
		mv("build/gendoc", "archive-tmp/bin/gendoc");
		foreach (de; dirEntries("build/ddoc", SpanMode.depth))
			mv(de.name, buildPath("archive-tmp/etc/.gendoc/ddoc", abs(de.name, "build/ddoc")));
		foreach (de; dirEntries("build/source_docs", SpanMode.depth))
			mv(de.name, buildPath("archive-tmp/etc/.gendoc/docs", abs(de.name, "build/source_docs")));
		exec(["tar", "cvfz", buildPath("..", archiveName), "-C", "."]
			~ dirEntries("archive-tmp", "*", SpanMode.shallow)
				.map!(de => abs(de.name, "archive-tmp")).array, "archive-tmp");
	}
}

///
void exec(string[] args, string workDir = null, string[string] env = null)
{
	import std.process, std.stdio;
	writefln!"> %-(%-s %)"(args);
	auto pid = spawnProcess(args, env, std.process.Config.none, workDir ? workDir : ".");
	auto res = pid.wait();
	enforce(res == 0, format!"Execution was failed[code=%d]."(res));
}
///
string cmd(string[] args, string workDir = null, string[string] env = null)
{
	import std.process;
	auto res = execute(args, env, std.process.Config.none, size_t.max, workDir);
	enforce(res.status == 0, format!"Execution was failed[code=%d]."(res.status));
	return res.output;
}

///
string getRefName()
{
	auto ghref = environment.get("GITHUB_REF");
	enum keyBranche = "refs/heads/";
	enum keyTag = "refs/heads/";
	enum keyPull = "refs/heads/";
	if (ghref.startsWith(keyBranche))
		return ghref[keyBranche.length..$];
	if (ghref.startsWith(keyTag))
		return ghref[keyTag.length..$];
	if (ghref.startsWith(keyPull))
		return "pr" ~ ghref[keyPull.length..$];
	return cmd(["git", "describe", "--tags", "--always"]).chomp;
}

///
string[] getPaths(string[string] env)
{
	version (Windows)
		return env.get("Path", env.get("PATH", env.get("path", null))).split(";");
	else
		return env.get("PATH", null).split(":");
}
///
string[] getPaths()
{
	version (Windows)
		return environment.get("Path").split(";");
	else
		return environment.get("PATH").split(":");
}

///
void setPaths(string[string] env, string[] paths)
{
	version (Windows)
		env["Path"] = paths.join(";");
	else
		env["PATH"] = paths.join(":");
}

///
void setPaths(string[] paths)
{
	version (Windows)
		environment["Path"] = paths.join(";");
	else
		environment["PATH"] = paths.join(":");
}

///
string searchPath(string name, string[] dirs = null)
{
	if (name.length == 0)
		return name;
	if (name.isAbsolute())
		return name;
	
	foreach (dir; dirs.chain(getPaths()))
	{
		version (Windows)
			auto bin = dir.buildPath(name).setExtension(".exe");
		else
			auto bin = dir.buildPath(name);
		if (bin.exists)
			return bin;
	}
	return name;
}

///
string searchDCompiler()
{
	auto compiler = config.compiler;
	if (compiler.absolutePath.exists)
		return compiler.absolutePath;
	compiler = compiler.searchPath();
	if (compiler.exists)
		return compiler;
	
	auto dc = searchPath(environment.get("DC"));
	if (dc.exists)
		return dc;
	
	auto dmd = searchPath(environment.get("DMD"));
	if (dmd.exists)
		return dmd;
	
	return "dmd";
}
