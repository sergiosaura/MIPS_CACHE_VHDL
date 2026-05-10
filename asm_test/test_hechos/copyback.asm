LW R1, 0(R0) ; Miss. Carga bloque A en conjunto 0.
SW R1, 0(R0) ; Write hit. Marca dirty el bloque A.
LW R2, 64(R0) ; Miss. Carga bloque B en la otra vía.
LW R3, 128(R0) ; Miss. Reemplaza A, que está dirty -> copy-back.
BEQ R0, R0, -1
