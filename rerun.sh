#!/bin/bash
set -ex
pushd examples
main_class=MatMult
javac "$main_class.java"
method=$(echo $main_class | tr '[:upper:]' '[:lower:]')
output_path=$(java -XX:CompileOnly=::$method '-Dgraal.Dump=*' "$main_class" 50 | grep -o '\/.*')
popd
bgv=$(echo $output_path/*.bgv | cut -f1 -d' ')
bin/seafoam ${1:-render} "$bgv":0
#ruby -d bin/seafoam ${1:-render} "$bgv":0
