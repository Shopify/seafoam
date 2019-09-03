/*
 * $ javac Fib.java
 * $ java -XX:CompileOnly=::fib -Dgraal.Dump=* Fib 14
 */

class Fib {

  public static void main(String[] args) {
    while (true) {
      for (String arg : args) {
        fib(Integer.parseInt(args[0]));
      }
    }
  }

  public static int fib(int n) {
    if (n <= 1) {
      return n;
    } else {
      return fib(n - 1) + fib(n - 2);
    }
  }

}
