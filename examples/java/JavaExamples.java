/*
 * % javac JavaExamples.java
 * % java -XX:-UseOnStackReplacement '-XX:CompileCommand=dontinline,*::*' -XX:+PrintCompilation -Dgraal.Dump=:3 JavaExamples
 */

import java.lang.reflect.Field;
import java.util.Random;
import sun.misc.Unsafe;

class JavaExamples {

    private final static Random RANDOM = new Random();
    private final static Unsafe UNSAFE = getUnsafe();
    private final static long UNSAFE_MEMORY = UNSAFE.allocateMemory(1024);

    public static void main(String[] args) {
        if (args.length != 0) {
            throw new UnsupportedOperationException("not expecting any arguments");
        }

        while (true) {
            exampleLocalVariables(RANDOM.nextInt(), RANDOM.nextInt());
            exampleLocalVariablesState(RANDOM.nextInt(), RANDOM.nextInt());
            exampleArithOperator(RANDOM.nextInt(), RANDOM.nextInt());
            exampleCompareOperator(RANDOM.nextInt(), RANDOM.nextInt());
            try {
              exampleExactArith(RANDOM.nextInt(), RANDOM.nextInt());
            } catch (ArithmeticException e) { }
            examplePhi(RANDOM.nextBoolean(), RANDOM.nextInt());
            exampleSimpleCall(new ExampleObject(RANDOM.nextInt()), RANDOM.nextInt());
            exampleInterfaceCall(new ExampleObject(RANDOM.nextInt()), RANDOM.nextInt());
            exampleStaticCall(RANDOM.nextInt());
            exampleStamp(RANDOM.nextInt());
            exampleFullEscape(RANDOM.nextInt());
            exampleNoEscape(RANDOM.nextInt());
            examplePartialEscape(RANDOM.nextBoolean(), RANDOM.nextInt());
            exampleIf(RANDOM.nextBoolean(), RANDOM.nextInt(), RANDOM.nextInt());
            exampleIfNeverTaken(false, RANDOM.nextInt(), RANDOM.nextInt());
            exampleIntSwitch(RANDOM.nextInt(3), RANDOM.nextInt(), RANDOM.nextInt(), RANDOM.nextInt());
            exampleStringSwitch(new String[]{"foo", "bar", "baz"}[RANDOM.nextInt(3)], RANDOM.nextInt(), RANDOM.nextInt(), RANDOM.nextInt());
            exampleWhile(RANDOM.nextInt(10));
            exampleReducible(RANDOM.nextBoolean(), RANDOM.nextInt(10));
            Irreducible.exampleIrreducible(RANDOM.nextBoolean(), RANDOM.nextInt(10));
            exampleNestedWhile(RANDOM.nextInt(10));
            exampleWhileBreak(RANDOM.nextInt(10));
            exampleNestedWhileBreak(RANDOM.nextInt(10));
            try {
              exampleThrow();
            } catch (RuntimeException e) { }
            exampleCatch();
            exampleThrowCatch();
            exampleObjectAllocation(RANDOM.nextInt());
            exampleArrayAllocation(RANDOM.nextInt(), RANDOM.nextInt());
            exampleFieldWrite(new ExampleObject(RANDOM.nextInt()), RANDOM.nextInt());
            exampleFieldRead(new ExampleObject(RANDOM.nextInt()));
            exampleArrayWrite(new int[]{RANDOM.nextInt(), RANDOM.nextInt(), RANDOM.nextInt()}, RANDOM.nextInt(3), RANDOM.nextInt());
            exampleArrayRead(new int[]{RANDOM.nextInt(), RANDOM.nextInt(), RANDOM.nextInt()}, RANDOM.nextInt(3));
            exampleUnsafeRead(UNSAFE_MEMORY + RANDOM.nextInt(4) * 4);
            exampleUnsafeWrite(UNSAFE_MEMORY + RANDOM.nextInt(4) * 4, RANDOM.nextInt());
            exampleInstanceOf(RANDOM.nextBoolean() ? new ExampleObject(RANDOM.nextInt()) : new ExampleNonImplementation());
            exampleLocalInstanceOf();
            exampleSynchronized(new Object(), RANDOM.nextInt());
            exampleDoubleSynchronized(new Object(), RANDOM.nextInt());
            exampleLocalSynchronized(RANDOM.nextInt());
        }
    }

    private static int exampleLocalVariables(int x, int y) {
        int a = x + y;
        return a * 2 + a;
    }

    private static int exampleLocalVariablesState(int x, int y) {
        int a = x + y;
        opaqueCall();
        return a * 2 + a;
    }

    private static int exampleArithOperator(int x, int y) {
        return x + y;
    }

    private static boolean exampleCompareOperator(int x, int y) {
        return x <= y;
    }

    private static int exampleExactArith(int x, int y) throws ArithmeticException {
        return Math.addExact(x, y);
    }

    private static int examplePhi(boolean condition, int x) {
        final int a;
        if (condition) {
            a = opaqueCall();
        } else {
            a = opaqueCall();
        }
        return a + x;
    }

    private static int exampleSimpleCall(ExampleObject object, int x) {
        return object.instanceCall(x);
    }

    private static int exampleInterfaceCall(ExampleInterface object, int x) {
        return object.instanceCall(x);
    }

    private static int exampleStaticCall(int x) {
        return staticCall(x);
    }

    private static int exampleStamp(int x) {
        return x & 0x1234;
    }

    private static int exampleFullEscape(int x) {
        final int[] a = new int[]{x};
        objectField = a;
        return a[0];
    }

    private static int exampleNoEscape(int x) {
        final int[] a = new int[]{x};
        return a[0];
    }

    private static int examplePartialEscape(boolean condition, int x) {
        final int[] a = new int[]{x};
        if (condition) {
            objectField = a;
            return a[0];
        } else {
            return a[0];
        }
    }

    private static int exampleIf(boolean condition, int x, int y) {
        final int a;
        if (condition) {
            intField = x;
            a = x;
        } else {
            intField = y;
            a = y;
        }
        return a;
    }

    private static int exampleIfNeverTaken(boolean condition, int x, int y) {
        final int a;
        if (condition) {
            intField = x;
            a = x;
        } else {
            intField = y;
            a = y;
        }
        return a;
    }

    private static int exampleIntSwitch(int value, int x, int y, int z) {
        final int a;
        switch (value) {
            case 0:
                intField = x;
                a = x;
                break;
            case 1:
                intField = y;
                a = y;
                break;
            default:
                intField = z;
                a = z;
                break;
        }
        return a;
    }

    private static int exampleStringSwitch(String value, int x, int y, int z) {
        final int a;
        switch (value) {
            case "foo":
                intField = x;
                a = x;
                break;
            case "bar":
                intField = y;
                a = y;
                break;
            default:
                intField = z;
                a = z;
                break;
        }
        return a;
    }

    private static int exampleWhile(int count) {
        int a = count;
        while (a > 0) {
            intField = a;
            a--;
        }
        return count;
    }

    private static int exampleReducible(boolean condition, int count) {
        int a = count;
        if (condition) {
            a = count - 1;
        }
        while (a > 0) {
            intField = a;
          inner:
            a--;
        }
        return count;
    }

    private static int exampleFor(int count) {
        for (int a = count; a > 0; a--) {
            intField = a;
        }
        return count;
    }

    private static int exampleNestedWhile(int count) {
        int a = count;
        while (a > 0) {
            int y = count;
            while (y > 0) {
                intField = a;
                y--;
            }
            a--;
        }
        return count;
    }

    private static int exampleWhileBreak(int count) {
        int a = count;
        while (a > 0) {
            if (a == 4) {
                break;
            }
            intField = a;
            a--;
        }
        return count;
    }

    private static int exampleNestedWhileBreak(int count) {
        int a = count;
        outer: while (a > 0) {
            int b = count;
            while (b > 0) {
                if (b == 4) {
                    break outer;
                }
                intField = a;
                b--;
            }
            a--;
        }
        return count;
    }

    private static void exampleThrow() {
        throw RUNTIME_EXCEPTION;
    }

    private static void exampleCatch() {
      try {
          exampleThrow();
      } catch (RuntimeException e) {
          objectField = e;
      }
    }

    private static void exampleThrowCatch() {
      try {
          throw RUNTIME_EXCEPTION;
      } catch (RuntimeException e) {
      }
    }

    private static ExampleObject exampleObjectAllocation(int x) {
        return new ExampleObject(x);
    }

    private static int[] exampleArrayAllocation(int x, int y) {
        return new int[]{x, y};
    }

    private static void exampleFieldWrite(ExampleObject object, int x) {
        object.x = x;
    }

    private static int exampleFieldRead(ExampleObject object) {
        assert object != null; // otherwise this is a 'trivial' method and won't go past tier 1
        return object.x;
    }

    private static void exampleArrayWrite(int[] array, int n, int x) {
        array[n] = x;
    }

    private static int exampleArrayRead(int[] array, int n) {
        return array[n];
    }

    private static int exampleUnsafeRead(long unsafeMemory) {
        return UNSAFE.getInt(unsafeMemory);
    }

    private static void exampleUnsafeWrite(long unsafeMemory, int x) {
        UNSAFE.putInt(unsafeMemory, x);
    }

    private static boolean exampleInstanceOf(Object object) {
        return object instanceof ExampleInterface;
    }

    private static boolean exampleLocalInstanceOf() {
        return new ExampleObject(1) instanceof ExampleInterface;
    }

    private static void exampleSynchronized(Object object, int x) {
        synchronized (object) {
            intField = x;
        }
    }

    private static void exampleDoubleSynchronized(Object object, int x) {
        synchronized (object) {
            intField = x;
        }
        synchronized (object) {
            intField = x;
        }
    }

    private static void exampleLocalSynchronized(int x) {
        final Object object = new Object();
        synchronized (object) {
            intField = x;
        }
    }

    private static int opaqueCall() {
        return RANDOM.nextInt();
    }

    private static int staticCall(int x) {
        return x;
    }

    private static final RuntimeException RUNTIME_EXCEPTION = new RuntimeException();
    private static volatile int intField;
    private static volatile Object objectField;

    private interface ExampleInterface {
        int instanceCall(int y);
    }

    private static class ExampleObject implements ExampleInterface {
        public int x;

        public ExampleObject(int x) {
            this.x = x;
        }

        public int instanceCall(int y) {
            return x + y;
        }
    }

    private static class ExampleNonImplementation {
    }

    private static Unsafe getUnsafe() {
        try {
            final Field theUnsafe = Unsafe.class.getDeclaredField("theUnsafe");
            theUnsafe.setAccessible(true);
            return (Unsafe) theUnsafe.get(null);
        } catch (NoSuchFieldException | IllegalAccessException e) {
            throw new RuntimeException(e);
        }
    }

}
