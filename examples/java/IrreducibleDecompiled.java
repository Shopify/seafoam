//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by Fernflower decompiler)
//

public class IrreducibleDecompiled {
    private static volatile int intField;

    public static int exampleIrreducible(boolean var0, int var1) {
        int var2 = var1;
        if (var0) {
            var2 = var1 - 1;
        }

        while(var2 > 0) {
            intField = var2--;
        }

        return var1;
    }
}
