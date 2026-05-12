; =============================================================================
; Test de lecturas (Test_lecturas_P2.pdf)
; -----------------------------------------------------------------------------
; Test de integracion: en un bucle infinito, va trayendo bloques consecutivos
; de MD a MC (un fallo + un acierto por iteracion). Llena las 2 vias de los 4
; conjuntos, fuerza reemplazos FIFO, y cuando el desplazamiento se sale del
; rango de MD se dispara Mem_Error -> Data_abort -> manejador RT_Abort, que
; lee el ADDR_Error_Reg para limpiar el flag.
; -----------------------------------------------------------------------------
; Disposicion del programa (cada manejador esta en su direccion fija; entre
; secciones hay NOPs):
;   @0x000-0x00C : vectores de salto (INI, RTI, RT_Abort, RT_UNDEF)
;   @0x010-0x028 : INI (setup de R1, R4, R6, R8, R16)
;   @0x02C-0x03C : Bucle1 (recorrido de bloques)
;   @0x100-0x108 : RTI (manejador de IRQ)
;   @0x180-0x194 : RT_Abort (manejador de Mem_Error/Data_abort)
;   @0x1C0-0x1C8 : RT_UNDEF (manejador de instruccion no definida)
;
; Constantes preinit en MD (memoriaRAM_128_32_2026_bucle_lectura.vhd):
;   MD[0x000] = 0x00000001       R1 base (=1)
;   MD[0x104] = 0x00000AB0       valor de prueba que RT_Abort vuelca a IO_output
;   MD[0x108] = 0x01000000       base del ADDR_Error_Reg
;   MD[0x10C] = 0x0BAD0C0D       valor de prueba que RT_UNDEF vuelca a IO_output
; =============================================================================

; --- Vectores (@0x000-@0x00C) -----------------------------------------------
beq R1, R1, 3       ; @0x000  salta a INI  (PC+4+4*3 = 0x010)
beq R1, R1, 62      ; @0x004  salta a RTI  (PC+4+4*62 = 0x100)
beq R1, R1, 93      ; @0x008  salta a RT_Abort (PC+4+4*93 = 0x180)
beq R1, R1, 108     ; @0x00C  salta a RT_UNDEF (PC+4+4*108 = 0x1C0)

; --- INI: prepara registros (@0x010-@0x028) ---------------------------------
lw  R1, 0(R0)       ; @0x010  R1 = MD[0] = 0x00000001  (MISS bloque 0, set 0 v0)
add R4, R1, R1      ; @0x014  R4 = 2
add R4, R4, R4      ; @0x018  R4 = 4
add R8, R4, R4      ; @0x01C  R8 = 8
add R16, R8, R8     ; @0x020  R16 = 16  (= tamano de bloque)
add R6, R16, R0     ; @0x024  R6 = 16   (desplazamiento inicial; salta el bloque 0)
lw  R4, 4(R0)       ; @0x028  R4 = MD[1]  (HIT bloque 0, palabra 1)

; --- Bucle1: recorre bloques consecutivos (@0x02C-@0x03C) --------------------
lw  R2, 0(R6)       ; @0x02C  Lee primera palabra del bloque en R6 (MISS)
lw  R2, 4(R6)       ; @0x030  Lee segunda palabra del mismo bloque  (HIT)
add R6, R16, R6     ; @0x034  R6 += 16  -> siguiente bloque
add R5, R1, R5      ; @0x038  R5 += 1   -> indice de iteracion
beq R0, R0, -5      ; @0x03C  vuelve a @0x02C

; (NOPs de relleno hasta @0x100)

; --- RTI: manejador de IRQ (@0x100-@0x108) ----------------------------------
lw  R1, 0(R0)       ; @0x100  Recarga R1=1 (por si la IRQ llego en medio del bucle)
sw  R1, 0x7008(R0)  ; @0x104  INT_ACK <- 1  (1 ciclo)
rte                 ; @0x108  Vuelve a la instruccion interrumpida

; (NOPs de relleno hasta @0x180)

; --- RT_Abort: manejador de Mem_Error (@0x180-@0x194) -----------------------
lw  R2, 0x104(R0)   ; @0x180  R2 = MD[0x104] = 0x00000AB0
sw  R2, 0x7004(R0)  ; @0x184  IO_output <- 0x00000AB0  (parada lw-uso 1 ciclo)
lw  R2, 0x108(R0)   ; @0x188  R2 = MD[0x108] = 0x01000000  (base ADDR_Error_Reg)
lw  R2, 0(R2)       ; @0x18C  R2 = ADDR_Error_Reg  -> tambien limpia Mem_Error
sw  R2, 0x7004(R0)  ; @0x190  IO_output <- direccion que causo el abort
rte                 ; @0x194  Vuelve (con parada de control de retorno)

; (NOPs de relleno hasta @0x1C0)

; --- RT_UNDEF: manejador de instruccion no definida (@0x1C0-@0x1C8) ----------
lw  R2, 0x10C(R0)   ; @0x1C0  R2 = MD[0x10C] = 0x0BAD0C0D
sw  R2, 0x7004(R0)  ; @0x1C4  IO_output <- 0x0BAD0C0D
beq R0, R0, -1      ; @0x1C8  Bucle infinito
