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

|  | options           | Type     | desctiption                                              | default                     |
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
