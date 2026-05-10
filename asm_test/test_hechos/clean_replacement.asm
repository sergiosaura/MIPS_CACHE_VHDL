LW R1, 0(R0)        ; Miss, conjunto 0, vía 0.
LW R2, 64(R0)       ; Miss, conjunto 0, vía 1.
LW R3, 128(R0)      ; Miss, conjunto 0, reemplazo FIFO de vía 0.
LW R4, 0(R0)        ; Miss de nuevo si el bloque 0 fue expulsado.
BEQ R0, R0, -1
