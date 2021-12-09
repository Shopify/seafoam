# Seafoam

*Seafoam* is a tool for working with compiler graphs. It's designed primarily
for working with the graph files dumped by the GraalVM compiler, such as in
TruffleRuby, but it could be used with other compilers and graph dump file
formats.

The *Ideal Graph Visualizer*, or *IGV*, is the tool usually used to work with
GraalVM compiler graphs. Seafoam aims to solve several problems with IGV. Unlike
IGV, Seafoam:

* has special passes to make Truffle graphs easier to read
* is open source and can be used according to the MIT license
* supports gzip-compressed BGV files
* is able to some extent seek BGV files to load specific graphs without loading the rest of the file
* has a command-line interface
* can be used as a library
* has easy PDF, SVG, PNG and JSON output
* is designed for accessibility
* looks prettier, in our opinion

Additionally, Seafoam adds:

* support for disassembling CFG files

Admittedly, Seafoam does not yet have:

* an interactive user interface
* diffing of graphs
* breaking of edges for very congested graphs
* the same speed in rendering big graphs - Seafoam is best suited for looking at graphs before lowering, which is what language developers are usually doing, or use spotlight

## Seafoam compared to IGV

<p>
<img src="docs/images/seafoam.png" width="350">
<img src="docs/images/igv.png" width="350">
</p>

## Installation

### macOS

```
% brew install graphviz
% gem install seafoam
% seafoam --version
seafoam 0.1
```

### Ubuntu

```
% sudo apt-get install ruby graphviz
% gem install seafoam
% seafoam --version
seafoam 0.1
```

### RedHat

```
% sudo yum install ruby graphviz
% gem install seafoam
% seafoam --version
seafoam 0.1
```

### Capstone

To use the `cfg2asm` disassembler, you'll then need to install Capstone.

```
% brew install capstone               # macOS
% sudo apt-get install libcapstone3   # Ubuntu < 21.04
% sudo apt-get install libcapstone4   # Ubuntu >= 21.04
```

## Quick-start demo

```
% seafoam examples/fib-java.bgv.gz:0 render
```

## Getting compiler graphs

If you are just experimenting, there are example graphs such as
`examples/fib-java.bgv.gz`.

This is just a quick summary - see more information on
[getting graphs out of compilers](docs/getting-graphs.md).

### GraalVM for Java

```
% javac Fib.java
% java -XX:CompileOnly=::fib -Dgraal.Dump=:1 Fib 14
```

### GraalVM Native Image

```
% native-image -H:Dump=:1 -H:MethodFilter=fib Fib
```

### TruffleRuby and other Truffle languages

```
% ruby --experimental-options --engine.CompileOnly=fib --engine.Inlining=false --engine.OSR=false --vm.Dgraal.Dump=Truffle:1 fib.rb 14
```

You will usually want to look at the *After TruffleTier* graph.

## Name syntax

When using a command-line interface, Seafoam refers to
`file.bgv[:graph][:node[-edge]]`, where `file.bgv` is a file, `graph` is a graph
index, `node` is a node index, and `to` is another node index to form an edge
from `node` to another node `edge`.

Note that a *graph ID* is an ID found in BGV files, but is not unique. A
*graph index* is what we use in names, and is unique.

## Use cases

#### Print information about a file

```
% seafoam examples/fib-java.bgv.gz info
BGV 7.0
```

#### List graphs in a file

```
% seafoam examples/fib-java.bgv.gz list
examples/fib-java.bgv.gz:0  17:Fib.fib(int)/After parsing
examples/fib-java.bgv.gz:1  17:Fib.fib(int)/Before phase org.graalvm.compiler.phases.common.LoweringPhase
examples/fib-java.bgv.gz:2  17:Fib.fib(int)/After high tier
examples/fib-java.bgv.gz:3  17:Fib.fib(int)/After mid tier
examples/fib-java.bgv.gz:4  17:Fib.fib(int)/After low tier
...
```

#### Search for strings in a graph, or node or edge within a graph

```
% seafoam examples/fib-java.bgv.gz:0 search Start
examples/fib-java.bgv.gz:0:0  ...node_class":"org.graalvm.compiler.nodes.StartNode","name_template":"Start","inputs":[...
examples/fib-java.bgv.gz:0:0  ...piler.nodes.StartNode","name_template":"Start","inputs":[{"direct":true,"name":"state...
```

#### Print edges of a graph, or node or edge within a graph

```
% seafoam examples/fib-java.bgv.gz:0 edges
21 nodes, 30 edges
% seafoam examples/fib-java.bgv.gz:0:13 edges
Input:
  13 (Call Fib.fib) <-() 6 (Begin)
  13 (Call Fib.fib) <-() 14 (FrameState Fib#fib Fib.java:20)
  13 (Call Fib.fib) <-() 12 (MethodCallTarget)
Output:
  13 (Call Fib.fib) ->() 18 (Call Fib.fib)
  13 (Call Fib.fib) ->(values) 14 (FrameState Fib#fib Fib.java:20)
  13 (Call Fib.fib) ->(values) 19 (FrameState Fib#fib Fib.java:20)
  13 (Call Fib.fib) ->(x) 20 (+)
% seafoam examples/fib-java.bgv.gz:0:13-20 edges
13 (Call Fib.fib) ->(x) 20 (+)
```

#### Print properties of a file, graph, or node or edge within a graph

```
% seafoam examples/fib-java.bgv.gz:0 props
{
  "group": [
    {
      "name": "17:Fib.fib(int)",
      "short_name": "17:Fib.fib(int)",
      "method": null,
...
% seafoam examples/fib-java.bgv.gz:0:13 props
{
  "relativeFrequency": 0.4995903151404586,
  "targetMethod": "Fib.fib",
  "nodeCostSize": "SIZE_2",
  "stamp": "i32",
  "bci": 10,
  "polymorphic": false,
...
% seafoam examples/fib-java.bgv.gz:0:13-20 props
{
  "direct": true,
  "name": "x",
  "type": "Value",
  "index": 0
}

```

#### Print node source information

For Truffle graphs you need to run with `--engine.NodeSourcePositions` to get
useful source information. This only works on JVM or on Native when built with
`-H:+IncludeNodeSourcePositions`, which isn't set by default.

```
% seafoam examples/fib-ruby.bgv.gz:2:2436 source
java.lang.Math#addExact
org.truffleruby.core.numeric.IntegerNodes$AddNode#add
org.truffleruby.core.numeric.IntegerNodesFactory$AddNodeFactory$AddNodeGen#executeAdd
org.truffleruby.core.inlined.InlinedAddNode#intAdd
org.truffleruby.core.inlined.InlinedAddNodeGen#execute
org.truffleruby.language.control.IfElseNode#execute
org.truffleruby.language.control.SequenceNode#execute
org.truffleruby.language.RubyMethodRootNode#execute
org.graalvm.compiler.truffle.runtime.OptimizedCallTarget#executeRootNode
org.graalvm.compiler.truffle.runtime.OptimizedCallTarget#profiledPERoot
```

#### Describe a graph

Describe the key features of a graph without rendering it.

```
% seafoam examples/fib-java.bgv.gz:1 describe
21 nodes, branches, calls
```

The graph description is a useful way to quickly catch unexpected or undesired
attributes in a graph and makes comparing two graphs to each other straightforward.
Such a comparison could be the basis of a regression test.

#### Render a graph

Render a graph as a PDF image and have it opened automatically.

```
% seafoam examples/fib-java.bgv.gz:0 render
```

Render a graph showing just a few nodes and those surrounding them, similar to
the IGV feature of gradually revealing nodes.

```
% seafoam examples/fib-java.bgv.gz:0 render --spotlight 13,20
```

<p>
<img src="docs/images/spotlight-seafoam.png" width="200">
<img src="docs/images/spotlight-igv.png" width="350">
</p>

`render` supports these options:

* `--out filename.pdf` or `.pdf`, `.svg`, `.png`, `.dot`
* `--option key value` for pass options.

#### Convert a file

Convert a BGV file to the Isabelle graph format.

```
% bgv2isabelle examples/fib-java.bgv.gz
graph0 = # 2:Fib.fib(int)/After phase org.graalvm.compiler.java.GraphBuilderPhase
 (add_node 0 StartNode [2] [8]
 (add_node 1 (ParameterNode 0) [] [2, 5, 9, 11, 14, 16]
 (add_node 2 FrameState [1] [0]
 (add_node 3 (ConstantNode 1) [] []
 (add_node 4 (ConstantNode 2) [] [5]
 (add_node 5 IntegerLessThanNode [1, 4] [8]
 (add_node 6 BeginNode [8] [13]
 (add_node 7 BeginNode [8] [9]
 (add_node 8 IfNode [0, 5] [7, 6]
...
```

Convert a BGV file to JSON.

```
% bgv2json examples/fib-java.bgv.gz
graph0 = # 2:Fib.fib(int)/After phase org.graalvm.compiler.java.GraphBuilderPhase
 (add_node 0 StartNode [2] [8]
 (add_node 1 (ParameterNode 0) [] [2, 5, 9, 11, 14, 16]
 (add_node 2 FrameState [1] [0]
 (add_node 3 (ConstantNode 1) [] []
 (add_node 4 (ConstantNode 2) [] [5]
 (add_node 5 IntegerLessThanNode [1, 4] [8]
 (add_node 6 BeginNode [8] [13]
 (add_node 7 BeginNode [8] [9]
 (add_node 8 IfNode [0, 5] [7, 6]
...
```

#### Disassembling

```
% cfg2asm examples/java/exampleArithOperator.cfg.gz
[examples/java/exampleArithOperator.cfg.gz]
				;Comment 0:	VERIFIED_ENTRY
	0x124b8de80:	nop	dword ptr [rax + rax]
				;Comment 5:	block B0 null
				;Comment 5:	0 [rsi|DWORD, rdx|DWORD, rbp|QWORD] = LABEL numbPhis: 0 align: false label: ?
				;Comment 5:	4 [] = HOTSPOTLOCKSTACK frameMapBuilder: org.graalvm.compiler.lir.amd64.AMD64FrameMapBuilder@26ba755b slotKind: QWORD
				;Comment 5:	10 rsi|DWORD = ADD (x: rsi|DWORD, y: rdx|DWORD) size: DWORD
	0x124b8de85:	add	esi, edx
				;Comment 7:	12 rax|DWORD = MOVE rsi|DWORD moveKind: DWORD
	0x124b8de87:	mov	eax, esi
				;Comment 9:	14 RETURN (savedRbp: rbp|QWORD, value: rax|DWORD) isStub: false requiresReservedStackAccessCheck: false thread: r15 scratchForSafepointOnReturn: rcx config: org.graalvm.compiler.hotspot.GraalHotSpotVMConfig@6c71283a
	0x124b8de89:	mov	rcx, qword ptr [r15 + 0x108]
				;Comment 16:	POLL_RETURN_FAR
	0x124b8de90:	test	dword ptr [rcx], eax
	0x124b8de92:	ret	
				;Comment 19:	{Stub<ExceptionHandlerStub.exceptionHandler>@0x11a9b9980:CallingConvention[rax|QWORD[.], rdx|QWORD]:CallingConvention[rax|QWORD[.], rdx|QWORD]; temps=rdi|ILLEGAL,xmm14|ILLEGAL,xmm15|ILLEGAL,xmm12|ILLEGAL,xmm13|ILLEGAL,xmm10|ILLEGAL,xmm11|ILLEGAL,xmm7|ILLEGAL,xmm8|ILLEGAL,xmm9|ILLEGAL,xmm0|ILLEGAL,xmm1|ILLEGAL,xmm2|ILLEGAL,xmm3|ILLEGAL,xmm4|ILLEGAL,xmm5|ILLEGAL,xmm6|ILLEGAL,rax|ILLEGAL,rcx|ILLEGAL,rdx|ILLEGAL,rsi|ILLEGAL,r8|ILLEGAL,r9|ILLEGAL,r10|ILLEGAL,r11|ILLEGAL}
				;Comment 19:	EXCEPTION_HANDLER_ENTRY
	0x124b8de93:	call	0x11a9b9980
	0x124b8de98:	nop	
				;Comment 25:	{Field[name=CompilerToVM::Data::SharedRuntime_deopt_blob_unpack, type=address, offset=0, address=0x10646a4d0, value=4740607520]:0x11a8fee20}
				;Comment 25:	DEOPT_HANDLER_ENTRY
	0x124b8de99:	call	0x11a8fee20
	0x124b8de9e:	nop	
	0x124b8de9f:	hlt	
```

## Options for GraalVM graphs

* `--full-truffle-args` shows full Truffle argument nodes, which are simplified by default
* `--show-frame-state` shows frame state nodes, which are hidden by default
* `--show-pi` shows 'pi' nodes, which are hidden by default
* `--hide-floating` hides nodes that aren't fixed by control flow
* `--no-reduce-edges` turns off the option to reduce the number of edges by inlining simple nodes above their users
* `--draw-blocks` to draw basic block information if available

## Debugging

Exception backtraces are printed if `$DEBUG` (`-d`) is set.

Use `seafoam file.bgv debug` to debug file parsing.

## More documentation

* [Graph passes](docs/passes.md)
* [Details of the BGV file format](docs/bgv.md)
* [How to get graphs from various compilers](docs/getting-graphs.md)

## Frequently asked questions

#### Why is it called *Seafoam*?

GraalVM graphs are *seas of nodes*. Seafoam is a shade of green, and Seafoam was
written at Shopify, which has green as a brand colour. Graphs can sometimes be
very complicated, appearing like a foam without any structure - Seafoam tries to
help you make sense of it all.

#### What do you mean by *graphs*, and *seas* or *soups* of nodes?

Graphs, as in edges and nodes, are the data structure some compilers use to
represent your program while they're compiling it. It's a form of *intermediate
representation*. Graphs are how the compiler understands the programs and if the
compiler isn't doing what you want you need to look at the graph and make sense
of it. Some graphs are loosely structured and large, making them like a sea or
soup of nodes.

#### Doesn't *reduce edges* actually introduce more edges?

Yes, but they're shorter edges, and it achieves the intended effect of less
edges crossing over the graph.

## Related work

The graph layout algorithm we use, via Graphviz, is

* E. R. Gansner, et al, [*A Technique for Drawing Directed Graphs*](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.3.8982), IEEE Transactions on Software Engineering, 1993

IGV is the existing tool for working with Graal graphs. It uses a *hierarchical*
layout algorithm, rather than the *force directed* algorithm we use when we use
Graphviz. It's based on the NetBeans IDE platform. It's related to the *C1
Visualiser*, for control-flow graphs. The C1 Visualiser can also be used with
Graal as the backend of Graal is similar enough to C1. IGV is closed-source and
available under a proprietary licence.

* T. Würthinger, [*Visualization of Program Dependence Graphs*](http://www.ssw.uni-linz.ac.at/Research/Papers/Wuerthinger07Master/), Master Thesis, Linz 2007
* T. Würthinger, [*Visualization of Java Control Flow Graphs*](http://www.ssw.uni-linz.ac.at/General/Staff/TW/Wuerthinger06Bachelor.pdf), Bachelor Thesis, Linz 2006

[*Turbolizer*][turbolizer] is a similar tool for the intermediate representation
in the V8 JavaScript compiler.

[turbolizer]: https://github.com/v8/v8/blob/4b9b23521e6fd42373ebbcb20ebe03bf445494f9/tools/turbolizer

## Author

Seafoam was written by Chris Seaton at Shopify, chris.seaton@shopify.com.

## Citations

* [A Formal Semantics of the GraalVM Intermediate Representation](https://arxiv.org/pdf/2107.01815.pdf), Brae J. Webb , Mark Utting , and Ian J. Hayes.

## License

MIT
