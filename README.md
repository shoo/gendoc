# gendoc

[![GitHub tag](https://img.shields.io/github/tag/shoo/gendoc.svg?maxAge=86400)](#)
[![CI Status](https://github.com/shoo/gendoc/workflows/master/badge.svg)](https://github.com/shoo/gendoc/actions?query=workflow%3A%22master%22)
[![codecov](https://codecov.io/gh/shoo/gendoc/branch/master/graph/badge.svg)](https://codecov.io/gh/shoo/gendoc)

gendoc is a tool for generating documents using the built-in document generation feature of D language compilers.

This is forked from [dxml/gendocs.d](https://github.com/jmdavis/dxml/blob/master/gendocs.d), and file search and specification of compilation options based on dub package information are added.

# Sample Pages

- Default style: http://shoo.github.io/gendoc
- Candydoc: http://shoo.github.io/gendoc/candydoc

# How to build

```sh
dub build
```

# How to use

To use gendoc, move current directory to the dub project and enter the following command:

```sh
gendoc
```

Or, can be run using dub package manager:

```sh
dub run gendoc
```

You can apply CanDyDoc style:

```sh
dub run gendoc:candydoc
```

In addition, to import template document styles using gendoc's dub package:

```sh
dub build gendoc -c=init
```

CanDyDoc:

```sh
dub build gendoc:candydoc -c=init
```

When you want to know the detail of usage, you can use the help command to display help messages:

```
gendoc -h
```

| .  | Options            | Type       | Desctiption                                              | Default                     |
|---:|-------------------:|:-----------|:---------------------------------------------------------|:----------------------------|
| -a |             --arch | string     | Archtecture of dub project.                              | x86_64                      |
| -b |            --build | string     | Build type of dub project.                               | debug                       |
| -c |           --config | string     | Configuration of dub project.                            |                             |
|    |         --compiler | string     | Specifies the compiler binary to use (can be a path).    | dmd                         |
|    |      --gendocDdocs | string\[\] | Ddoc sources of document files.                          | \["ddoc"\] if exists        |
|    | --gendocSourceDocs | string\[\] | Source of document files.                                | \["source_docs"\] if exists |
|    |     --gendocTarget | string     | Target directory of generated documents.                 | docs                        |
|    |     --gendocConfig | string     | Configuration file of gendoc.                            | "gendoc.json" if exists     |
|    |             --root | string     | Path to operate in instead of the current working dir.   | .                           |
|    |       --singleFile | bool       | Single file generation mode.                             | false                       |
| -v |          --varbose | bool       | Display varbose messages.                                | false                       |
| -q |            --quiet | bool       | Non-display messages.                                    | false                       |
| -h |             --help | bool       | This help information.                                   | false                       |

# Settings
You can change the settings of the directory where the `*.ddoc`, `*.dd`, `*.html` etc. source files are placed according to your preference.
The directory is searched using the following procedure:

Search settings in the following order(Top item in list has highest priority):

1. Command line argument specifiered
    1. `(--gendocConfig=<jsonfile>)`
    2. `(--gendocConfig=<directory>)/settings.json`
    3. `(--gendocConfig=<directory>)/gendoc.json`
    4. `(--gendocConfig=<directory>)/ddoc` and `(--gendocConfig=<directory>)/docs`
    5. `(--gendocConfig=<directory>)/ddoc` and `(--gendocConfig=<directory>)/source_docs`
2. Search current directory
    1. `./.gendoc.json`
    2. `./gendoc.json`
    3. `./.gendoc/settings.json`
    4. `./.gendoc/gendoc.json`
    5. `./.gendoc/ddoc` and `./.gendoc/docs`
    6. `./.gendoc/ddoc` and `./.gendoc/source_docs`
    7. `./ddoc` and `./source_docs` * (docs may be a target)
3. Search `$(HOME)` (POSIX) or `%USERPROFILE` (Windows) directory
    1. `$(HOME)/.gendoc.json`
    2. `$(HOME)/gendoc.json`
    3. `$(HOME)/.gendoc/settings.json`
    4. `$(HOME)/.gendoc/gendoc.json`
    5. `$(HOME)/.gendoc/ddoc` and `$(HOME)/.gendoc/docs`
    6. `$(HOME)/.gendoc/ddoc` and `$(HOME)/.gendoc/source_docs`
4. Search `(gendocExeDir)` directory
    1. `(gendocExeDir)/.gendoc.json`
    2. `(gendocExeDir)/gendoc.json`
    3. `(gendocExeDir)/.gendoc/settings.json`
    4. `(gendocExeDir)/.gendoc/gendoc.json`
    5. `(gendocExeDir)/.gendoc/ddoc` and `(gendocExeDir)/.gendoc/docs`
    6. `(gendocExeDir)/.gendoc/ddoc` and `(gendocExeDir)/.gendoc/source_docs`
    7. `(gendocExeDir)/ddoc` and `(gendocExeDir)/source_docs` * (docs may be a gendoc's document target)
5. Search `(gendocExeDir)/../etc` directory
    1. `(gendocExeDir)/../etc/.gendoc.json`
    2. `(gendocExeDir)/../etc/gendoc.json`
    3. `(gendocExeDir)/../etc/.gendoc/settings.json`
    4. `(gendocExeDir)/../etc/.gendoc/gendoc.json`
    5. `(gendocExeDir)/../etc/.gendoc/ddoc` and `(gendocExeDir)/../etc/.gendoc/docs`
    6. `(gendocExeDir)/../etc/.gendoc/ddoc` and `(gendocExeDir)/../etc/.gendoc/source_docs`

## gendoc.json / .gendoc/settings.json
You can change the gendoc settings by adding `gendoc.json` or `.gendoc/settings.json` to the dub package.

Example:

```json
{
    "//": "Same to --gendocDdocs option. (Run-time arguments are preferred.)",
    "//": "Specify a directory path where the relative path from the root of dub package.",
    "//": "The directory where the `*.ddoc` files to be specified in the compilation",
    "//": "argument when generating HTML are stored.",
    "ddocs": [ "ddocs" ],
    
    "//": "Same to --gendocSourceDocs option. (Run-time arguments are preferred.)",
    "//": "Specify a directories path where the relative path from the root of dub package.",
    "//": "`*.dd` files are compiled and other files are simply copied.",
    "sourceDocs": [ "source_docs" ],
    
    "//": "Same to --gendocTarget option. (Run-time arguments are preferred.)",
    "//": "Specify a directory path where the relative path from the root of dub package.",
    "//": "The resulting HTML is generated in this directory.",
    "target": "docs",
    
    "//": "Specify names there exactly match the path.",
    "//": "For the path, specify the relative path from the first one of the",
    "//": "importPaths of dub settings.",
    "//": "Matched files are excluded from document generation.",
    "excludePaths": ["src/_internal", "src/ut.d"],
    
    "//": "Specify regex patterns there match the path.",
    "//": "For the path, specify the relative path from the first one of the",
    "//": "importPaths of dub settings.",
    "//": "Matched files are excluded from document generation.",
    "excludePatterns": [
        "(?:(?<=/)|^)\\.[^/.]+$",
        "(?:(?<=[^/]+/)|^)_[^/]+$",
        "(?:(?<=[^/]+/)|^)internal(?:\\.d)?$"
    ],
    
    "//": "Specify a name that exactly matches the full dub package name.",
    "//": "Matched packages are excluded from document generation.",
    "excludePackages": ["gendoc:example", "gendoc:test"],
    
    "//": "Specify regex patterns there match the full dub package name.",
    "//": "Matched packages are excluded from document generation.",
    "excludePackagePatterns": [
        "(?:(?<=[^:]+/)|^)_[^/]+$",
        ":docs?$"
    ],
    
    "//": "Specify pair of key and regex pattern that exactly matches the full dub package name.",
    "//": "Matched dub packages are combinined into key name. The dub packages also includes sub-packages.",
    "combinedDubPackagePatterns": {
      "gendoc": [
          "^gendoc(?::.+)?$"
      ]
    }
}
```

For `ddocs`, `sourceDocs` and `target`, the following variables can be used:

| Variables          | Descriptions                         |
|:------------------:|:-------------------------------------|
| `${GENDOC_DIR}`    | gendoc binary's parent directory.    |
| `${GENDOC_SD_DIR}` | gendoc default source_docs directory. `${GENDOC_DIR}/source_docs` is checked first, then `${GENDOC_DIR}/../etc/.gendoc/docs` is checked, and the existing is selected. |
| `${GENDOC_DD_DIR}` | gendoc default ddoc directory. `${GENDOC_DIR}/ddoc` is checked first, then `${GENDOC_DIR}/../etc/.gendoc/ddoc` is checked, and the existing is selected.|
| `${PROJECT_DIR}`   | Project root directory (which has dub.json/dub.sdl) |
| `${WORK_DIR}`      | Current working directory.           |

# mustache
You can use [mustache](http://mustache.github.io/) as a way to embed information that is difficult to manage manually, such as a list of modules, in a ddoc file.
Save it with the extension `*.ddoc.mustache`, `*.dd.mustache`, such as `module_list.ddoc.mustache`.

```mustache
MODULE_MENU={{# dub_pkg_info }}
$(MENU_DUBPKG {{ name }}, {{ version }},
  {{# children }}{
    "file": "_module_info",
    "map": {
      "tag_pkg":"MENU_PKG",
      "tag_mod":"MENU_MOD"
    }
  }{{/ children }}
)
{{/ dub_pkg_info }}
```

Available tags are as below:



| Location                     |    Tag name      |    Type      | Description                                                                  |
|:-----------------------------|:----------------:|:------------:|:-----------------------------------------------------------------------------|
| 1. (root of package)         | name             | Variables    | Dub package name.                                                            |
| 2. (root of package)         | version          | Variables    | Dub package version.                                                         |
| 3. (root of package)         | dir              | Variables    | Path of dub package directory.                                               |
| 4. (root of package)         | command          | Lambdas      | Execute command and store result.                                            |
| 5. (root of package)         | rdmd             | Lambdas      | Execute dlang code with rdmd --eval and store the result to standard output. |
| 6. (root of package)         | environemnt      | Lambdas      | Expand and store environment variables.                                      |
| 7. (root of package)         | ***children***   | Lambdas      | The package and module information included in the dub package is embedded.  |
|   7.1. children              | is_package       | Section      | Section used when the current element is a package.                          |
|     7.1.1. is_package        | has_package_d    | Section      | Section used when the current package has a package.d                        |
|       7.1.1.1. has_package_d | name             | Variables    | Name of package. (`foo/bar/package.d` -> `bar`)                              |
|       7.1.1.2. has_package_d | page_url         | Variables    | Url of the document of package.d                                             |
|       7.1.1.3. has_package_d | dub_package_name | Variables    | Name of dub package.                                                         |
|       7.1.1.3. has_package_d | package_name     | Variables    | Name of package. (`foo/bar/package.d` -> `foo.bar`)                          |
|       7.1.1.4. has_package_d | module_name      | Variables    | Name of module.  (`foo/bar/package.d` -> (none))                             |
|       7.1.1.5. has_package_d | full_module_name | Variables    | Fullname of module.  (`foo/bar/package.d` -> `foo.bar`)                      |
|       7.1.1.6. has_package_d | command          | Lambdas      | Execute command and store result.                                            |
|       7.1.1.7. has_package_d | rdmd             | Lambdas      | Execute dlang code with rdmd --eval and store the result to standard output. |
|       7.1.1.8. has_package_d | environemnt      | Lambdas      | Expand and store environment variables.                                      |
|       7.1.1.9. has_package_d | ***children***   | Lambdas      | The package and module information included in the package is embedded.      |
|     7.1.2. is_package        | no_package_d     | Section      | Section used when the current package has not a package.d                    |
|       7.1.2.1. no_package_d  | name             | Variables    | Name of package(only bottom name). (`foo/bar` -> `bar`)                      |
|       7.1.2.2. no_package_d  | dub_package_name | Variables    | Name of dub package.                                                         |
|       7.1.2.3. no_package_d  | package_name     | Variables    | Name of package. (`foo/bar` -> `foo.bar`)                                    |
|       7.1.1.4. no_package_d  | command          | Lambdas      | Execute command and store result.                                            |
|       7.1.1.5. no_package_d  | rdmd             | Lambdas      | Execute dlang code with rdmd --eval and store the result to standard output. |
|       7.1.1.6. no_package_d  | environemnt      | Lambdas      | Expand and store environment variables.                                      |
|       7.1.2.7. no_package_d  | ***children***   | Lambdas      | The package and module information included in the package is embedded.      |
|   7.2. children              | is_module        | Section      | Section used when the current element is a module.                           |
|     7.2.1. is_module         | name             | Variables    | Name of package. (`foo/bar/hoge.d` -> `hoge`)                                |
|     7.2.2. is_module         | page_url         | Variables    | Url of the document of module.                                               |
|     7.2.3. is_module         | package_name     | Variables    | Name of package. (`foo/bar/hoge.d` -> `foo.bar`)                             |
|     7.2.4. is_module         | dub_package_name | Variables    | Name of dub package.                                                         |
|     7.2.5. is_module         | module_name      | Variables    | Name of module.  (`foo/bar/hoge.d` -> `hoge`)                                |
|     7.2.6. is_module         | full_module_name | Variables    | Fullname of module.  (`foo/bar/package.d` -> foo.bar.hoge)                   |
|     7.2.7. is_module         | command          | Lambdas      | Execute command and store result.                                            |
|     7.2.8. is_module         | rdmd             | Lambdas      | Execute dlang code with rdmd --eval and store the result to standard output. |
|     7.2.9. is_module         | environemnt      | Lambdas      | Expand and store environment variables.                                      |

### **{{ children }}**
As it appears above, `{{# children }} {{/ children }}` is special.
Recursive embedding is done to represent the package tree structure.
At that time, it is possible to change the contents with the information described inside. The information is in JSON format or mustache format.

- If the literal start token of `{`, `[`, `"` is included in the same line with `{{# children }}` start tag, it is treated as JSON format.
  - In the case of JSON format, it is possible to take one of three types: string, array, or object.
    - string: Treat the string as "mustache".    
      Example:
      ```
      {{# children }}"foo{{ xxx }}bar"{{/ children }}
      ```
    - array: Interpret as like command line arguments.
      |  Options           | Type             | Description                                   |
      |:-------------------|:----------------:|:----------------------------------------------|
      | (first argumenet)  | string           | file name or path of mustache                 |
      | `-i` / `--import`  | string\[\]       | search path of mustache file (first argument) |
      | `-m` / `--map`     | string\[stirng\] | define additional variable                    |
      | `-u` / `--use`     | string\[\]       | usable section                                |
      Example:
      ```
      {{# children }}[
        "_module_info",
        "-m=tag_pkg=INFO_PKG",
        "-m=tag_mod=INFO_MOD"
      ]{{/ children }}
      ```
    - object: Interpret the data structure.
    
      |  Field        | Type             | Description                               |
      |:--------------|:----------------:|:------------------------------------------|
      | `file`        | string           | file name or path of mustache             |
      | `imports`     | string\[\]       | search path of mustache file (file field) |
      | `contents`    | string           | mustache (File field takes precedence)    |
      | `map`         | string\[stirng\] | define additional variable                |
      | `useSections` | string\[\]       | usable section                            |
      Example:
      ```
      {{# children }}{
        "file": "_module_info",
        "map": {
          "tag_pkg":"INFO_PKG",
          "tag_mod":"INFO_MOD"
        }
      }{{/ children }}
      ```
  - If the file is specified above, rendering will be performed with the target file.
- If none of the above, JSON parsing fails, or a muctache string is specified even in JSON format, treat it as a mustache string.
  - If a mustache-style string is specified in either way, the string is rendered directly as mustache instead of a file.

### **{{ rdmd }}** and **{{ command }}**
`{{# rdmd}} {{/ rdmd}}` and `{{# command}} {{/ command}}` are also special. The result is replaced with the contents of stdout and stderr after the program is executed.

**{{ rdmd }}** executes the string contained inside as dlang source code with `rdmd --eval`
```
{{# rdmd }}
  writeln("Hello, world!");
{{/ rdmd }}
```

**{{ command }}** executes the contained string as a single command line. Line breaks are interpreted as delimiters for arguments. In the case of a line break delimited, invoke the process directly. In the case of one line, the command is invoked in the shell.
```
{{# command }}
  dmd
  -ofbuild directory/foo
  main.d
{{/ command }} {{# command}}echo "xxx"{{/ command}}
```

In either case of **{{ rdmd }}** or **{{ command }}**, the invoked program can interact with gendoc through stdio.

gendoc responds to requests from the launched guest program.
One request or response communicates via a JSON object without lines.
Guest program requests are passed line by line to the stderr.
gendoc responds to requests with one line.
The request starts with `::gendoc-request::`, followed by a JSON string.
```
::gendoc-request::{ "type": "ReqEcho", "value": {"msg": "test"} }
```
The response type corresponds to the request type.

| Request Type          | Response Type        |
|:----------------------|:---------------------|
| [ReqEcho](https://shoo.github.io/gendoc/gendoc--gendoc.cmdpipe.html#.ReqEcho)           | [ResEcho](https://shoo.github.io/gendoc/gendoc--gendoc.cmdpipe.html#.ResEcho), [ResErr](https://shoo.github.io/gendoc/gendoc--gendoc.cmdpipe.html#.ResErr)  |
| [ReqInfo](https://shoo.github.io/gendoc/gendoc--gendoc.cmdpipe.html#.ReqInfo)           | [ResInfo](https://shoo.github.io/gendoc/gendoc--gendoc.cmdpipe.html#.ResInfo), [ResErr](https://shoo.github.io/gendoc/gendoc--gendoc.cmdpipe.html#.ResErr)  |

Each piece of information is composed of a JSON object composed of `type` and `value` as follows, and the `value` includes a payload.
The following examples include line breaks and indents for readability, but do not break lines in the data actually used.

```
{
 "type":  "ReqInfo",
 "value": { }
}
```

# License
gendoc is licensed by [Boost Software License 1.0](LICENSE)

gendoc depends on:

- [dub](https://code.dlang.org/packages/dub)                    ([MIT](https://github.com/dlang/dub/blob/master/LICENSE))
- [mustache-d](https://code.dlang.org/packages/mustache-d)      ([BSL-1.0](https://github.com/repeatedly/mustache-d/blob/master/dub.json))

Generated html by dendoc depends on:

- [jQuery](https://jquery.com/) (CDN)                           ([MIT](https://jquery.org/license/))
