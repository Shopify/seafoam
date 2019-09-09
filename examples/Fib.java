/*
 * $ javac Fib.java
 * $ java -XX:CompileOnly=::fib -Dgraal.Dump=* Fib 14
 */

/*

 you will have to rename this file before you can run it and get a graph.

 pushd examples; javac Fib.java;and java '-XX:CompileOnly=::fib' '-Dgraal.Dump=*' Fib 7 20; popd
 bin/seafoam render examples/graal_dumps/2019.09.05.13.15.57.431/HotSpotCompilation-2\[Fib.fib\(int\)int\].bgv:0

  Some interseting things:
  - if you run with java Fib 7, graal will notice that one side of the ternary isn't reachable and generate an uncommon trap
  - running with java Fib 7 20 gives a larger graph that has handling for both side of the ternary
*/
class Fib {

  public static void main(String[] args) {
    for (String arg : args) {
      System.out.println(arg);
    }

    for (int i = 0; i < 10000; i++) {
      System.out.format("%d\r", i);
      for (String arg : args) {
        fib(Integer.parseInt(arg));
      }
    }

    // for (int i = 0; i < 100000; i++) {
    //   fib(20);
    // }
  }

  public static void noop(int x, int y) {
  }

  public static int fib(int n) {
    int result = 1;
    int bosh = 4;
    if (n <= 1) {
      result = n;
    } else {
      fib(n - 1);
      int hoho = fib(n - 1) + fib(n - 2) + (n > 15 ? n : 39) + 234;
      noop(hoho, 34);
      noop(9, 34);
      noop(2, 1);
      bosh = 100;
      // bosh = hoho;
    }

    if (n < 5) bosh = 1000;

    switch(n) {
      case 4:
        result = 120;
        break;
      case 5:
        result = 200 * n;
        break;
      case 3:
        result = 99;
        bosh = 39;
        break;
      case 6:
        result = 100;
        break;
      default:
        bosh = 999;
    }

    if (n <= 3) {
      return result / 300;
    }

    return result + fib(n-1) + bosh;
  }

}
