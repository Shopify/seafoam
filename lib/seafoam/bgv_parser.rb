module Seafoam
  # A parser for BGV files. It's a push-pull streaming interface that you need
  # to drive with what you want next from the file. It's slightly complicated
  # and some code is duplicated in order to support skipping over parts of the
  # file that you don't need.
  class BGVParser
    def initialize(source)
      @reader = BinaryReader.for(source)
      @group_stack = []
      @pool = {}
      @index = 0
    end

    # Read the file header and return the version.
    def read_file_header(version_check: true)
      raise EncodingError, 'does not appear to be a BGV file - missing header' unless @reader.read_bytes(4) == MAGIC

      @major = @reader.read_sint8
      @minor = @reader.read_sint8
      version = [@major, @minor]
      if version_check && !SUPPORTED_VERSIONS.include?(version)
        raise NotImplementedError, "unsupported BGV version #{@major}.#{@minor}"
      end

      version
    end

    def read_document_props
      if @major >= 7
        token = @reader.peek_sint8
        if token == BEGIN_DOCUMENT
          @reader.skip_int8
          document_props = read_props
        end
      end
      document_props
    end

    def skip_document_props
      if @major >= 7
        token = @reader.peek_sint8
        if token == BEGIN_DOCUMENT
          @reader.skip_int8
          skip_props
        end
      end
    end

    # Move to the next graph in the file, and return its index and ID, or nil if
    # there are no more graphs.
    def read_graph_preheader
      return nil unless read_groups

      # Already read BEGIN_GRAPH
      index = @index
      id = @reader.read_sint32
      if id
        @index += 1
        [index, id]
      else
        [nil, nil]
      end
    end

    # Skip over a graph's headers, having just read its ID.
    def skip_graph_header
      # Already read BEGIN_GRAPH and id
      skip_string
      skip_args
      @graph_props = read_props
    end

    # Read a graph's headers, having just read its ID. This gives you the
    # graph's properties.
    def read_graph_header
      # Already read BEGIN_GRAPH and id
      format = read_string
      args = read_args
      props = read_props
      @graph_props = props
      {
        group: @group_stack.dup,
        format: format,
        args: args,
        props: props
      }
    end

    # Read a graph having either read or skipped its headers, producing a Graph object.
    def read_graph
      # Already read BEGIN_GRAPH, id, format, args, and props
      graph = Graph.new(@graph_props)
      edge_delay = []
      @reader.read_sint32.times do
        id = @reader.read_sint32
        node_class = read_pool_object
        has_predecessor = read_bool
        props = read_props
        props[:id] = id
        props[:node_class] = node_class
        props[:has_predecessor] = has_predecessor
        node = graph.create_node(id, props)
        edge_delay.push(*read_edges(node, node_class, true))
        edge_delay.push(*read_edges(node, node_class, false))
      end
      edge_delay.each do |edge|
        node = edge[:node]
        props = edge[:edge]
        inputs = edge[:inputs]
        others = edge[:ids].reject(&:nil?).map { |id| graph.nodes[id] || raise(EncodingError, "BGV edge with unknown node #{id}") }
        others.each_with_index do |other, index|
          # We need to give each edge their own property as they're annotated separately.
          props = props.dup
          props[:index] = index
          if inputs
            graph.create_edge other, node, props
          else
            graph.create_edge node, other, props
          end
        end
      end
      skip_blocks
      graph
    end

    # Skip over a graph, having read or skipped its headers.
    def skip_graph
      # Already read BEGIN_GRAPH, id, format, args, and props
      @reader.read_sint32.times do
        @reader.skip_int32
        node_class = read_pool_object
        skip_bool
        skip_props
        skip_edges node_class, true
        skip_edges node_class, false
      end
      skip_blocks
    end

    # Produce a flat graph name from a header.
    def graph_name(graph_header)
      groups_names = graph_header[:group].map { |g| g[:short_name] }
      count = 0
      name = graph_header[:format].sub(/%s/) do
        arg = graph_header[:args][count]
        count += 1
        arg
      end
      components = groups_names + [name]
      components.join('/')
    end

    private

    # Read through group declarations to get to the start of the next graph.
    def read_groups
      until @reader.eof?
        token = @reader.read_sint8
        case token
        when BEGIN_GROUP
          read_begin_group
        when BEGIN_GRAPH
          break true
        when CLOSE_GROUP
          read_close_group
        else
          raise EncodingError, "unknown token 0x#{token.to_s(16)} beginning BGV object"
        end
      end
    end

    # Read the opening of a group.
    def read_begin_group
      # Already read BEGIN_GROUP
      name = read_pool_object
      short_name = read_pool_object
      method = read_pool_object
      bci = @reader.read_sint32
      props = read_props
      group = {
        name: name,
        short_name: short_name,
        method: method,
        bci: bci,
        props: props
      }
      @group_stack.push group
    end

    # Read the closing of a group.
    def read_close_group
      # Already read CLOSE_GROUP
      @group_stack.pop
    end

    # Skip over arguments.
    def skip_args
      @reader.read_sint32.times do
        skip_prop_object
      end
    end

    # Read arguments.
    def read_args
      @reader.read_sint32.times.map do
        read_prop_object
      end
    end

    # Skip over edges.
    def skip_edges(node_class, inputs)
      edges = if inputs
                node_class[:inputs]
              else
                node_class[:outputs]
              end
      edges.each do |edge|
        count = if edge[:direct]
                  1
                else
                  @reader.read_sint16
                end
        count.times do
          @reader.skip_int32
        end
      end
    end

    # Read edges, producing an array of edge hashes.
    def read_edges(node, node_class, inputs)
      edges = if inputs
                node_class[:inputs]
              else
                node_class[:outputs]
              end
      edges.map do |edge|
        count = if edge[:direct]
                  1
                else
                  @reader.read_sint16
                end
        ids = count.times.map do
          id = @reader.read_sint32
          raise if id < -1

          id = nil if id == -1
          id
        end
        {
          node: node,
          edge: edge,
          ids: ids,
          inputs: inputs
        }
      end
    end

    # Skip over blocks in a graph.
    def skip_blocks
      @reader.read_sint32.times do
        @reader.skip_int32
        @reader.skip_int32 @reader.read_sint32
        @reader.skip_int32 @reader.read_sint32
      end
    end

    # Skip over a set of properties.
    def skip_props
      @reader.read_sint16.times do
        skip_pool_object
        skip_prop_object
      end
    end

    # Read a set of properties, producing a Hash.
    def read_props
      @reader.read_sint16.times.map do
        key = read_pool_object
        value = read_prop_object
        [key, value]
      end.to_h
    end

    # Skip over a single property value.
    def skip_prop_object
      token = @reader.read_sint8
      case token
      when PROPERTY_POOL
        skip_pool_object
      when PROPERTY_INT
        @reader.skip_int32
      when PROPERTY_LONG
        @reader.skip_int64
      when PROPERTY_DOUBLE
        @reader.skip_float64
      when PROPERTY_FLOAT
        @reader.skip_float32
      when PROPERTY_TRUE
      when PROPERTY_FALSE
      when PROPERTY_ARRAY
        type = @reader.read_sint8
        case type
        when PROPERTY_POOL
          @reader.read_sint32.times do
            skip_pool_object
          end
        when PROPERTY_INT
          @reader.skip_int32 @reader.read_sint32
        when PROPERTY_DOUBLE
          @reader.skip_float64 @reader.read_sint32
        else
          raise EncodingError, "unknown BGV property array type 0x#{type.to_s(16)}"
        end
      when PROPERTY_SUBGRAPH
        skip_props
        skip_graph
      else
        raise EncodingError, "unknown BGV property 0x#{token.to_s(16)}"
      end
    end

    # Read a single property value.
    def read_prop_object
      token = @reader.read_sint8
      case token
      when PROPERTY_POOL
        read_pool_object
      when PROPERTY_INT
        @reader.read_sint32
      when PROPERTY_LONG
        @reader.read_sint64
      when PROPERTY_DOUBLE
        @reader.read_float64
      when PROPERTY_FLOAT
        @reader.read_float32
      when PROPERTY_TRUE
        true
      when PROPERTY_FALSE
        false
      when PROPERTY_ARRAY
        type = @reader.read_sint8
        case type
        when PROPERTY_POOL
          @reader.read_sint32.times.map do
            read_pool_object
          end
        when PROPERTY_INT
          @reader.read_sint32.times.map do
            @reader.read_sint32
          end
        when PROPERTY_DOUBLE
          @reader.read_sint32.times.map do
            @reader.read_float64
          end
        else
          raise EncodingError, "unknown BGV property array type 0x#{type.to_s(16)}"
        end
      when PROPERTY_SUBGRAPH
        @graph_props = read_props
        read_graph
      else
        raise EncodingError, "unknown BGV property 0x#{token.to_s(16)}"
      end
    end

    # Skip over an object from the pool.
    def skip_pool_object
      token = @reader.read_sint8
      case token
      when POOL_NULL
      when POOL_NEW
        read_pool_entry
      when POOL_STRING, POOL_ENUM, POOL_CLASS, POOL_METHOD, POOL_NODE_CLASS, POOL_FIELD, POOL_SIGNATURE, POOL_NODE_SOURCE_POSITION, POOL_NODE
        @reader.skip_int16
      else
        raise EncodingError, "unknown token 0x#{token.to_s(16)} in BGV pool object"
      end
    end

    # Read an object from the pool.
    def read_pool_object
      token = @reader.read_sint8
      case token
      when POOL_NULL
        nil
      when POOL_NEW
        read_pool_entry
      when POOL_STRING, POOL_ENUM, POOL_CLASS, POOL_METHOD, POOL_NODE_CLASS, POOL_FIELD, POOL_SIGNATURE, POOL_NODE_SOURCE_POSITION, POOL_NODE
        id = @reader.read_uint16
        object = @pool[id]
        raise EncodingError, "unknown BGV pool object #{token}" unless object

        object
      else
        raise EncodingError, "unknown token 0x#{token.to_s(16)} in BGV pool object"
      end
    end

    # Read a new entry to the pool.
    def read_pool_entry
      # Already read POOL_NEW
      id = @reader.read_uint16
      type = @reader.read_sint8
      case type
      when POOL_STRING
        object = read_string
      when POOL_ENUM
        enum_class = read_pool_object
        enum_ordinal = @reader.read_sint32
        raise EncodingError, "unknown BGV eum ordinal #{enum_ordinal} in #{enum_class}" if enum_ordinal.negative? || enum_ordinal >= enum_class.size

        object = enum_class[enum_ordinal]
      when POOL_CLASS
        type_name = read_string
        token = @reader.read_sint8
        case token
        when ENUM_KLASS
          values = @reader.read_sint32.times.map do
            read_pool_object
          end
          object = values
        when KLASS
          object = type_name
        else
          raise EncodingError, "unknown BGV pool class token 0x#{token.to_s(16)}"
        end
      when POOL_METHOD
        declaring_class = read_pool_object
        method_name = read_pool_object
        signature = read_pool_object
        modifiers = @reader.read_sint32
        bytes_length = @reader.read_sint32
        @reader.skip bytes_length if bytes_length != -1
        object = {
          declaring_class: declaring_class,
          method_name: method_name,
          signature: signature,
          modifiers: modifiers
        }
      when POOL_NODE_CLASS
        node_class = read_pool_object
        name_template = read_string
        inputs = read_edges_info(true)
        outputs = read_edges_info(false)
        object = {
          node_class: node_class,
          name_template: name_template,
          inputs: inputs,
          outputs: outputs
        }
      when POOL_FIELD
        field_class = read_pool_object
        name = read_pool_object
        type_name = read_pool_object
        modifiers = @reader.read_sint32
        object = {
          field_class: field_class,
          name: name,
          type_name: type_name,
          modifiers: modifiers
        }
      when POOL_SIGNATURE
        args = @reader.read_sint16.times.map do
          read_pool_object
        end
        ret = read_pool_object
        object = {
          args: args,
          ret: ret
        }
      when POOL_NODE_SOURCE_POSITION
        method = read_pool_object
        bci = @reader.read_sint32
        locs = []
        loop do
          uri = read_pool_object
          break unless uri

          location = read_string
          loc_line = @reader.read_sint32
          loc_start = @reader.read_sint32
          loc_end = @reader.read_sint32
          locs.push [location, loc_line, loc_start, loc_end]
        end
        caller = read_pool_object
        object = {
          method: method,
          bci: bci,
          locs: locs,
          caller: caller
        }
      when POOL_NODE
        node_id = @reader.read_sint32
        node_class = read_pool_object
        object = {
          node_id: node_id,
          node_class: node_class
        }
      else
        raise EncodingError, "unknown BGV pool type 0x#{type.to_s(16)}"
      end
      set_pool_entry id, object
    end

    # Hook method that can be overidden for debugging.
    def set_pool_entry(id, object)
      @pool[id] = object
    end

    # Read information about edges.
    def read_edges_info(inputs)
      @reader.read_sint16.times.map do
        indirect = read_bool
        name = read_pool_object
        type = (read_pool_object if inputs)
        {
          direct: !indirect,
          name: name,
          type: type
        }
      end
    end

    # Skip over a UTF-8 string.
    def skip_string
      length = @reader.read_sint32
      @reader.skip length if length != -1
    end

    # Read a UTF-8 string.
    def read_string
      length = @reader.read_sint32
      if length == -1
        nil
      else
        string = @reader.read_utf8(length)
        raise EncodingError, 'null byte in BGV string' if string.include?("\0")

        string
      end
    end

    # Skip over a boolean value.
    def skip_bool
      @reader.skip_int8
    end

    # Read a boolean value.
    def read_bool
      token = @reader.read_uint8
      case token
      when 0
        false
      when 1
        true
      else
        raise ::EncodingError, "unknown BGV boolean value 0x#{token.to_s(16)}"
      end
    end

    # File format constants.

    MAGIC = 'BIGV'

    SUPPORTED_VERSIONS = [
      [6, 1],
      [7, 0]
    ]

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
  end
end
