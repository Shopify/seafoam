# Getting Graphs

## GraalVM Compiler as a Java compiler

`-Dgraal.Dump=:1` is a simple option to enable Graal graph dumping.

The value of `Dump` is a *dump filter*. The format of dump filters is
[documented][dump-filters], but in simple cases `:1` will be enough and will
give you everything.

[dump-filters]: https://github.com/oracle/graal/blob/master/compiler/src/org.graalvm.compiler.debug/src/org/graalvm/compiler/debug/doc-files/DumpHelp.txt

You may want to combine with `-XX:CompileOnly=Foo::foo` (you can omit the class
part) to restrict  compilation to a single method to give smaller dumps, and to
some extent make graphs simpler by avoiding what you want to look at being
inlined, or other things being inlined into it.

Graal tends to be quite aggressive about loop peeling, which can produce
massive graphs with the logic repeated. I often use these flags to simplify the
graph without significantly effecting too much how the logic in it is compiled.

```
  -Dgraal.PartialUnroll=false \
  -Dgraal.LoopPeeling=false \
  -Dgraal.LoopUnswitch=false \
  -Dgraal.OptScheduleOutOfLoops=false
```

Also on Graal EE:

```
  -Dgraal.VectorizeLoops=false
```

## GraalVM's Native Image compiler

When using `native-image` you will want to use the `-H:` format.

```
% native-image -H:Dump=:1 -H:MethodFilter=fib Fib
```

## TruffleRuby and other Truffle languages

Use the same options as for GraalVM for Java, except they're prefixed with
`--vm.`, for example `--vm.Dgraal.Dump=Truffle:1`.

```
  --vm.Dgraal.PartialUnroll=false \
  --vm.Dgraal.LoopPeeling=false \
  --vm.Dgraal.LoopUnswitch=false \
  --vm.Dgraal.OptScheduleOutOfLoops=false
```

On Graal EE:

```
  --vm.Dgraal.VectorizeLoops=false
```

Use with `--engine.CompileOnly=foo`.

A good filter to use for Truffle languages is `--vm.Dgraal.Dump=Truffle:1`,
which will only give you Truffle compilations if you don't care about the
whole Graal compilation pipeline.

You may want to disable on-stack-replacement and inlining with
`--engine.Inlining=false` and `--engine.OSR=false` in order to make graphs
easier to understand.

For source information, you want to run with `--engine.NodeSourcePositions`.
This only works on JVM or on Native when built with
`-H:+IncludeNodeSourcePositions`, which isn't set by default.

You may need to use `--experimental-options`.

## Getting basic blocks

To get the graph when scheduled, so that you can see basic blocks, use
`-Dgraal.PrintGraphWithSchedule=true`. Truffle graphs beyond the initial stages
have scheduling information by default.
