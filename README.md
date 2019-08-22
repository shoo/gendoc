# gendoc

[![GitHub tag](https://img.shields.io/github/tag/shoo/gendoc.svg?maxAge=86400)](#) [![CI Status](https://travis-ci.com/shoo/gendoc.svg)](https://travis-ci.com/shoo/gendoc)

gendoc is a tool for generating documents using the built-in document generation feature of D language compilers.

This is forked from [dxml/gendocs.d](https://github.com/jmdavis/dxml/blob/master/gendocs.d), and file search and specification of compilation options based on dub package information are added.



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

In addition, to import template document styles using gendoc's dub package:

```sh
dub build gendoc -c=init
```

When you want to know the detail of usage, you can use the help command to display help messages:

```
gendoc -h
```

|  | Options           | Type     | Desctiption                                              | Default                     |
|-:|------------------:|:---------|:---------------------------------------------------------|:----------------------------|
|-a|            --arch | string   | Archtecture of dub project.                              | x86_64                      |
|-b|           --build | string   | Build type of dub project.                               | debug                       |
|-c|          --config | string   | Configuration of dub project.                            |                             |
|  |        --compiler | string   | Specifies the compiler binary to use (can be a path).    | dmd                         |
|  |     --gendocDdocs | string[] | Ddoc sources of document files.                          | \["ddoc"\] if exists        |
|  |--gendocSourceDocs | string[] | Source of document files.                                | \["source_docs"\] if exists |
|  |    --gendocTarget | string   | Target directory of generated documents.                 | docs                        |
|  |    --gendocConfig | string   | Configuration file of gendoc.                            | "gendoc.json" if exists     |
|  |            --root | string   | Path to operate in instead of the current working dir.   | .                           |
|  |      --singleFile | bool     | Single file generation mode.                             | false                       |
|-v|         --varbose | bool     | Display varbose messages.                                | false                       |
|-q|           --quiet | bool     | Non-display messages.                                    | false                       |
|-h|            --help | bool     | This help information.                                   | false                       |

# Settings
You can change the settings of the directory where the `*.ddoc`, `*.dd`, `*.html` etc. source files are placed according to your preference.
The directory is searched using the following procedure:

Search settings in the following order(Top item in list has highest priority):

1. `(--gendocConfig=<jsonfile>)`
2. `(--gendocConfig=<directory>)/settings.json`
3. `(--gendocConfig=<directory>)/gendoc.json`
4. `(--gendocConfig=<directory>)/ddoc` and `(--gendocConfig=<directory>)/docs`
5. `(--gendocConfig=<directory>)/ddoc` and `(--gendocConfig=<directory>)/source_docs`
6. `./gendoc.json`
7. `./.gendoc/settings.json`
8. `./.gendoc/gendoc.json`
9. `./.gendoc/ddoc` and `./.gendoc/docs`
10. `./.gendoc/ddoc` and `./.gendoc/source_docs`
11. `./ddoc` and `./source_docs`
12. `(gendocExePath)/gendoc.json`
13. `(gendocExePath)/.gendoc/settings.json`
14. `(gendocExePath)/.gendoc/gendoc.json`
15. `(gendocExePath)/.gendoc/ddoc` and `(gendocExePath)/.gendoc/docs`
16. `(gendocExePath)/.gendoc/ddoc` and `(gendocExePath)/.gendoc/source_docs`
17. `(gendocExePath)/ddoc` and `(gendocExePath)/source_docs`

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
    "ddocs": "docs",
    
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
    ]
}
```

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
| 4. (root of package)         | ***children***   | Lambdas      | The package and module information included in the dub package is embedded.  |
|   4.1. children              | is_package       | Section      | Section used when the current element is a package.                          |
|     4.1.1. is_package        | has_package_d    | Section      | Section used when the current package has a package.d                        |
|       4.1.1.1. has_package_d | name             | Variables    | Name of package. (`foo/bar/package.d` -> `bar`)                              |
|       4.1.1.2. has_package_d | page_url         | Variables    | Url of the document of package.d                                             |
|       4.1.1.3. has_package_d | dub_package_name | Variables    | Name of dub package.                                                         |
|       4.1.1.3. has_package_d | package_name     | Variables    | Name of package. (`foo/bar/package.d` -> `foo.bar`)                          |
|       4.1.1.4. has_package_d | module_name      | Variables    | Name of module.  (`foo/bar/package.d` -> (none))                             |
|       4.1.1.5. has_package_d | full_module_name | Variables    | Fullname of module.  (`foo/bar/package.d` -> `foo.bar`)                      |
|       4.1.1.6. has_package_d | ***children***   | Lambdas      | The package and module information included in the package is embedded.      |
|     4.1.2. is_package        | no_package_d     | Section      | Section used when the current package has not a package.d                    |
|       4.1.2.1. no_package_d  | name             | Variables    | Name of package(only bottom name). (`foo/bar` -> `bar`)                      |
|       4.1.2.2. no_package_d  | dub_package_name | Variables    | Name of dub package.                                                         |
|       4.1.2.3. no_package_d  | package_name     | Variables    | Name of package. (`foo/bar` -> `foo.bar`)                                    |
|       4.1.2.4. no_package_d  | ***children***   | Lambdas      | The package and module information included in the package is embedded.      |
|   4.2. children              | is_module        | Section      | Section used when the current element is a module.                           |
|     4.2.1. is_module         | name             | Variables    | Name of package. (`foo/bar/hoge.d` -> `hoge`)                                |
|     4.2.2. is_module         | page_url         | Variables    | Url of the document of module.                                               |
|     4.2.3. is_module         | package_name     | Variables    | Name of package. (`foo/bar/hoge.d` -> `foo.bar`)                             |
|     4.2.4. is_module         | dub_package_name | Variables    | Name of dub package.                                                         |
|     4.2.5. is_module         | module_name      | Variables    | Name of module.  (`foo/bar/hoge.d` -> `hoge`)                                |
|     4.2.6. is_module         | full_module_name | Variables    | Fullname of module.  (`foo/bar/package.d` -> foo.bar.hoge)                   |

As it appears above, `{{# children }} {{/ children }}` is special.
Recursive embedding is done to represent the package tree structure.
At that time, it is possible to change the contents with the information described inside. The information is in JSON format or mustache format.

- If the literal start token of `{`, `[`, `"` is included in the same line with `{{# children }}` start tag, it is treated as JSON format.
  - In the case of JSON format, it is possible to take one of three types: string, array, or object.
    - string: treat the string as "mustache".
    - array: Interpret as command line.
    
      |  Options           | Type             | Description                                   |
      |:-------------------|:----------------:|:----------------------------------------------|
      | (first argumenet)  | string           | file name or path of mustache                 |
      | `-i` \| `--import` | string\[\]       | search path of mustache file (first argument) |
      | `-m` \| `--map`    | string\[stirng\] | define additional variable                    |
      | `-u` \| `--use`    | string\[\]       | usable section                                |
    
    - object: Interpret the data structure.
    
      |  Field        | Type             | Description                               |
      |:--------------|:----------------:|:------------------------------------------|
      | `file`        | string           | file name or path of mustache             |
      | `imports`     | string\[stirng\] | search path of mustache file (file field) |
      | `contents`    | string           | mustache (File field takes precedence)    |
      | `map`         | string\[stirng\] | define additional variable                |
      | `useSections` | string\[\]       | usable section                            |
  
  - If the file is specified above, rendering will be performed with the target file.
- If none of the above, JSON parsing fails, or a muctache string is specified even in JSON format, treat it as a mustache string.
  - If a mustache-style string is specified in either way, the string is rendered directly as mustache instead of a file.


# License
gendoc is licensed by [Boost Software License 1.0](LICENSE)

gendoc depends on:

- [dub](https://code.dlang.org/packages/dub)                    ([MIT](https://github.com/dlang/dub/blob/master/LICENSE))
- [mustache-d](https://code.dlang.org/packages/mustache-d)      ([BSL-1.0](https://github.com/repeatedly/mustache-d/blob/master/dub.json))

Generated html by dendoc depends on:

- [jQuery](https://jquery.com/) (CDN)                           ([MIT](https://jquery.org/license/))
