#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
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
GraalVM_22_3_1 = GraalVM.new('https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.1/graalvm-ce-java17-darwin-amd64-22.3.1.tar.gz', 'graalvm-ce-java17-22.3.1')

GRAAL_VMS = [
  GraalVM_22_3_1,
  GraalVM_21_2_0
]

def run_java(bin, dump_level, *args)
  FileUtils.rm_rf('./graal_dumps')

  pipe = IO.popen(["#{bin}/java", \
                   '-XX:+PrintCompilation', \
                   '-Dgraal.PrintGraphWithSchedule=true', \
                   "-Dgraal.Dump=:#{dump_level}"] + args)

  yield pipe

  sleep 3
  Process.kill 'KILL', pipe.pid
  Process.wait pipe.pid
end

def run_js(bin, *args)
  FileUtils.rm_rf('graal_dumps')

  pipe = IO.popen(["#{bin}/node", '--experimental-options', \
                   '--engine.CompileOnly=fib', '--engine.TraceCompilation', \
                   '--engine.MultiTier=false', '--engine.Inlining=false', \
                   '--vm.Dgraal.Dump=Truffle:1'] + args, { err: %i[child out] })

  yield pipe

  sleep 3
  Process.kill 'KILL', pipe.pid
  Process.wait pipe.pid
end

def run_ruby(bin, *args)
  FileUtils.rm_rf('./graal_dumps')

  pipe = IO.popen(["#{bin}/ruby", '--jvm', '--experimental-options', \
                   '--engine.TraceCompilation', \
                   '--engine.NodeSourcePositions', '--engine.MultiTier=false', \
                   '--engine.Inlining=false', '--vm.Dgraal.Dump=Truffle:1'] + args, { err: %i[child out] })

  yield pipe

  sleep 3
  Process.kill 'KILL', pipe.pid
  Process.wait pipe.pid
end

def process_examples(graalvm, language, pattern)
  Dir.mkdir language unless Dir.exist?(language)
  Dir.mkdir "../../examples/#{graalvm.name}/#{language}" unless Dir.exist?("../../examples/#{graalvm.name}/#{language}")
  Dir.glob "graal_dumps/**/*\\[#{Regexp.escape(pattern)}example*.bgv" do |bgv_file|
    next if bgv_file.end_with?('_1.bgv') # The AST graphs have the same name as the primary graph with a '_1' suffix. Skip them.
    bgv_file =~ /HotSpotCompilation-\d+\[#{Regexp.escape(pattern)}(.+?)[\(\]]/
    method = Regexp.last_match(1)

    system 'cp', bgv_file, "#{method}.bgv"

    system 'gzip', '-f', "#{method}.bgv"
    system 'cp', "#{method}.bgv.gz", "../../examples/#{graalvm.name}/#{language}"

    if graalvm == GRAAL_VMS.first
      FileUtils.ln_sf "../../examples/#{graalvm.name}/#{language}/#{method}.bgv.gz", "../../examples/#{language}"
    end
  end
end

def log(graalvm, message)
  puts "#{graalvm.name}: #{message}"
end

Dir.chdir 'tools' do
  GRAAL_VMS.each do |graalvm|
    system 'curl', '-OL', graalvm.url unless File.exist?(graalvm.tarball)
    Dir.mkdir graalvm.name unless Dir.exist?(graalvm.name)
    Dir.chdir graalvm.name do
      Dir.mkdir "../../examples/#{graalvm.name}" unless Dir.exist?("../../examples/#{graalvm.name}")

      bin = "#{graalvm.dir}/Contents/Home/bin"

      log(graalvm, "Installing Truffle languages.")

      unless Dir.exist?(graalvm.dir)
        system 'tar', '-zxf', "../#{graalvm.tarball}"
        system "#{bin}/gu", 'install', 'nodejs'
        system "#{bin}/gu", 'install', 'ruby'
      end


      ###########################
      ##### Java: Fibonacci #####
      ###########################

      log(graalvm, "Running Fibonacci in Java.")

      system 'cp', '../../examples/Fib.java', '.'
      system "#{bin}/javac", 'Fib.java'

      run_java(bin, 1, '-XX:CompileOnly=Fib::fib', 'Fib', '14') do |pipe|
        loop do
          line = pipe.gets
          break if line =~ /4\s+Fib::fib/
        end
      end

      bgv = Dir.glob('graal_dumps/**/*.bgv')
      raise unless bgv.size == 1

      system 'cp', bgv.first, 'fib-java.bgv'
      system 'gzip', '-f', 'fib-java.bgv'
      system 'cp', 'fib-java.bgv.gz', "../../examples/#{graalvm.name}"

      if graalvm == GRAAL_VMS.first
        FileUtils.ln_sf "../../examples/#{graalvm.name}/fib-java.bgv.gz", '../../examples'
      end



      ###########################
      ##### Java: Examples  #####
      ###########################

      log(graalvm, "Running Java examples.")

      system 'cp', '../../examples/java/JavaExamples.java', '.'
      system "#{bin}/javac", 'JavaExamples.java'

      run_java(bin, 3, '-XX:-UseOnStackReplacement', '-XX:CompileCommand=dontinline,*::*', 'JavaExamples') do |pipe|
        loop do
          line = pipe.gets if select([pipe], nil, nil, 5)
          break if line.nil? || line =~ /4\s+Fib::fib/
        end
      end

      process_examples(graalvm, 'java', 'JavaExamples.')



      #################################
      ##### JavaScript: Fibonacci #####
      #################################

      log(graalvm, "Running Fibonacci in JavaScript.")

      run_js(bin, '../../examples/fib.js', '14') do |pipe|
        loop do
          line = pipe.gets
          break if line =~ /opt done\s+(?:id=\d+\s+)?fib/
        end
      end

      bgv = Dir.glob('graal_dumps/**/*_fib\\].bgv')
      bgv_ast = Dir.glob('graal_dumps/**/*\\[fib\\].bgv')
      raise unless bgv.size == 1
      raise unless bgv_ast.size == 1

      system 'cp', bgv.first, 'fib-js.bgv'
      system 'cp', bgv_ast.first, 'fib-js-ast.bgv'
      system 'gzip', '-f', 'fib-js.bgv'
      system 'gzip', '-f', 'fib-js-ast.bgv'
      system 'cp', 'fib-js.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-js-ast.bgv.gz', "../../examples/#{graalvm.name}"

      if graalvm == GRAAL_VMS.first
        FileUtils.ln_sf "../../examples/#{graalvm.name}/fib-js.bgv.gz", '../../examples/'
        FileUtils.ln_sf  "../../examples/#{graalvm.name}/fib-js-ast.bgv.gz", '../../examples/'
      end



      ###########################
      ##### Ruby: Fibonacci #####
      ###########################

      log(graalvm, "Running Fibonacci in Ruby.")

      run_ruby(bin, '--engine.CompileOnly=fib', '../../examples/fib.rb', '14') do |pipe|
        loop do
          line = pipe.gets
          break if line =~ /opt done\s+(?:id=\d+\s+)?Object#fib/
        end
      end

      bgv = Dir.glob('graal_dumps/**/*\\[Object#fib\\].bgv')
      bgv_ast = Dir.glob('graal_dumps/**/*\\[Object#fib\\]_1.bgv')
      raise unless bgv.size == 1
      raise unless bgv_ast.size == 1

      system 'cp', bgv.first, 'fib-ruby.bgv'
      system 'cp', bgv_ast.first, 'fib-ruby-ast.bgv'
      system 'gzip', '-f', 'fib-ruby.bgv'
      system 'gzip', '-f', 'fib-ruby-ast.bgv'
      system 'cp', 'fib-ruby.bgv.gz', "../../examples/#{graalvm.name}"
      system 'cp', 'fib-ruby-ast.bgv.gz', "../../examples/#{graalvm.name}"

      if graalvm == GRAAL_VMS.first
        FileUtils.ln_sf "../../examples/#{graalvm.name}/fib-ruby.bgv.gz", '../../examples'
        FileUtils.ln_sf "../../examples/#{graalvm.name}/fib-ruby-ast.bgv.gz", '../../examples'
      end



      ###########################
      ##### Ruby: Examples  #####
      ###########################

      # Older GraalVM instances did not support the `--engine.InlineOnly` option. We had to manually patch Graal to
      # add the inlining support. This script does not manually build GraalVM. Rather, the older graphs were manually
      # created and added to this repo. They can be retrieved via git.
      unless graalvm == GraalVM_21_2_0
        run_ruby(bin, '--engine.OSR=false', '--engine.InlineOnly=~Object#opaque_,~Object#static_call,~ExampleObject#instance_call', '../../examples/ruby/ruby_examples.rb') do |pipe|
          loop do
            line = pipe.gets if select([pipe], nil, nil, 5)
            break if line.nil?
          end
        end

        process_examples(graalvm, 'ruby', 'Object#')
      end
    end
  end
end
