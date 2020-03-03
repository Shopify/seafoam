; https://github.com/Storyyeller/Krakatau
; Krakatau/assemble.py Irreducible.j

.class public Irreducible
  .super java/lang/Object
  .field private static volatile intField I

  .method public static exampleIrreducible : (ZI)I
    .code stack 1 locals 3

      iload_1
      istore_2
      iload_0
      ifeq L_start_of_loop

      goto L_inside_loop

    L_start_of_loop:
      iload_2
      ifle L_end_of_loop
      iload_2
      putstatic Field Irreducible intField I

    L_inside_loop:
      iinc 2 -1
      goto L_start_of_loop

    L_end_of_loop:
      iload_1
      ireturn

    .end code
  .end method

.end class
