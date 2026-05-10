; Test de Mem_ERROR por acceso no alineado + lectura del ADDR_Error_Reg
; -----------------------------------------------------------------------------
; El inmediato de lw/sw es de 16 bits con signo, asi que la direccion del
; registro interno 0x01000000 no se puede escribir directa. La cargamos desde
; MD[0x108], que viene preinicializada a X"01000000" en
; memoriaRAM_128_32_2026_bucle_lectura.vhd (NO en ram.txt).
;
; Verificacion esperada en GTKWave:
;   (1) lw R7, 0x108(R0)     MISS cacheable -> trae bloque @0x100. R7=0x01000000
;   (2) lw R1, 0x33(R0)      UNALIGNED -> Mem_ERROR=1, load_addr_error=1, ready=1
;                              ADDR_Error_Reg <- ADDR(31:2)&"00" = 0x00000030
;                              (no toca cache, no incrementa cont_*)
;   (3) lw R2, 0(R7)         internal_addr=1 -> mux_output="10" -> R2=Addr_Error=0x30
;                              y Mem_ERROR vuelve a No_error
;   (4) beq R0, R0, -1       loop
; -----------------------------------------------------------------------------

LW R7, 0x108(R0)        ; R7 = 0x01000000 (base ADDR_Error_Reg, preinit en MD)
LW R1, 0x33(R0)         ; Acceso no alineado (addr=0x33) -> Mem_ERROR; ADDR_Error_Reg=0x30
LW R2, 0(R7)            ; Lee ADDR_Error_Reg (R2=0x30) y limpia Mem_ERROR
BEQ R0, R0, -1
