# frozen_string_literal: true

require "stringio"
require "tmpdir"

require "seafoam"

require "rspec"

require_relative "spec_helpers"

describe Seafoam::Commands do
  before :all do
    @fib_java = File.expand_path("../../examples/graalvm-ce-java11-21.2.0/fib-java.bgv.gz", __dir__)
    @fib_ruby = File.expand_path("../../examples/graalvm-ce-java11-21.2.0/fib-ruby.bgv.gz", __dir__)
  end

  before :each do
    @out = StringIO.new
    @commands = Seafoam::Commands.new(@out)
  end

  describe "#info" do
    describe "txt format" do
      it "prints format and version" do
        @commands.send(:info, @fib_java, Seafoam::Formatters::Text)
        lines = @out.string.lines.map(&:rstrip)
        expect(lines.first).to(eq("BGV 7.0"))
      end
    end

    describe "json format" do
      it "prints format and version" do
        @commands.send(:info, @fib_java, Seafoam::Formatters::Json)
        lines = @out.string.lines.map(&:rstrip)
        expect(JSON.parse(lines.first)).to(eq({ "major_version" => 7, "minor_version" => 0 }))
      end
    end

    it "does not work on a graph" do
      expect { @commands.send(:info, "#{@fib_java}:0") }.to(raise_error(ArgumentError))
    end
  end

  describe "#list" do
    describe "txt format" do
      it "prints graphs" do
        @commands.send(:list, @fib_java, Seafoam::Formatters::Text)
        lines = @out.string.lines.map(&:rstrip)
        expect(lines).to(eq([
          "#{@fib_java}:0  17:Fib.fib(int)/After parsing",
          "#{@fib_java}:1  17:Fib.fib(int)/Before phase org.graalvm.compiler.phases.common.LoweringPhase",
          "#{@fib_java}:2  17:Fib.fib(int)/After high tier",
          "#{@fib_java}:3  17:Fib.fib(int)/After mid tier",
          "#{@fib_java}:4  17:Fib.fib(int)/After low tier",
        ]))
      end
    end

    describe "json format" do
      it "prints graphs" do
        @commands.send(:list, @fib_java, Seafoam::Formatters::Json)
        decoded = JSON.parse(@out.string)
        expect(decoded).to(eq([
          {
            "graph_index" => 0,
            "graph_file" => @fib_java,
            "graph_name_components" => ["17:Fib.fib(int)", "After parsing"],
          },
          {
            "graph_index" => 1,
            "graph_file" => @fib_java,
            "graph_name_components" => [
              "17:Fib.fib(int)",
              "Before phase org.graalvm.compiler.phases.common.LoweringPhase",
            ],
          },
          {
            "graph_index" => 2,
            "graph_file" => @fib_java,
            "graph_name_components" => ["17:Fib.fib(int)", "After high tier"],
          },
          {
            "graph_index" => 3,
            "graph_file" => @fib_java,
            "graph_name_components" => ["17:Fib.fib(int)", "After mid tier"],
          },
          {
            "graph_index" => 4,
            "graph_file" => @fib_java,
            "graph_name_components" => ["17:Fib.fib(int)", "After low tier"],
          },
        ]))
      end
    end

    it "does not work on a graph" do
      expect { @commands.send(:list, "#{@fib_java}:0") }.to(raise_error(ArgumentError))
    end
  end

  # rubocop:disable Layout/LineLength

  describe "#search" do
    it "finds terms in files" do
      @commands.send(:search, @fib_java, "MethodCallTarget")
      lines = @out.string.lines.map(&:rstrip)
      expect(lines).to(eq([
        "#{@fib_java}:0:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:0:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:1:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:1:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
      ]))
    end

    it "finds terms in graphs" do
      @commands.send(:search, "#{@fib_java}:0", "MethodCallTarget")
      lines = @out.string.lines.map(&:rstrip)
      expect(lines).to(eq([
        "#{@fib_java}:0:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:0:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
      ]))
    end

    it "is case-insensitive" do
      @commands.send(:search, "#{@fib_java}:0", "methodcalltarget")
      lines = @out.string.lines.map(&:rstrip)
      expect(lines).to(eq([
        "#{@fib_java}:0:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:0:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
      ]))
    end

    it "does not work on a node" do
      expect { @commands.send(:search, "#{@fib_java}:0:0") }.to(raise_error(ArgumentError))
    end
  end

  # rubocop:enable Layout/LineLength

  describe "#edges" do
    describe "txt format" do
      it "prints the number of edges and nodes for a graph" do
        @commands.send(:edges, "#{@fib_java}:0", Seafoam::Formatters::Text)
        lines = @out.string.lines.map(&:rstrip)
        expect(lines).to(eq(["21 nodes, 30 edges"]))
      end

      it "prints the edges for a node" do
        @commands.send(:edges, "#{@fib_java}:0:13", Seafoam::Formatters::Text)
        lines = @out.string.lines.map(&:rstrip)
        expect(lines).to(eq([
          "Input:",
          "  13 (Call Fib.fib) <-() 6 (Begin)",
          "  13 (Call Fib.fib) <-() 14 (FrameState Fib#fib Fib.java:20)",
          "  13 (Call Fib.fib) <-() 12 (MethodCallTarget)",
          "Output:",
          "  13 (Call Fib.fib) ->() 18 (Call Fib.fib)",
          "  13 (Call Fib.fib) ->(values) 14 (FrameState Fib#fib Fib.java:20)",
          "  13 (Call Fib.fib) ->(values) 19 (FrameState Fib#fib Fib.java:20)",
          "  13 (Call Fib.fib) ->(x) 20 (+)",
        ]))
      end

      it "prints details for an edge" do
        @commands.send(:edges, "#{@fib_java}:0:13-18", Seafoam::Formatters::Text)
        lines = @out.string.lines.map(&:rstrip)
        expect(lines).to(eq(["13 (Call Fib.fib) ->() 18 (Call Fib.fib)"]))
      end

      it "does not work on a file" do
        expect { @commands.send(:edges, @fib_java, Seafoam::Formatters::Text) }.to(raise_error(ArgumentError))
      end
    end

    describe "json format" do
      it "prints the number of edges and nodes for a graph" do
        @commands.send(:edges, "#{@fib_java}:0", Seafoam::Formatters::Json)
        decoded = JSON.parse(@out.string)

        expect(decoded).to(eq({ "node_count" => 21, "edge_count" => 30 }))
      end

      it "prints the edges for a node" do
        @commands.send(:edges, "#{@fib_java}:0:13", Seafoam::Formatters::Json)
        decoded = JSON.parse(@out.string)

        expect(decoded).to(eq({
          "input" => [
            {
              "from" => { "id" => "6", "label" => "Begin" },
              "to" => { "id" => "13", "label" => "Call Fib.fib" },
              "label" => nil,
            },
            {
              "from" => { "id" => "14", "label" => "FrameState Fib#fib Fib.java:20" },
              "to" => { "id" => "13", "label" => "Call Fib.fib" },
              "label" => nil,
            },
            {
              "from" => { "id" => "12", "label" => "MethodCallTarget" },
              "to" => { "id" => "13", "label" => "Call Fib.fib" },
              "label" => nil,
            },
          ],
          "output" => [
            {
              "from" => { "id" => "13", "label" => "Call Fib.fib" },
              "to" => { "id" => "18", "label" => "Call Fib.fib" },
              "label" => nil,
            },
            {
              "from" => { "id" => "13", "label" => "Call Fib.fib" },
              "to" => { "id" => "14", "label" => "FrameState Fib#fib Fib.java:20" },
              "label" => "values",
            },
            {
              "from" => { "id" => "13", "label" => "Call Fib.fib" },
              "to" => { "id" => "19", "label" => "FrameState Fib#fib Fib.java:20" },
              "label" => "values",
            },
            {
              "from" => { "id" => "13", "label" => "Call Fib.fib" },
              "to" => { "id" => "20", "label" => "+" },
              "label" => "x",
            },
          ],
        }))
      end

      it "prints details for an edge" do
        @commands.send(:edges, "#{@fib_java}:0:13-18", Seafoam::Formatters::Json)
        decoded = JSON.parse(@out.string)

        expect(decoded).to(eq([
          {
            "from" => { "id" => "13", "label" => "Call Fib.fib" },
            "to" => { "id" => "18", "label" => "Call Fib.fib" },
            "label" => nil,
          },
        ]))
      end

      it "does not work on a file" do
        expect { @commands.send(:edges, @fib_java, Seafoam::Formatters::Json) }.to(raise_error(ArgumentError))
      end
    end
  end

  describe "#props" do
    it "prints properties for a file" do
      @commands.send(:props, @fib_java)
      expect(@out.string.gsub("\n\n", "\n")).to(eq("{\n  \"vm.uuid\": \"21734\"\n}\n"))
    end

    it "prints properties for a graph" do
      @commands.send(:props, "#{@fib_java}:0")
      expect(@out.string).to(include('"scope": "main.Compiling.GraalCompiler.FrontEnd"'))
    end

    it "prints properties for a node" do
      @commands.send(:props, "#{@fib_java}:0:13")
      expect(@out.string).to(include('"declaring_class": "Fib"'))
    end

    it "prints properties for an edge" do
      @commands.send(:props, "#{@fib_java}:0:13-18")
      lines = @out.string.lines.map(&:rstrip)
      expect(lines[2]).to(include('"name": "next"'))
    end
  end

  describe "#source" do
    describe "txt format" do
      it "prints source information for a node" do
        @commands.send(:source, "#{@fib_ruby}:2:2436", Seafoam::Formatters::Text)
        expect(@out.string).to(eq(<<~SOURCE))
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
        SOURCE
      end
    end

    describe "json format" do
      it "prints source information for a node" do
        @commands.send(:source, "#{@fib_ruby}:2:2436", Seafoam::Formatters::Json)
        decoded = JSON.parse(@out.string)
        expect(decoded).to(eq([
          { "class" => "java.lang.Math", "method" => "addExact" },
          { "class" => "org.truffleruby.core.numeric.IntegerNodes$AddNode", "method" => "add" },
          {
            "class" => "org.truffleruby.core.numeric.IntegerNodesFactory$AddNodeFactory$AddNodeGen",
            "method" => "executeAdd",
          },
          { "class" => "org.truffleruby.core.inlined.InlinedAddNode", "method" => "intAdd" },
          { "class" => "org.truffleruby.core.inlined.InlinedAddNodeGen", "method" => "execute" },
          { "class" => "org.truffleruby.language.control.IfElseNode", "method" => "execute" },
          { "class" => "org.truffleruby.language.control.SequenceNode", "method" => "execute" },
          { "class" => "org.truffleruby.language.RubyMethodRootNode", "method" => "execute" },
          { "class" => "org.graalvm.compiler.truffle.runtime.OptimizedCallTarget", "method" => "executeRootNode" },
          { "class" => "org.graalvm.compiler.truffle.runtime.OptimizedCallTarget", "method" => "profiledPERoot" },
        ]))
      end
    end
  end

  describe "#render" do
    it "does not work on a file" do
      expect { @commands.send(:render, @fib_java) }.to(raise_error(ArgumentError))
    end

    it "can render all BGV files to dot" do
      Seafoam::SpecHelpers::SAMPLE_BGV.each do |file|
        Dir.mktmpdir do |dir|
          @commands.send(:render, "#{file}:2", "--out", "#{dir}/out.dot")
        end
      end
    end

    it "supports --out out.dot" do
      Dir.mktmpdir do |dir|
        @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.dot")
        expect(%x(file #{dir}/out.dot)).to(start_with("#{dir}/out.dot: ASCII text"))
      end
    end

    it "supports --out out.mmd" do
      Dir.mktmpdir do |dir|
        @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.mmd")
        expect(File.read("#{dir}/out.mmd")).to(start_with("flowchart TD"))
      end
    end

    it "supports --out out.md" do
      Dir.mktmpdir do |dir|
        @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.md")
        expect(File.read("#{dir}/out.md")).to(start_with("```mermaid"))
      end
    end

    it "supports --md" do
      @commands.send(:render, "#{@fib_java}:0", "--md")
      expect(@out.string).to(start_with("```mermaid"))
    end

    it "supports spotlighting nodes" do
      Dir.mktmpdir do |dir|
        @commands.send(:render, "#{@fib_java}:0", "--spotlight", "13", "--out", "#{dir}/out.dot")
      end
    end

    if Seafoam::SpecHelpers.dependencies_installed?
      it "supports --out out.pdf" do
        Dir.mktmpdir do |dir|
          @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.pdf")
          expect(%x(file #{dir}/out.pdf)).to(start_with("#{dir}/out.pdf: PDF document"))
        end
      end

      it "supports --out out.svg" do
        Dir.mktmpdir do |dir|
          @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.svg")
          expect(%x(file #{dir}/out.svg)).to(start_with("#{dir}/out.svg: SVG Scalable Vector Graphics image"))
        end
      end

      it "supports --out out.png" do
        Dir.mktmpdir do |dir|
          @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.png")
          expect(%x(file #{dir}/out.png)).to(start_with("#{dir}/out.png: PNG image data"))
        end
      end
    else
      it "raises an exception if Graphviz is not installed" do
        expect do
          Dir.mktmpdir do |dir|
            @commands.send(:render, "#{@fib_java}:0", "--out", "#{dir}/out.pdf")
          end
        end.to(raise_error(RuntimeError, /Could not run Graphviz - is it installed?/))
      end
    end

    it "does not work on a node" do
      expect { @commands.send(:render, "#{@fib_java}:0:13") }.to(raise_error(ArgumentError))
    end
  end

  describe "#debug" do
    it "does not work with a graph" do
      expect { @commands.send(:debug, "#{@fib_java}:0") }.to(raise_error(ArgumentError))
    end
  end

  describe "#describe" do
    describe "txt format" do
      it "does not work if a graph index is not supplied" do
        expect { @commands.send(:describe, @fib_java, Seafoam::Formatters::Text) }.to(raise_error(ArgumentError))
      end

      it "prints a description of a particular graph index" do
        @commands.send(:describe, "#{@fib_java}:4", Seafoam::Formatters::Text)
        expect(@out.string).to(eq(<<~EXPECTED))
          16 nodes, branches, calls
          AddNode: 3
          ConstantNode: 3
          HotSpotDirectCallTargetNode: 2
          InvokeNode: 2
          ReturnNode: 2
          IfNode: 1
          IntegerLessThanNode: 1
          ParameterNode: 1
          StartNode: 1
        EXPECTED
      end
    end

    describe "json format" do
      it "does not work if a graph index is not supplied" do
        expect { @commands.send(:describe, @fib_java, Seafoam::Formatters::Json) }.to(raise_error(ArgumentError))
      end

      it "prints a description of a particular graph index" do
        @commands.send(:describe, "#{@fib_java}:4", Seafoam::Formatters::Json)
        decoded = JSON.parse(@out.string)
        expected = {
          "branches" => true,
          "calls" => true,
          "loops" => false,
          "deopts" => false,
          "linear" => false,
          "node_count" => 16,
          "node_counts" => {
            "AddNode" => 3,
            "ConstantNode" => 3,
            "HotSpotDirectCallTargetNode" => 2,
            "InvokeNode" => 2,
            "ReturnNode" => 2,
            "IfNode" => 1,
            "IntegerLessThanNode" => 1,
            "ParameterNode" => 1,
            "StartNode" => 1,
          },
        }
        expect(decoded).to(eq(expected))
      end
    end
  end

  describe "#help" do
    it "does not take any arguments" do
      expect { @commands.send(:seafoam, "--help", "foo") }.to(raise_error(ArgumentError))
    end
  end

  describe "#version" do
    it "does not take any arguments" do
      expect { @commands.send(:version, "foo") }.to(raise_error(ArgumentError))
    end
  end

  describe "#parse_name" do
    it "parses file.bgv" do
      file, graph, node, edge = @commands.send(:parse_name, "file.bgv")
      expect(file).to(eq("file.bgv"))
      expect(graph).to(be_nil)
      expect(node).to(be_nil)
      expect(edge).to(be_nil)
    end

    it "parses file.bgv:14" do
      file, graph, node, edge = @commands.send(:parse_name, "file.bgv:14")
      expect(file).to(eq("file.bgv"))
      expect(graph).to(eq(14))
      expect(node).to(be_nil)
      expect(edge).to(be_nil)
    end

    it "parses file.bgv:14:12" do
      file, graph, node, edge = @commands.send(:parse_name, "file.bgv:14:12")
      expect(file).to(eq("file.bgv"))
      expect(graph).to(eq(14))
      expect(node).to(eq(12))
      expect(edge).to(be_nil)
    end

    it "parses file.bgv:14:12-81" do
      file, graph, node, edge = @commands.send(:parse_name, "file.bgv:14:12-81")
      expect(file).to(eq("file.bgv"))
      expect(graph).to(eq(14))
      expect(node).to(eq(12))
      expect(edge).to(eq(81))
    end

    it "parses a realistic knarly BGV file name" do
      # rubocop:disable Layout/LineLength
      file_name = "../graal_dumps/2019.11.03.19.35.03.828/TruffleHotSpotCompilation-13320[while_loop_at__Users_chrisseaton_src_github.com_Shopify_truffleruby-shopify_src_main_ruby_truffleruby_core_kernel.rb:360<OSR>].bgv"
      # rubocop:enable Layout/LineLength
      file, graph, node, edge = @commands.send(:parse_name, "#{file_name}:14:12-81")
      expect(file).to(eq(file_name))
      expect(graph).to(eq(14))
      expect(node).to(eq(12))
      expect(edge).to(eq(81))
    end

    it "parses a BGV file name with periods and colons" do
      file_name = "TruffleHotSpotCompilation-13029[Truffle::ThreadOperations.detect_recursion_<split-3a5973bc>].bgv"
      file, graph, node, edge = @commands.send(:parse_name, "#{file_name}:4")
      expect(file).to(eq(file_name))
      expect(graph).to(eq(4))
      expect(node).to(be_nil)
      expect(edge).to(be_nil)
    end

    it "parses a BGV.gz file name with periods and colons" do
      file_name = "TruffleHotSpotCompilation-13029[Truffle::ThreadOperations.detect_recursion_<split-3a5973bc>].bgv.gz"
      file, graph, node, edge = @commands.send(:parse_name, "#{file_name}:4")
      expect(file).to(eq(file_name))
      expect(graph).to(eq(4))
      expect(node).to(be_nil)
      expect(edge).to(be_nil)
    end
  end
end
