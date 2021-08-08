# Passes

The model of Seafoam is that it is a directed graph, with nodes annotated with a
bag of key-value properties. When graphs are read they'll have some initial
properties. Seafoam may add more properties. The output routines then draw the
graph using the graph structure itself and also the properties.

*Passes* are routines that may modify graphs, or add extra properties to graphs,
to help the user understand them. They usually have knowledge of how the graph
is structured, and use this to make the graph easier to read or to make
important information in them stand out.

Passes are similar to filters in IGV, but are more powerful.

Appropriate passes are automatically selected and applied to graphs.

## Properties

The rendering commands recognize these properties, so passes will probably
want to add them:

* `:label` on nodes and edges
* `:out_annotation` on nodes
* `:hidden` on nodes only, to not show them (*remove frame state* for example in IGV terminology)
* `:inlined` on nodes only, to indicate the node should be shown immediately above each node using it (*reduce edges* in IGV terminology)
* `:kind` on nodes only, which can be `info`, `input`, `control`, `effect`, `virtual`, `calc`, `guard`, or `other`
* `:kind` on edges only, which can be `info`, `control`, `loop`, or `data`
* `:reverse` on edges only
* `:spotlight` for nodes as part of spotlighting (`lit` are shown, `shaded` are shown but greyed out, and edges from `shaded` to `:hidden` nodes are also shown greyed out)

Seafoam ships with a pass for generic GraalVM graphs. If you work with a
different compiler you'll probably want to write your own pass.

A fallback pass, run after all others, just labels the node with the
`'label'` property if there is one.

Options for passes can be set on the command line with
`--option key value`. Some options are built into Seafoam commands,
like `--show-frame-state`, but they're doing the same thing as
`--option hide_frame_state false`.
