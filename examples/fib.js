// $ js --vm.Dgraal.TruffleCompileOnly=fib --vm.Dgraal.TruffleFunctionInlining=false --vm.Dgraal.Dump=Truffle:1 fib.rb 14

function fib(n) {
  if (n <= 1) {
    return n;
  } else {
    return fib(n - 1) + fib(n - 2);
  }
}

while (true) {
  for (let n = 2; n < process.argv.length; n++) {
    fib(parseInt(process.argv[n]));
  }
}
