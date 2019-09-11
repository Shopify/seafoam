/*
 * $ javac MatMult.java
 * $ java -XX:CompileOnly=::matmult -Dgraal.Dump=* MatMult 50
 */

class MatMult {

  public static void main(String[] args) {
    for (int i = 0; i < 1000; i++) {
      for (String arg : args) {
        final int size = Integer.parseInt(args[0]);
        final double[][] a = new double[size][];
        final double[][] b = new double[size][];
        final double[][] c = new double[size][];
        for (int n = 0; n < size; n++) {
          a[n] = new double[size];
          b[n] = new double[size];
          c[n] = new double[size];
          for (int m = 0; m < size; m++) {
            a[n][m] = Math.random();
            b[n][m] = Math.random();
          }
        }
        matmult(size, a, b, c);
      }
    }
  }

  static void a(){}
  static void b(){}
  static void c(){}

  public static void matmult(int size, double[][] a, double[][] b, double[][] c) {
    for(int i = 0; i < size; i++) {
      c[0][0] = i;
    }
    a();
    int i = 0;
    while (i < size) {
      c[0][0] = i;
      i++;
    }
    b();
    i = 0;
    while (i < size) {
      i++;
      c[0][0] = i;
    }
    c();
    i = 0;
    while (i < size) {
      i++;
      c[0][0] = i;
      i++;
    }
  }
}
