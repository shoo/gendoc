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
|-v|         --varbose | bool     | Display varbose messages.                                | false                       |
|-q|           --quiet | bool     | Non-display messages.                                    | false                       |
|-h|            --help | bool     | This help information.                                   | false                       |

# gendoc.json
You can change the gendoc settings by adding gendoc.json to the dub package.

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
        "(?:(?<=/)|^)\\.[^/]+$",
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

# License
gendoc is licensed by [Boost Software License 1.0](LICENSE)
