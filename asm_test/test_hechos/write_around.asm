LW R1, 0(R0);
SW R1, 192(R0) ; Write miss. Debe ir por WriteAround_DATA.
LW R2, 192(R0) ; Miss de lectura si el SW anterior no cargó el bloque.
BEQ R0, R0, -1
