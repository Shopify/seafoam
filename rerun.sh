#!/bin/bash
set -ex
pushd examples
main_class=MatMult
javac "$main_class.java"
method=$(echo $main_class | tr '[:upper:]' '[:lower:]')
output_path=$(java -XX:CompileOnly=::$method '-Dgraal.Dump=*' "$main_class" 50 | grep -o '\/.*')
popd
bgv=$(echo $output_path/*.bgv | cut -f1 -d' ')
# ruby    bin/seafoam ${1:-render} "$bgv":0
if [ ! -z "$DEBUG" ]; then
  ruby_debug_flag=-d
fi
ruby $ruby_debug_flag bin/seafoam ${1:-render} "$bgv":0
