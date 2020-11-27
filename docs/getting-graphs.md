# Getting Graphs

## GraalVM Compiler as a Java compiler

`-Dgraal.Dump=:2` is a simple option to enable Graal graph dumping.

The value of `Dump` is a *dump filter*. The format of dump filters is
[documented][dump-filters], but in simple cases `:2` will be enough and will
give you everything.

[dump-filters]: https://github.com/oracle/graal/blob/master/compiler/src/org.graalvm.compiler.debug/src/org/graalvm/compiler/debug/doc-files/DumpHelp.txt

You may want to combine with `-XX:CompileOnly=Foo::foo` (you can omit the class
part) to restrict  compilation to a single method to give smaller dumps, and to
some extent make graphs simpler by avoiding what you want to look at being
inlined, or other things being inlined into it.

Graal tends to be quite aggressive about loop unrolling, which can produce
massive graphs with the logic repeated. I often use these flags to simplify the
graph without significantly effecting too much how the logic in it is compiled.

```
  -Dgraal.FullUnroll=false \
  -Dgraal.PartialUnroll=false \
  -Dgraal.LoopPeeling=false \
  -Dgraal.LoopUnswitch=false \
  -Dgraal.OptLoopTransform=false \
  -Dgraal.OptScheduleOutOfLoops=false \
  -Dgraal.VectorizeLoops=false
```

## GraalVM's Native Image compiler

When using `native-image` you will want to use the `-H:` format.

```
% native-image -H:Dump=:2 -H:MethodFilter=fib Fib
```

## TruffleRuby and other Truffle languages

Use the same options as for GraalVM for Java, except they're prefixed with
`--vm.`, for example `--vm.Dgraal.Dump=Truffle:2`.

Use with `--engine.CompileOnly=foo`.

A good filter to use for Truffle languages is `--vm.Dgraal.Dump=Truffle:1`,
which will only give you Truffle compilations if you don't care about the
whole Graal compilation pipeline.

You may want to disable on-stack-replacement and inlining with
`--engine.Inlining=false` and `--engine.OSR=false` in order to make graphs
easier to understand.

You may need to use `--experimental-options`.
