# BGV File Format

The BGV (*binary graph*, sometimes also called *BIGV*) file format is dumped by
Graal graphs.

The BGV parser was implemented from the [open-source writer code][graph-protocol]
in the GraalVM compiler.

[graph-protocol]: https://github.com/oracle/graal/blob/master/compiler/src/org.graalvm.graphio/src/org/graalvm/graphio/GraphProtocol.java

## Format

Seafoam supports BGV versions:

* 7.0 (GraalVM 20.1.0 and up)
* 6.1 (GraalVM 1.0.0-rc16 and up)

The BGV file format is network-endian.

```c
BGV {
  char[4] = 'BIGV'
  sint8 major
  sint8 minor
  GroupDocumentGraph*
}

GroupDocumentGraph {
  BeginGroup GroupDocumentGraph* CloseGroup | Document | Graph
}

BeginGroup {
  sint8 token = BEGIN_GROUP
  PoolObject name
  PoolObject method
  sint32 bci
  Props props
}

CloseGroup {
  sint8 token = CLOSE_GROUP
}

Document {
  sint8 token = BEGIN_DOCUMENT
  Pops props
}

Graph {
  sint8 token = BEGIN_GRAPH
  String format
  Args args
  GraphBody body
}

GraphBody {
  Props props
  sint32 nodes_count
  Node[nodes_count] nodes
  sint32 blocks_count
  Blocks[blocks_count] blocks
}

Node {
  sint32 id
  PoolObject node_class
  bool has_predecessor
  Pops props
  Edge[node_class.inputs.size] edges_in
  Edge[node_class.outputs.size] edges_out
}

Edge {
  sint32[inputs_count] nodes
}

Blocks {
  sint32 id
  sint32 nodes_count
  sint32[nodes_count] nodes
  sint32 followers_count
  sint32[followers_count] followers
}

Props {
  sint16 props_count
  Prop[props_count] props
}

Prop {
  PoolObject key
  PropObject value
}

PropObject {
  union {
    struct {
      sint8 PROPERTY_POOL
      PoolObject object
    }
    struct {
      sint8 PROPERTY_INT
      sint32 value
    }
    struct {
      sint8 PROPERTY_LONG
      sint64 value
    }
    struct {
      sint8 PROPERTY_DOUBLE
      float64 value
    }
    struct {
      sint8 PROPERTY_FLOAT
      float32 value
    }
    struct {
      sint8 PROPERTY_TRUE
    }
    struct {
      sint8 PROPERTY_FALSE
    }
    struct {
      sint8 PROPERTY_ARRAY
      union {
        struct {
          sint8 PROPERTY_POOL
          sint32 times
          PoolObject[times] values
        }
      }
    }
    struct {
      sint8 PROPERTY_SUBGRAPH
      GraphBody graph
    }
  }
}

PoolObject {
  union {
    POOL_NULL
    struct {
      sint8 token = POOL_NEW
      uint16 id
      union {
        struct {
          sint8 type = POOL_STRING
          String string
        }
        struct {
          sint8 type = POOL_ENUM
          PoolObject enum_class
          sint32 enum_ordinal
        }
        struct {
          sint8 type = POOL_CLASS
          String type_name
          union {
            struct {
              sint8 type = ENUM_KLASS
              sint32 values_count
              PoolObject values[values_count]
            }
            struct {
              sint8 type = KLASS
            }
          }
        }
        struct {
          sint8 type = POOL_METHOD
          PoolObject declaring_class
          PoolObject method_name
          PoolObject signature
          sint32 modifiers
          sint32 bytes_length
          uint8[bytes_length] bytes
        }
        struct {
          sint8 type = POOL_NODE_CLASS
          PoolObject node_class
          String name_template
          sint16 input_count
          InputEdgeInfo inputs[input_count]
          sint16 output_count
          OutputEdgeInfo outputs[output_count]
        }
        struct {
          sint8 type = POOL_FIELD
          PoolObject field_class
          PoolObject name
          PoolObject type_name
          sint32 modifiers
        }
        struct {
          sint8 type = POOL_NODE_SIGNATURE
          sint16 args_count
          PoolObject args[args_count]
        }
        struct {
          sint8 type = POOL_NODE_SOURCE_POSITION
          PoolObject method
          sint32 bci
          SourcePosition source_positions[...until SourcePosition.uri = null]
          PoolObject caller
        }
        struct {
          sint8 type = POOL_NODE
          sint32 node_id
          PoolObject node_class
        }
      }
    }
    struct {
      sint8 token = POOL_STRING | POOL_ENUM | POOL_CLASS | POOL_METHOD | POOL_NODE_CLASS | POOL_FIELD | POOL_SIGNATURE | POOL_NODE_SOURCE_POSITION | POOL_NODE
      uint16 pool_id
    }
  }
}

InputEdgeInfo {
  sint8 indirect
  PoolObject name
  PoolObject type
}

OutputEdgeInfo {
  sint8 indirect
  PoolObject name
}

SourcePosition {
  PoolObject uri
  String location
  sint32 line
  sint32 start
  sint32 end
}

String {
  sint32 length
  char[length] chars
}

BEGIN_GROUP = 0x00
BEGIN_GRAPH = 0x01
CLOSE_GROUP = 0x02
BEGIN_DOCUMENT = 0x03

POOL_NEW = 0x00
POOL_STRING = 0x01
POOL_ENUM = 0x02
POOL_CLASS = 0x03
POOL_METHOD = 0x04
POOL_NULL = 0x05
POOL_NODE_CLASS = 0x06
POOL_FIELD = 0x07
POOL_SIGNATURE = 0x08
POOL_NODE_SOURCE_POSITION = 0x09
POOL_NODE = 0x0a

PROPERTY_POOL = 0x00
PROPERTY_INT = 0x01
PROPERTY_LONG = 0x02
PROPERTY_DOUBLE = 0x03
PROPERTY_FLOAT = 0x04
PROPERTY_TRUE = 0x05
PROPERTY_FALSE = 0x06
PROPERTY_ARRAY = 0x07
PROPERTY_SUBGRAPH = 0x08

KLASS = 0x00
ENUM_KLASS = 0x01
```

## Seeking

The BGV format is not particularly amenable to seeking. You must read each prior
graph in order to read any subsequent graph, the length of nodes and edges
depends on values within them, and there is an object pool that is incrementally
built.

In order to 'seek' BGV files we have two code paths for reading the file, one
with loads the data and one which loads as little as possible to know just how
much further to advance in the file.

## Compression

Seafoam supports compressed BGV files in the gzip file format.

## Other information

`seafoam file.bgv debug` checks that a file can be parsed and prints information
as it does so.
