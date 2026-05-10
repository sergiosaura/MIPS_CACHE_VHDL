LW R1, 0(R0) ; Miss de lectura. Se trae el bloque 0 a MC.
LW R2, 4(R0) ; Hit. Misma línea cacheada, palabra 1.
LW R3, 8(R0) ; Hit. Misma línea cacheada, palabra 2.
LW R4, 12(R0) ; Hit. Misma línea cacheada, palabra 3.
BEQ R0, R0, -1