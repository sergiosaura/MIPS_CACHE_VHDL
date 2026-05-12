; =====================================================================
; Loop interchange - VERSION MALA (recorrido col-major, stride 32 bytes)
; ---------------------------------------------------------------------
; Misma matriz 8x8 en MD[0..63] recorrida por columnas. Constantes en
; MD[68..70]: 4 (paso col), 32 (paso fila), 256 (fin columna).
;
; Requiere bloque MD "MATRIX_TEST" activado en memoriaRAM_128_32.vhd.
;
; Esperado:
;   cont_m ~ 65  (1 bloque constantes + 64 misses por thrashing)
;   cont_r ~ 67  (3 hits constantes + 64 hits tras fetch)
; =====================================================================

LW  R4, 272(R0)      ; R4 = MD[68] = 4   (paso col, miss bloque 17)
LW  R5, 276(R0)      ; R5 = MD[69] = 32  (paso fila)
LW  R8, 280(R0)      ; R8 = MD[70] = 256 (fin columna)
ADD R6, R0, R0       ; R6 = 0 (col base)
ADD R10, R0, R0      ; R10 = 0 (acumulador)

ADD R7, R6, R0       ; R7 = puntero interno     (OUTER)
ADD R9, R6, R8       ; R9 = col_base + 256

LW  R3, 0(R7)        ; M[i][j]                  (INNER)
ADD R10, R10, R3
ADD R7, R7, R5       ; addr += 32
BEQ R7, R9, 1
BEQ R0, R0, -5

ADD R6, R6, R4       ; col_base += 4            (FIN_INT)
BEQ R6, R5, 1
BEQ R0, R0, -10

BEQ R0, R0, -1       ; FIN
