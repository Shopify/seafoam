# Unreleased

New Features:

Bug Fixes:

* Fixed an invalid method call in `bgv2json` (#82, @nirvdrum).
* Fixed a character escape issue with the Mermaid formatter that could result in invalid syntax (#87, @nirvdrum).

Changes:

* Support running with GraalVM 24.0+ (#86, @nirvdrum).

# 0.15

New Features:

* Added a new `--no-simplify` option to disable Seafoam’s graph simplification (#66, @chrisseaton).
* Updated the synthetic Truffle argument nodes to use our packed argument name rather than an index offset (e.g., `T(5)` -> `T(SELF)` and `T(8)` -> `T(args[0])`) (#72, @nirvdrum).

Bug Fixes:

* Fixed issue with Truffle arg simplification where some edges could fail to simplify (#69, @nirvdrum).
* Fixed validation of custom render options (#70, @nirvdrum).

Changes:

* Run the various graph transformation passes in the `describe` command as well (#66, @chrisseaton).
* Removed hidden nodes from the `describe` command output (#66, @chrisseaton).
* Improved the `describe` command output to ignore hidden nodes (@chrisseaton).
* Added more “triggers” to detect if we’re looking at Graal or Truffle graphs (as opposed to regular JVM graphs) (@chrisseaton).
* Support simplifying more allocation node classes (#73, @nirvdrum).


# 0.14

New Features:

* Added a histogram of nodes in the `describe` command output (#52, @eregon).
* Hide null and zero fields in Truffle object allocations by default (#62, @chrisseaton).
* Added new `--no-simplify-alloc` option to disable simplification of Truffle object allocations (#62, @chrisseaton).

Bug Fixes:

Changes:

* Hide `BeginNode` and `EndNode` in graphs (#59, @eregon).
* Split the "effect" kind into "alloc", "call", "memory", and "sync", each with a different color, for easier identification (#59, @eregon).
* Enhanced the style of Mermaid graphs (#61, @chrisseaton).
* Enhanced allocation node simplification by replacing various allocation nodes with a single node per new object (#63, @eregon)


# 0.13

New Features:

* Added a Mermaid format option (`--md`) to the `render` command to simplify sharing graphs on GitHub (#56, @chrisseaton).

Bug Fixes:

Changes:


# 0.12

New Features:

Bug Fixes:

Changes:

* Moved the `cfg2asm` command out of this project and into a [new one](https://github.com/Shopify/cfg2asm) to simplify this project's dependencies (#50, @chrisseaton).
* Fixed some incorrect details and added missing information about the BGV file format to the documentation (#46, @mattco98).


# 0.11

New Features:

* Added a new formatter system for all commands to customize the output (#48, @nirvdrum).
* Added a new `--json` option to most commands to output in a JSON format (#48, @nirvdrum).

Bug Fixes:

Changes:

* Updated notes on loop peeling in the documentation on generating compiler graphs (#49, @chrisseaton).


# 0.10

New Features:

* Auto-open graphs upon generation in Linux (#44, @chrisseaton).
* Added a new `describe` command to provide a textual summary of a graph without rendering it (#47, @nirvdrum, @chrisseaton).

Bug Fixes:

Changes:


# 0.9

New Features:

* Hide pi nodes by default (#39, @chrisseaton).
* Added new `--show-pi` option to show pi nodes (#39, @chrisseaton).
* Added a new pass to simplify Truffle argument nodes to look more like Graal parameter nodes (#40, @chrisseaton).
* Added new `--full-truffle-args` option to disable Truffle argument simplification (#40, @chrisseaton).

Bug Fixes:

* Fixed display of the help output when a command isn't provided (#33, @chrisseaton).
* Don't hide all the nodes in a call tree (#34, @chrisseaton).
* Fixed an issue with NaN handling in JSON output (#37, @chrisseaton). 

Changes:

* Removed support for the _~/.seafoam/config_ file since it was largely unused (#35, @chrisseaton).
* Added a new citation section to the README (#36, @chrisseaton).
* Added a script for regenerating all of the example graphs in this repository (#37, @chrisseaton).
* Added documentation on how to add source info to Truffle graphs (#37, @chrisseaton).
* Renamed graph _annotators_ to _passes_ (#38, @chrisseaton).
* Shortened the display of `PiArrayNode` to `[π]` (#39, @chrisseaton).


# 0.8

New Features:

* Added a new `--draw-blocks` option for rendering basic blocks (#24, @kethomassen).

Bug Fixes:

Changes:

* Make the PDF and PNG graphs have a white background so the nodes are easier to see when viewed in something with a dark background (#26, @chrisseaton).


# 0.7

No changes.


# 0.6

No changes.


# 0.5

New Features:

* Added a new `cfg2asm` disassembler to turn Graal CFG files into assembly code (#15, @chrisseaton).
* Added the `source` command for printing node source information (#19, @chrisseaton).

Bug Fixes:

* Fixed handling of NaN values in BGV files when converting the graphs to JSON (#16, @chrisseaton).

Changes:

* Added a demo to show how to use Seafoam as an API to process a directory of graph files (#14, @chrisseaton).
* Added documentation on how to install Capstone for the `cfg2asm` disassembler (#18, @chrisseaton).


# 0.4

No changes.


# 0.3

New Features:

* Added parsing of gzipped graph files (@chrisseaton).

Bug Fixes:

* Fixed parsing of graph filenames with an embedded colon (e.g., as Ruby's scope operator) (#9, @LillianZ).
* Fixed parsing of gzipped graph files with multiple extensions (e.g., .bgv.gz) (#9, @LillianZ).

Changes:

* Added documentation for structure of BGV `Document` entries (@chrisseaton).
* Added documentation for generating graphs from a GraalVM Native Image binary (#11, @galderz).