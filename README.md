# code_static_analyzer plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-code_static_analyzer)

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-code_static_analyzer`, add it to your project by running:

```bash
fastlane add_plugin code_static_analyzer
```

## About code_static_analyzer

This plugins runs different Static Analyzers for checking your code on warnings, copypaste, syntax, etc and generate reports. 
Each analyzer in this plugin generate separate report `codeAnalysResult_<name of analyzer>.xml` and 
save result status in shared values `<NAME>_ANALYZER_STATUS`: 0 - code is clear, any other value - code include warnings/errors.
Finally you can check plugin return value (true='code is clear'/false) to decide what to do next. <br />
All reports are generated in JUnit format for easier start-up at the CI servers.<br />
This plugin can be used in pair with CI static code analysis plugins. Check out the `Using CI plugins` section.

## Important
- You can configure rubocop analyzer by creating configuration file `.rubocop.yml` in your project (more about rubocop configuration http://rubocop.readthedocs.io/en/latest/cops/)
- All paths should be relative to work directory. 

### Specific for copy paste analyzer (CPD)
- PMD have to be installed on your machine (http://pmd.sourceforge.net/snapshot/usage/installing.html)
- [!]Pay attention on language parameter: if your code language is available in supported list you have to set this parameter.

## Actions

`code_static_analyzer` - runs all configured analyzers together (Copy paste analyzer always runs).<br />
You may run each analyzer separate:<br />
`cpd_analyzer` - finds copy paste in code (based on CPD from PMD package) <br />
`ruby_analyzer` - checks your ruby files. Some offenses can be auto-corrected (if you want to save the changes do it manually) <br />
`warning_analyzer` - this analyzer uses Xcode built-in analyzer mainly to detect warnings<br /> 

## Reference and Example

### `code_static_analyzer` (Run all analyzers)

````ruby
# minimum configuration
code_static_analyzer(
      analyzers: 'all',
      cpd_language: 'objectivec',
      xcode_project_name: 'path/to/TestProject',
    )
# full configuration
code_static_analyzer(
      analyzers: 'all',
      result_dir: 'result directory',
      cpd_tokens: '150',
      cpd_language: 'objectivec',
      cpd_files_to_inspect: 'path/to/myFiles/', # or list %w('path/to/myFiles/' 'path/to/testFiles/')
      cpd_files_to_exclude: 'Pods', # or list %w('Pods' 'path/to/filesNotToInspect/file1.m' 'path/to/filesNotToInspect/in/dir')
      xcode_project_name: 'path/to/TestProject',
      xcode_workspace_name: 'path/to/testWorkspace',
      xcode_targets: ['TPClientTarget','TPServerTarget'],
      ruby_files: 'fastlane/Fastfile',
      disable_junit: 'all' # don't create any results in JUnit format
    )
````
Parameter | Description
--------- | -----------
`analyzers` | List of analysers you want to run.  Supported analyzers: "xcodeWar", "rubocop", "CPD", "all"
`result_dir` | *(optional)* Directory's name for storing  analysis results.
`cpd_tokens` | *(optional)* The min number of words in code that is detected as copy paste.<br />Default value: 100
`cpd_language` | *(optional)* Language used in files that will be inspected on copy paste.<br />Supported analyzers: ['python', 'objectivec', 'jsp', 'ecmascript', 'fortran', 'cpp', 'ruby', 'php', 'java', 'matlab', 'scala', 'plsql', 'go', 'cs']. If you need any other language just don't set this parameter. 
`cpd_files_to_inspect` | *(optional)* List of paths (relative to work directory) to files/directories to be inspected on copy paste. 
`cpd_files_to_exclude` | *(optional)* List of paths (relative to work directory) to files/directories not to be inspected on copy paste
`xcode_project_name` | *(required if use warning analyzer)* Xcode project name in work directory
`xcode_workspace_name`| *(optional)* Xcode workspace name in work directory. Set it if you use different project & workspace names
`xcode_targets` | *(optional)* List of Xcode targets to inspect. By default used all targets which are available in project
`ruby_files` | *(optional)* List of paths to ruby files to be inspected 
`disable_junit` | *(optional)* List of analysers for which you want to disable results in JUnit format.<br />Supported analyzers: "xcodeWar", "rubocop", "CPD", "all"<br />By default all results will be created in JUnit format.

### `code_static_analyzer` other examples (full configuration):
CPD:
````ruby
code_static_analyzer(
      analyzers: 'cpd',
      result_dir: 'result directory',
      cpd_tokens: '150',
      cpd_language: 'objectivec',
      cpd_files_to_inspect: %w('path/to/myFiles/' 'path/to/testFiles/'),
      cpd_files_to_exclude: %w('Pods' 'ThirdParty')
    )
````
CPD + ruby:
````ruby
code_static_analyzer(
      analyzers: 'rubocop',
      result_dir: 'result directory',
      cpd_tokens: '150',
      cpd_language: 'objectivec',
      cpd_files_to_inspect: %w('path/to/myFiles/' 'path/to/testFiles/'),
      cpd_files_to_exclude: %w('Pods' 'ThirdParty'),
      ruby_files: 'fastlane/Fastfile',
      disable_junit: 'CPD' # results of rubocop analyzer - in JUnit format, CPD analyzer - not in JUnit format
    )
````
CPD + Xcode project warnings:
````ruby
code_static_analyzer(
      analyzers: 'xcodewar',
      result_dir: 'result directory',
      cpd_tokens: '150',
      cpd_language: 'objectivec',
      cpd_files_to_inspect: %w('path/to/myFiles/' 'path/to/testFiles/'),
      cpd_files_to_exclude: %w('Pods' 'ThirdParty'),
      xcode_project_name: 'path/to/TestProject',
      xcode_workspace_name: 'path/to/testWorkspace',
      xcode_targets: ['TPClientTarget','TPServerTarget'],
    )
````
## Using CI plugins

If you want to use CI static code analysis plugins pay attention on type of file which they use. 
Commonly CI static code analysis plugins don't scan files in JUnit format, so you need to `disable usage of results in JUnit format` (especially for ruby analyzer).
After that each analyzer in this plugin will generate separate report(s):
CPD analyzer - `cpd.xml`; Ruby analyzer - `ruby.log`; Warning analyzer - `warnings_<target name>.log`

## Issues and Feedback

- In some cases CPD can't recognize patterns in file/dir paths like `path/to/files/*.m`
(about path you may read in [CPD documentation](http://pmd.sourceforge.net/snapshot/usage/cpd-usage.html)).<br />
For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using `fastlane` Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About `fastlane`

`fastlane` is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
