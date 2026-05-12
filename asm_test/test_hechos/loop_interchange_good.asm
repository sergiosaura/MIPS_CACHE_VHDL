; =====================================================================
; Loop interchange - VERSION BUENA (recorrido row-major, stride 1)
; ---------------------------------------------------------------------
; Suma 64 elementos en MD[0..63] recorriendolos linealmente. Carga las
; constantes desde MD[68] (=4, stride byte) y MD[70] (=256, fin).
;
; Requiere bloque MD "MATRIX_TEST" activado en memoriaRAM_128_32.vhd.
;
; Esperado:
;   cont_m = 17  (1 bloque constantes + 16 bloques de matriz)
;   cont_r = 66  (64 hits matriz + 2 hits constantes)
; =====================================================================

LW  R4, 272(R0)      ; R4 = MD[68] = 4   (paso byte, miss bloque 17)
LW  R8, 280(R0)      ; R8 = MD[70] = 256 (fin, hit bloque 17)
ADD R6, R0, R0       ; R6 = 0 (puntero)
ADD R10, R0, R0      ; R10 = 0 (acumulador)

LW  R3, 0(R6)        ; M[i]   (BUCLE)
ADD R10, R10, R3
ADD R6, R6, R4
BEQ R6, R8, 1
BEQ R0, R0, -5

BEQ R0, R0, -1       ; FIN
