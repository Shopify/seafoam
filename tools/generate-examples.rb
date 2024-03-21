#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "pathname"

VERBOSE = false
EXAMPLES_DIR = File.expand_path("../examples", __dir__)

GraalVMOld = Struct.new(:url, :dir) do
  def name
    dir
  end

  def tarball
    @tarball ||= File.basename(url)
  end

  def install
    system("curl", "-OL", url) unless File.exist?(tarball)
    FileUtils.mkdir_p(name)
    FileUtils.mkdir_p(File.join(EXAMPLES_DIR, name))

    Dir.chdir(name) do
      log(self, "Installing Truffle languages.")

      bin = "#{dir}/Contents/Home/bin"

      unless Dir.exist?(dir)
        system("tar", "-zxf", "../#{tarball}")
        system("#{bin}/gu", "install", "nodejs")
        system("#{bin}/gu", "install", "ruby")
      end
    end
  end

  def java_context(&block)
    Dir.chdir(name) do
      block.call("#{dir}/Contents/Home/bin")
    end
  end

  def options_version
    1
  end

  alias_method :js_context, :java_context
  alias_method :ruby_context, :java_context
end

GraalVM = Struct.new(:java_version, :truffle_version, :community_edition, :dir) do
  def name
    dir
  end

  def install
    FileUtils.mkdir_p(name)

    Dir.chdir(name) do
      FileUtils.mkdir_p("#{EXAMPLES_DIR}/#{name}")

      # Install the JDK.
      log(self, "Installing JDK.")
      install_distribution("java")

      # Install GraalJS.
      log(self, "Installing GraalJS.")
      install_distribution("js")

      # Install TruffleRuby.
      log(self, "Installing TruffleRuby.")
      install_distribution("ruby")
    end
  end

  def java_context(&block)
    Dir.chdir(File.join(name, "java")) do
      block.call(File.join(Dir.pwd, "Contents/Home/bin"))
    end
  end

  def js_context(&block)
    Dir.chdir(File.join(name, "js")) do
      block.call(File.join(Dir.pwd, "bin"))
    end
  end

  def ruby_context(&block)
    Dir.chdir(File.join(name, "ruby")) do
      block.call(File.join(Dir.pwd, "bin"))
    end
  end

  def options_version
    2
  end

  private

  def install_distribution(language)
    download_url = send("#{language}_download_url")
    system("curl", "-OL", download_url) unless File.exist?(File.basename(download_url))

    unless Dir.exist?(language)
      FileUtils.mkdir(language)
      system("tar", "-zxf", File.basename(download_url), "-C", language, "--strip-components=1")
    end
  end

  def java_download_url
    if community_edition
      "https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-#{java_version}/graalvm-community-jdk-#{java_version}_macos-aarch64_bin.tar.gz"
    else
      "https://download.oracle.com/graalvm/#{java_version}/latest/graalvm-jdk-#{java_version}_macos-aarch64_bin.tar.gz"
    end
  end

  def js_download_url
    # rubocop:disable Layout/LineLength
    "https://github.com/oracle/graaljs/releases/download/graal-#{truffle_version}/graalnodejs#{community_edition ? "-community" : ""}-jvm-#{truffle_version}-macos-aarch64.tar.gz"
    # rubocop:enable Layout/LineLength
  end

  def ruby_download_url
    # rubocop:disable Layout/LineLength
    "https://github.com/oracle/truffleruby/releases/download/graal-#{truffle_version}/truffleruby#{community_edition ? "-community" : ""}-jvm-#{truffle_version}-macos-aarch64.tar.gz"
    # rubocop:enable Layout/LineLength
  end
end

GraalVM_CE_23_1_2 = GraalVM.new("21.0.2", "23.1.2", true, "graalvm-ce-java21-23.1.2")
GraalVM_GFTC_23_1_2 = GraalVM.new("21", "23.1.2", false, "graalvm-gftc-java21-23.1.2")

GraalVM_CE_22_3_1 = GraalVMOld.new(
  "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.1/graalvm-ce-java17-darwin-amd64-22.3.1.tar.gz",
  "graalvm-ce-java17-22.3.1",
)

GraalVM_CE_21_2_0 = GraalVMOld.new(
  "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-21.2.0/graalvm-ce-java11-darwin-amd64-21.2.0.tar.gz",
  "graalvm-ce-java11-21.2.0",
)

GRAAL_VMS = [
  GraalVM_CE_23_1_2,
  GraalVM_GFTC_23_1_2,
  GraalVM_CE_22_3_1,
  GraalVM_CE_21_2_0,
]

REFERENCE_GRAALVM = GraalVM_GFTC_23_1_2

def reference_graalvm?(graalvm)
  graalvm == REFERENCE_GRAALVM
end

def run_command(graalvm, args, options = {})
  if VERBOSE
    log(graalvm, "  Command: #{args.join(" ")}")
  end

  IO.popen(args, options)
end

def run_java(graalvm, bin, dump_level, *args)
  FileUtils.rm_rf("./graal_dumps")

  pipe = run_command(graalvm, [
    "#{bin}/java", \
    "-XX:+PrintCompilation",
    "-Dgraal.PrintGraphWithSchedule=true",
    "-Dgraal.Dump=:#{dump_level}",
  ] + args)

  yield pipe

  sleep(3)
  Process.kill("KILL", pipe.pid)
  Process.wait(pipe.pid)
end

def run_js(graalvm, bin, *args)
  FileUtils.rm_rf("graal_dumps")

  pipe = run_command(
    graalvm,
    [
      "#{bin}/node",
      "--experimental-options",
      "--engine.CompileOnly=fib",
      "--engine.TraceCompilation",
      "--engine.MultiTier=false",
      graalvm.options_version == 1 ? "--engine.Inlining=false" : "--compiler.Inlining=false",
      "--vm.Dgraal.Dump=Truffle:1",
    ] + args,
    { err: [:child, :out] },
  )

  yield pipe

  sleep(3)
  Process.kill("KILL", pipe.pid)
  Process.wait(pipe.pid)
end

def run_ruby(graalvm, bin, *args)
  FileUtils.rm_rf("./graal_dumps")

  pipe = run_command(
    graalvm,
    [
      "#{bin}/ruby",
      "--jvm",
      "--experimental-options",
      "--engine.TraceCompilation",
      graalvm.options_version == 1 ? "--engine.NodeSourcePositions" : "--compiler.NodeSourcePositions",
      "--engine.MultiTier=false",
      "--vm.Dgraal.Dump=Truffle:1",
    ] + args,
    { err: [:child, :out] },
  )

  yield pipe

  sleep(3)
  Process.kill("KILL", pipe.pid)
  Process.wait(pipe.pid)
end

def process_examples(graalvm, language, pattern)
  FileUtils.mkdir_p(File.join(EXAMPLES_DIR, graalvm.name, language))
  Dir.glob("graal_dumps/**/*\\[#{Regexp.escape(pattern)}example*.bgv") do |bgv_file|
    # The AST graphs have the same name as the primary graph with a '_1' suffix. Skip them.
    next if bgv_file.end_with?("_1.bgv")

    bgv_file =~ /HotSpotCompilation-\d+\[#{Regexp.escape(pattern)}(.+?)[\(\]]/
    method = Regexp.last_match(1)

    FileUtils.cp(bgv_file, "#{method}.bgv")

    system("gzip", "-f", "#{method}.bgv")
    FileUtils.cp("#{method}.bgv.gz", File.join(EXAMPLES_DIR, graalvm.name, language))

    if reference_graalvm?(graalvm)
      Dir.chdir(EXAMPLES_DIR) do
        FileUtils.ln_sf(
          "../#{graalvm.name}/#{language}/#{method}.bgv.gz",
          "#{language}/#{method}.bgv.gz",
        )
      end
    end
  end
end

def log(graalvm, message, io = $stdout)
  io.puts("#{graalvm.name}: #{message}")
end

Dir.chdir("tools") do
  GRAAL_VMS.each do |graalvm|
    graalvm.install

    ###########################
    ##### Java: Fibonacci #####
    ###########################

    graalvm.java_context do |bin|
      log(graalvm, "Running Fibonacci in Java.")

      FileUtils.cp(File.join(EXAMPLES_DIR, "Fib.java"), ".")
      system("#{bin}/javac", "Fib.java")

      run_java(graalvm, bin, 1, "-XX:CompileOnly=Fib::fib", "Fib", "14") do |pipe|
        loop do
          line = pipe.gets
          break if line =~ /4\s+Fib::fib/
        end
      end

      bgv = Dir.glob("graal_dumps/**/*.bgv")
      raise unless bgv.size == 1

      FileUtils.cp(bgv.first, "fib-java.bgv")
      system("gzip", "-f", "fib-java.bgv")
      FileUtils.cp("fib-java.bgv.gz", File.join(EXAMPLES_DIR, graalvm.name))

      if reference_graalvm?(graalvm)
        FileUtils.ln_sf("#{graalvm.name}/fib-java.bgv.gz", EXAMPLES_DIR)
      end
    end

    ###########################
    ##### Java: Examples  #####
    ###########################

    graalvm.java_context do |bin|
      log(graalvm, "Running Java examples.")

      FileUtils.cp(File.join(EXAMPLES_DIR, "java/JavaExamples.java"), ".")
      system("#{bin}/javac", "JavaExamples.java")

      run_java(
        graalvm,
        bin,
        3,
        "-XX:-UseOnStackReplacement",
        "-XX:CompileCommand=dontinline,*::*",
        "JavaExamples",
      ) do |pipe|
        loop do
          line = pipe.gets if select([pipe], nil, nil, 5)
          break if line.nil? || line =~ /4\s+Fib::fib/
        end
      end

      process_examples(graalvm, "java", "JavaExamples.")
    end

    #################################
    ##### JavaScript: Fibonacci #####
    #################################
    graalvm.js_context do |bin|
      log(graalvm, "Running Fibonacci in JavaScript.")

      run_js(graalvm, bin, File.join(EXAMPLES_DIR, "fib.js"), "14") do |pipe|
        loop do
          line = pipe.gets
          break if line =~ /opt done\s+(?:id=\d+\s+)?fib/
        end
      end

      bgv = Dir.glob('graal_dumps/**/*_fib\\].bgv')
      bgv_ast = Dir.glob('graal_dumps/**/*\\[fib\\].bgv')
      # At some point Graal stopped using separate AST files and instead inserted the AST graphs as phases into
      # the primary graph.
      has_separate_ast_file = bgv_ast.any?

      raise unless bgv.size == 1
      raise if bgv_ast.size > 1

      FileUtils.cp(bgv.first, "fib-js.bgv")
      FileUtils.cp(bgv_ast.first, "fib-js-ast.bgv") if has_separate_ast_file
      system("gzip", "-f", "fib-js.bgv")
      system("gzip", "-f", "fib-js-ast.bgv") if has_separate_ast_file
      FileUtils.cp("fib-js.bgv.gz", File.join(EXAMPLES_DIR, graalvm.name))
      FileUtils.cp("fib-js-ast.bgv.gz", File.join(EXAMPLES_DIR, graalvm.name)) if has_separate_ast_file

      if reference_graalvm?(graalvm)
        FileUtils.ln_sf("#{graalvm.name}/fib-js.bgv.gz", EXAMPLES_DIR)
        FileUtils.ln_sf("#{graalvm.name}/fib-js-ast.bgv.gz", EXAMPLES_DIR) if has_separate_ast_file
      end
    end

    ###########################
    ##### Ruby: Fibonacci #####
    ###########################

    graalvm.ruby_context do |bin|
      log(graalvm, "Running Fibonacci in Ruby.")

      inlining_option = graalvm.options_version == 1 ? "--engine.Inlining=false" : "--compiler.Inlining=false"

      run_ruby(
        graalvm,
        bin,
        "--engine.CompileOnly=fib",
        inlining_option,
        File.join(EXAMPLES_DIR, "fib.rb"),
        "14",
      ) do |pipe|
        loop do
          line = pipe.gets
          break if line =~ /opt done\s+(?:id=\d+\s+)?Object#fib/
        end
      end

      bgv = Dir.glob('graal_dumps/**/*\\[Object#fib\\].bgv')
      bgv_ast = Dir.glob('graal_dumps/**/*\\[Object#fib\\]_1.bgv')

      # At some point Graal stopped using separate AST files and instead inserted the AST graphs as phases into
      # the primary graph.
      has_separate_ast_file = bgv_ast.any?

      raise unless bgv.size == 1
      raise if bgv_ast.size > 1

      FileUtils.cp(bgv.first, "fib-ruby.bgv")
      FileUtils.cp(bgv_ast.first, "fib-ruby-ast.bgv") if has_separate_ast_file
      system("gzip", "-f", "fib-ruby.bgv")
      system("gzip", "-f", "fib-ruby-ast.bgv") if has_separate_ast_file
      FileUtils.cp("fib-ruby.bgv.gz", File.join(EXAMPLES_DIR, graalvm.name))
      FileUtils.cp("fib-ruby-ast.bgv.gz", File.join(EXAMPLES_DIR, graalvm.name)) if has_separate_ast_file

      if reference_graalvm?(graalvm)
        FileUtils.ln_sf("#{graalvm.name}/fib-ruby.bgv.gz", EXAMPLES_DIR)
        FileUtils.ln_sf("#{graalvm.name}/fib-ruby-ast.bgv.gz", EXAMPLES_DIR) if has_separate_ast_file
      end
    end

    ###########################
    ##### Ruby: Examples  #####
    ###########################

    # Older GraalVM instances did not support the `--engine.InlineOnly` option. We had to manually patch Graal to
    # add the inlining support. This script does not manually build GraalVM. Rather, the older graphs were manually
    # created and added to this repo. They can be retrieved via git.
    next if graalvm == GraalVM_CE_21_2_0

    log(graalvm, "Running Ruby examples.")

    graalvm.ruby_context do |bin|
      run_ruby(
        graalvm,
        bin,
        "--engine.OSR=false",
        "--engine.InlineOnly=~Object#opaque_,~Object#static_call,~ExampleObject#instance_call",
        File.join(EXAMPLES_DIR, "ruby/ruby_examples.rb"),
      ) do |pipe|
        loop do
          line = pipe.gets if select([pipe], nil, nil, 5)
          break if line.nil?
        end
      end

      process_examples(graalvm, "ruby", "Object#")
    end
  end
end
