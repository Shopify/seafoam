/*
 * % javac MatMult.java
 * % java -XX:CompileOnly=::matmult -Dgraal.Dump=:2 MatMult 100
 */

class MatMult {

  public static void main(String[] args) {
    while (true) {
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

  public static void matmult(int size, double[][] a, double[][] b, double[][] c) {
    for(int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        for (int k = 0; k < size; k++) {
          c[i][j] += a[i][k] * b[k][j];
        }
      }
    }
  }

}
