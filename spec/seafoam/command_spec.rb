require 'stringio'
require 'tempfile'

require 'seafoam'

require 'rspec'

describe Seafoam::Commands do
  before :all do
    @fib_java = File.expand_path('../../examples/fib-java.bgv', __dir__)
  end

  before :each do
    @out = StringIO.new
    @commands = Seafoam::Commands.new(@out, {})
  end

  describe '#info' do
    it 'prints format and version' do
      @commands.send :info, @fib_java
      lines = @out.string.lines.map(&:rstrip)
      expect(lines.first).to eq 'BGV 6.1'
    end

    it 'does not work on a graph' do
      expect { @commands.send :info, "#{@fib_java}:0" }.to raise_error(ArgumentError)
    end
  end

  describe '#list' do
    it 'prints graphs' do
      @commands.send :list, @fib_java
      lines = @out.string.lines.map(&:rstrip)
      expect(lines.take(5)).to eq [
        "#{@fib_java}:0  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:1  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:2  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:3  2:Fib.fib(int)/After parsing",
        "#{@fib_java}:4  2:Fib.fib(int)/After phase %s"
      ]
      expect(lines.drop(lines.length - 5)).to eq [
        "#{@fib_java}:46  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:47  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:48  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:49  2:Fib.fib(int)/After phase %s",
        "#{@fib_java}:50  2:Fib.fib(int)/After low tier"
      ]
    end

    it 'does not work on a graph' do
      expect { @commands.send :list, "#{@fib_java}:0" }.to raise_error(ArgumentError)
    end
  end

  describe '#search' do
    it 'finds terms in files' do
      @commands.send :search, @fib_java, 'MethodCallTarget'
      lines = @out.string.lines.map(&:rstrip)
      expect(lines.take(5)).to eq [
        "#{@fib_java}:0:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:0:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:1:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:1:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:2:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir..."
      ]
    end

    it 'finds terms in graphs' do
      @commands.send :search, "#{@fib_java}:0", 'MethodCallTarget'
      lines = @out.string.lines.map(&:rstrip)
      expect(lines).to eq [
        "#{@fib_java}:0:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:0:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir..."
      ]
    end

    it 'is case-insensitive' do
      @commands.send :search, @fib_java, 'methodcalltarget'
      lines = @out.string.lines.map(&:rstrip)
      expect(lines.take(5)).to eq [
        "#{@fib_java}:0:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:0:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:1:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:1:17  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir...",
        "#{@fib_java}:2:12  ...class\":\"org.graalvm.compiler.nodes.java.MethodCallTargetNode\",\"name_template\":\"\",\"inputs\":[{\"dir..."
      ]
    end

    it 'does not work on a node' do
      expect { @commands.send :search, "#{@fib_java}:0:0" }.to raise_error(ArgumentError)
    end
  end

  describe '#edges' do
    it 'prints the number of edges and nodes for a graph' do
      @commands.send :edges, "#{@fib_java}:0"
      lines = @out.string.lines.map(&:rstrip)
      expect(lines.first).to eq '22 nodes, 30 edges'
    end

    it 'prints the edges for a node' do
      @commands.send :edges, "#{@fib_java}:0:13"
      lines = @out.string.lines.map(&:rstrip)
      expect(lines).to eq [
        'Input:',
        '  13 (Call Fib.fib) <-() 6 (Begin)',
        '  13 (Call Fib.fib) <-() 14 (@{:declaring_class=>"Fib", :method_name=>"fib", :signature=>{:args=>["I"], :ret=>"I"}, :modifiers=>9}:13)',
        '  13 (Call Fib.fib) <-() 12 (MethodCallTarget)',
        'Output:',
        '  13 (Call Fib.fib) ->() 18 (Call Fib.fib)',
        '  13 (Call Fib.fib) ->(values) 14 (@{:declaring_class=>"Fib", :method_name=>"fib", :signature=>{:args=>["I"], :ret=>"I"}, :modifiers=>9}:13)',
        '  13 (Call Fib.fib) ->(values) 19 (@{:declaring_class=>"Fib", :method_name=>"fib", :signature=>{:args=>["I"], :ret=>"I"}, :modifiers=>9}:19)',
        '  13 (Call Fib.fib) ->(x) 20 (+)'
      ]
    end

    it 'prints details for an edge' do
      @commands.send :edges, "#{@fib_java}:0:13-18"
      lines = @out.string.lines.map(&:rstrip)
      expect(lines.first).to eq '13 (Call Fib.fib) ->() 18 (Call Fib.fib)'
    end

    it 'does not work on a file' do
      expect { @commands.send :edges, @fib_java }.to raise_error(ArgumentError)
    end
  end

  describe '#props' do
    it 'does not work on a file' do
      expect { @commands.send :props, @fib_java }.to raise_error(ArgumentError)
    end

    it 'prints properties for a graph' do
      @commands.send :props, "#{@fib_java}:0"
      lines = @out.string.lines.map(&:rstrip)
      expect(lines[3]).to include '"name": "2:Fib.fib(int)"'
    end

    it 'prints properties for a node' do
      @commands.send :props, "#{@fib_java}:0:13"
      lines = @out.string.lines.map(&:rstrip)
      expect(lines[3]).to include '"declaring_class": "Fib"'
    end

    it 'prints properties for an edge' do
      @commands.send :props, "#{@fib_java}:0:13-18"
      lines = @out.string.lines.map(&:rstrip)
      expect(lines[2]).to include '"name": "next"'
    end
  end

  describe '#render' do
    before :all do
      @all_bgv = Dir.glob(File.expand_path('../../examples/*.bgv', __dir__))
    end

    it 'does not work on a file' do
      expect { @commands.send :render, @fib_java }.to raise_error(ArgumentError)
    end

    it 'can render all BGV files to dot' do
      @all_bgv.each do |file|
        @commands.send :render, "#{file}:7", '--out', 'out.dot'
      end
    end

    it 'supports -o out.pdf' do
      @commands.send :render, "#{@fib_java}:0", '--out', 'out.pdf'
      expect(`file out.pdf`).to start_with 'out.pdf: PDF document'
    end

    it 'supports -o out.svg' do
      @commands.send :render, "#{@fib_java}:0", '--out', 'out.svg'
      expect(`file out.svg`).to start_with 'out.svg: SVG Scalable Vector Graphics image'
    end

    it 'supports -o out.png' do
      @commands.send :render, "#{@fib_java}:0", '--out', 'out.png'
      expect(`file out.png`).to start_with 'out.png: PNG image data'
    end

    it 'supports -o out.dot' do
      @commands.send :render, "#{@fib_java}:0", '--out', 'out.dot'
      expect(`file out.dot`).to start_with 'out.dot: ASCII text'
    end

    it 'supports spotlighting nodes' do
      @commands.send :render, "#{@fib_java}:0", '--spotlight', '13'
    end

    it 'does not work on a node' do
      expect { @commands.send :render, "#{@fib_java}:0:13" }.to raise_error(ArgumentError)
    end
  end

  describe '#debug' do
    it 'does not work with a graph' do
      expect { @commands.send :debug, "#{@fib_java}:0" }.to raise_error(ArgumentError)
    end
  end

  describe '#help' do
    it 'does not take any arguments' do
      expect { @commands.send :help, 'foo' }.to raise_error(ArgumentError)
    end
  end

  describe '#version' do
    it 'does not take any arguments' do
      expect { @commands.send :help, 'foo' }.to raise_error(ArgumentError)
    end
  end

  describe '#parse_name' do
    it 'parses file.bgv' do
      file, graph, node, edge = @commands.send(:parse_name, 'file.bgv')
      expect(file).to eq 'file.bgv'
      expect(graph).to be_nil
      expect(node).to be_nil
      expect(edge).to be_nil
    end

    it 'parses file.bgv:14' do
      file, graph, node, edge = @commands.send(:parse_name, 'file.bgv:14')
      expect(file).to eq 'file.bgv'
      expect(graph).to eq 14
      expect(node).to be_nil
      expect(edge).to be_nil
    end

    it 'parses file.bgv:14:12' do
      file, graph, node, edge = @commands.send(:parse_name, 'file.bgv:14:12')
      expect(file).to eq 'file.bgv'
      expect(graph).to eq 14
      expect(node).to eq 12
      expect(edge).to be_nil
    end

    it 'parses file.bgv:14:12-81' do
      file, graph, node, edge = @commands.send(:parse_name, 'file.bgv:14:12-81')
      expect(file).to eq 'file.bgv'
      expect(graph).to eq 14
      expect(node).to eq 12
      expect(edge).to eq 81
    end

    it 'parses a realistic knarly BGV file name' do
      file, graph, node, edge = @commands.send(:parse_name, '../graal_dumps/2019.11.03.19.35.03.828/TruffleHotSpotCompilation-13320[while_loop_at__Users_chrisseaton_src_github.com_Shopify_truffleruby-shopify_src_main_ruby_truffleruby_core_kernel.rb:360<OSR>].bgv:14:12-81')
      expect(file).to eq '../graal_dumps/2019.11.03.19.35.03.828/TruffleHotSpotCompilation-13320[while_loop_at__Users_chrisseaton_src_github.com_Shopify_truffleruby-shopify_src_main_ruby_truffleruby_core_kernel.rb:360<OSR>].bgv'
      expect(graph).to eq 14
      expect(node).to eq 12
      expect(edge).to eq 81
    end
  end
end
