LW R7, 0x100(R0)        ; R7 = 0x01000000 (preinit en ram.txt word 64)
  LW R1, 3(R0)            ; Acceso no alineado -> Mem_ERROR
  LW R2, 0(R7)            ; Lee ADDR_Error_Reg y limpia Mem_ERROR
  BEQ R0, R0, -1
