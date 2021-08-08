require 'pathname'

GraalVM = Struct.new(:url, :dir) do
  def name
    dir
  end

  def tarball
    @tarball ||= File.basename(url)
  end
end

GraalVM_21_2_0 = GraalVM.new('https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-21.2.0/graalvm-ce-java11-darwin-amd64-21.2.0.tar.gz', 'graalvm-ce-java11-21.2.0')

GRAAL_VMS = [
  GraalVM_21_2_0
]

Dir.chdir 'tools' do
  GRAAL_VMS.each do |graalvm|
    system 'curl', '-OL', graalvm.url unless File.exist?(graalvm.tarball)
    Dir.mkdir graalvm.name unless Dir.exist?(graalvm.name)
    Dir.chdir graalvm.name do
      Dir.mkdir "../../examples/#{graalvm.name}" unless Dir.exist?("../../examples/#{graalvm.name}")

      bin = "#{graalvm.dir}/Contents/Home/bin"

      unless Dir.exist?(graalvm.dir)
        system 'tar', '-zxf', "../#{graalvm.tarball}"
        system "#{bin}/gu", 'install', 'nodejs'
        system "#{bin}/gu", 'install', 'ruby'
      end

      system 'cp', '../../examples/Fib.java', '.'
      system "#{bin}/javac", 'Fib.java'

      system 'rm', '-rf', 'graal_dumps'
      pipe = IO.popen(["#{bin}/java", '-XX:CompileOnly=Fib::fib', '-XX:+PrintCompilation', '-Dgraal.Dump=:1', '-Dgraal.PrintBackendCFG=true', '-Dgraal.PrintGraphWithSchedule=true', 'Fib', '14'])
      loop do
        line = pipe.gets
        break if line =~ /4\s+Fib::fib/
      end
      sleep 3
      Process.kill 'KILL', pipe.pid
      Process.wait pipe.pid

      bgv = Dir.glob('graal_dumps/**/*.bgv')
      cfg = Dir.glob('graal_dumps/**/*.cfg')
      raise unless bgv.size == 1
      raise unless cfg.size == 1

      system 'cp', bgv.first, 'fib-java.bgv'
      system 'cp', cfg.first, 'fib-java.cfg'
      system 'gzip', '-f', 'fib-java.bgv'
      system 'gzip', '-f', 'fib-java.cfg'
      system 'cp', 'fib-java.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-java.cfg.gz', "../../examples/#{graalvm.name}"

      if graalvm == GRAAL_VMS.first
        system 'cp', 'fib-java.bgv.gz', '../../examples'
        system 'cp', 'fib-java.cfg.gz', '../../examples'
      end

      system 'cp', '../../examples/java/JavaExamples.java', '.'
      system "#{bin}/javac", 'JavaExamples.java'

      system 'rm', '-rf', 'graal_dumps'
      pipe = IO.popen(["#{bin}/java", '-XX:-UseOnStackReplacement', \
                       '-XX:CompileCommand=dontinline,*::*', \
                       '-XX:+PrintCompilation', \
                       '-Dgraal.PrintBackendCFG=true', \
                       '-Dgraal.PrintGraphWithSchedule=true', \
                       '-Dgraal.Dump=:3', 'JavaExamples'])
      loop do
        line = pipe.gets if select([pipe], nil, nil, 5)
        break if line.nil? || line =~ /4\s+Fib::fib/
      end
      sleep 3
      Process.kill 'KILL', pipe.pid
      Process.wait pipe.pid

      Dir.mkdir 'java' unless Dir.exist?('java')
      Dir.mkdir "../../examples/#{graalvm.name}/java" unless Dir.exist?("../../examples/#{graalvm.name}/java")
      Dir.glob 'graal_dumps/**/*\\[JavaExamples\\.example*.bgv' do |bgv_file|
        cfg_file = Pathname.new(bgv_file).sub_ext('.cfg').to_s
        bgv_file =~ /HotSpotCompilation-\d+\[JavaExamples\.(.+)\(/
        method = Regexp.last_match(1)
        system 'cp', bgv_file, "#{method}.bgv"
        system 'cp', cfg_file, "#{method}.cfg"
        system 'gzip', '-f', "#{method}.bgv"
        system 'gzip', '-f', "#{method}.cfg"
        system 'cp', "#{method}.bgv.gz", "../../examples/#{graalvm.name}/java"
        system 'cp', "#{method}.cfg.gz", "../../examples/#{graalvm.name}/java"

        if graalvm == GRAAL_VMS.first
          system 'cp', "#{method}.bgv.gz", '../../examples/java'
          system 'cp', "#{method}.cfg.gz", '../../examples/java'
        end
      end

      system 'rm', '-rf', 'graal_dumps'
      pipe = IO.popen(["#{bin}/node", '--experimental-options', \
                       '--engine.CompileOnly=fib', '--engine.TraceCompilation', \
                       '--engine.MultiTier=false', '--engine.Inlining=false', \
                       '--vm.Dgraal.Dump=Truffle:1', '--vm.Dgraal.PrintBackendCFG=true', \
                       '../../examples/fib.js', '14'], { err: %i[child out] })
      loop do
        line = pipe.gets
        break if line =~ /opt done\s+fib/
      end
      sleep 3
      Process.kill 'KILL', pipe.pid
      Process.wait pipe.pid

      bgv = Dir.glob('graal_dumps/**/*_fib\\].bgv')
      bgv_ast = Dir.glob('graal_dumps/**/*\\[fib\\].bgv')
      cfg = Dir.glob('graal_dumps/**/*_fib\\].cfg')
      raise unless bgv.size == 1
      raise unless bgv_ast.size == 1
      raise unless cfg.size == 1

      system 'cp', bgv.first, 'fib-js.bgv'
      system 'cp', bgv_ast.first, 'fib-js-ast.bgv'
      system 'cp', cfg.first, 'fib-js.cfg'
      system 'gzip', '-f', 'fib-js.bgv'
      system 'gzip', '-f', 'fib-js-ast.bgv'
      system 'gzip', '-f', 'fib-js.cfg'
      system 'cp', 'fib-js.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-js-ast.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-js.cfg.gz', "../../examples/#{graalvm.name}"

      if graalvm == GRAAL_VMS.first
        system 'cp', 'fib-js.bgv.gz', '../../examples/fib-js.bgv.gz'
        system 'cp', 'fib-js-ast.bgv.gz', '../../examples/fib-js-ast.bgv.gz'
        system 'cp', 'fib-js.cfg.gz', '../../examples/fib-js.cfg.gz'
      end

      system 'rm', '-rf', 'graal_dumps'
      pipe = IO.popen(["#{bin}/ruby", '--jvm', '--experimental-options', \
                       '--engine.CompileOnly=fib', '--engine.TraceCompilation', \
                       '--engine.NodeSourcePositions', '--engine.MultiTier=false', \
                       '--engine.Inlining=false', '--vm.Dgraal.Dump=Truffle:1', \
                       '--vm.Dgraal.PrintBackendCFG=true', '../../examples/fib.rb', \
                       '14'], { err: %i[child out] })
      loop do
        line = pipe.gets
        break if line =~ /opt done\s+Object#fib/
      end
      sleep 3
      Process.kill 'KILL', pipe.pid
      Process.wait pipe.pid

      bgv = Dir.glob('graal_dumps/**/*\\[Object#fib\\].bgv')
      bgv_ast = Dir.glob('graal_dumps/**/*\\[Object#fib\\]_1.bgv')
      cfg = Dir.glob('graal_dumps/**/*\\[Object#fib\\].bgv')
      raise unless bgv.size == 1
      raise unless bgv_ast.size == 1
      raise unless cfg.size == 1

      system 'cp', bgv.first, 'fib-ruby.bgv'
      system 'cp', bgv_ast.first, 'fib-ruby-ast.bgv'
      system 'cp', cfg.first, 'fib-ruby.cfg'
      system 'gzip', '-f', 'fib-ruby.bgv'
      system 'gzip', '-f', 'fib-ruby-ast.bgv'
      system 'gzip', '-f', 'fib-ruby.cfg'
      system 'cp', 'fib-ruby.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-ruby-ast.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-ruby.cfg.gz', "../../examples/#{graalvm.name}"

      if graalvm == GRAAL_VMS.first
        system 'cp', 'fib-ruby.bgv.gz', '../../examples'
        system 'cp', 'fib-ruby-ast.bgv.gz', '../../examples'
        system 'cp', 'fib-ruby.cfg.gz', '../../examples'
      end
    end
  end
end
