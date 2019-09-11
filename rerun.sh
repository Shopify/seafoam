#!/bin/bash
set -ex
pushd examples
main_class=MatMult
javac "$main_class.java"
output_path=$(java -XX:CompileOnly=::matmult '-Dgraal.Dump=*' "$main_class" 50 | grep -o '\/.*')
popd
bgv=$(echo $output_path/*.bgv | cut -f1 -d' ')
ruby -d bin/seafoam ${1:-render} "$bgv":0
