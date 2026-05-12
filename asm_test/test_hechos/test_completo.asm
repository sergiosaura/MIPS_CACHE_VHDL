; ========================================================================
; Test combinado: hit/miss, copy-back, write-around, scratch, error reg
; ------------------------------------------------------------------------
; Direcciones de 32 bits precargadas desde MD (no caben en offset 16-bit):
;   MD[0x100] = 0x10000000 (base scratch)    -> R10
;   MD[0x108] = 0x01000000 (base ADDR_Error) -> R11
; (ambas vienen preinit en memoriaRAM_128_32_2026_bucle_lectura.vhd)
; ========================================================================

; --- Inicialización y primer bloque ---
LW R1, 0(R0)         ; Miss fetch bloque A (set 0, vía 0)
LW R2, 4(R0)         ; Hit bloque A
LW R3, 8(R0)         ; Hit bloque A
SW R3, 0(R0)         ; Write hit, bloque A dirty

; --- Mismo conjunto: reemplazo y copy-back ---
LW R4, 64(R0)        ; Miss bloque B (set 0, vía 1)
LW R5, 128(R0)       ; Miss bloque C, reemplaza A dirty -> copy-back

; --- Write-around ---
SW R5, 192(R0)       ; Write miss, no carga bloque (write-around)
LW R6, 192(R0)       ; Miss; trae bloque 12 (write-around no asignó)

; --- Scratch no cacheable ---
; OJO: usamos offset 4 (palabra 1) porque scratch[0] lo corrompe el IO_Master
; (bug del bus: IO_M_send_Data no tiene rama en el mux Bus_Data_Addr -> ZZZ).
LW R10, 0x100(R0)    ; Preload R10 = 0x10000000 (base scratch)
SW R6, 4(R10)        ; Escritura Scratch @0x10000004 (palabra 1)
LW R7, 4(R10)        ; Lectura  Scratch @0x10000004

; --- Registro interno / error de desalineamiento ---
LW R11, 0x108(R0)    ; Preload R11 = 0x01000000 (base ADDR_Error_Reg)
LW R8, 0x33(R0)      ; Acceso no alineado -> Mem_ERROR; ADDR_Error_Reg = 0x30
LW R9, 0(R11)        ; Lee ADDR_Error_Reg (R9 = 0x30) y limpia Mem_ERROR

BEQ R0, R0, -1
