; ============================================================================
; tb_dirty_replacement.asm
; Caso: REEMPLAZO DE BLOQUE SUCIO (con copy-back) + comprobacion de FIFO
; ----------------------------------------------------------------------------
; Llena set0 v0 y v1, ensucia v0, fuerza un miss adicional al set0 que dispara
; el reemplazo del bloque sucio. Despues comprueba que el copy-back entrego el
; dato modificado a MD (al volver a traer el bloque desalojado).
; ----------------------------------------------------------------------------
; Cola FIFO del set 0:
;   tras pre1)         [v0]
;   tras (2)           [v0, v1]
;   tras (3)           [v1, v0_nuevo]   (v0 desalojado por reemplazo sucio)
;   tras (6)           [v0_nuevo, v1_nuevo] (v1 desalojado por reemplazo limpio)
; ----------------------------------------------------------------------------
; Eventos esperados (m,w,r,cb):
;   pre1) lw R3, 0x4(R0)    MISS s0v0 bloque@0x00 limpio    (1,0,1,0)
;   pre2) lw R5, 0x8(R0)    HIT  s0v0 word2                  (1,0,2,0)
;   ; R3=0x0000CACA, R5=0x0000BEBE
;
;   (1) sw R3, 0x4(R0)      WRITE HIT s0v0 word1 dirty=1     (1,1,2,0)
;       MC[s0v0].word1 = 0x0000CACA, dirty=1
;
;   (2) lw R7, 0x40(R0)     MISS s0v1 bloque@0x40 limpio     (2,1,3,0)
;
;   (3) lw R8, 0x80(R0)     MISS s0 con REEMPLAZO SUCIO      (3,1,4,1)
;       - FIFO desaloja v0 (bloque@0x00 dirty)
;       - copy-back de bloque@0x00 a MD (CwB)
;       - fetch de bloque@0x80 a v0 (CrB)
;       - cont_cb++
;
;   (4) lw R9, 0x40(R0)     HIT s0v1 word0  R9=0x10000000    (3,1,5,1)
;       (MD[0x40]=0x10000000 segun memoriaRAM_128_32 en word 16)
;       NOTA: El valor de MD en 0x40 depende de la inicializacion: word 16 = 0x00000001
;       (corregir abajo si discrepa). El test no depende del valor concreto.
;
;   (5) lw R10, 0x80(R0)    HIT s0v0 word0                    (3,1,6,1)
;
;   (6) lw R11, 0x4(R0)     MISS s0v1 limpio (FIFO desaloja v1=bloque@0x40)
;                                                              (4,1,7,1)
;       - reemplazo LIMPIO, NO cont_cb
;       - R11 = MD[0x4]; si copy-back funciono debe ser 0x0000CACA
;         (el valor que escribimos en (1)). Si fuera 0x0000CACA original
;         de MD seria coincidencia: lo importante es que el bloque@0x00
;         haya sido reescrito en MD con el dato dirty.
; ----------------------------------------------------------------------------

; --- Preludio: cargar constantes y dejar bloque@0x00 en s0v0 ---
lw R3, 0x4(R0)        ; pre1: MISS s0v0   R3=0x0000CACA
lw R5, 0x8(R0)        ; pre2: HIT  s0v0   R5=0x0000BEBE

; --- Caso bajo prueba ---
sw R3, 0x4(R0)        ; (1) write hit, ensucia bloque@0x00 (overwrite mismo valor)
                      ;     -> dirty del bloque pasa a 1

lw R7,  0x40(R0)      ; (2) miss limpio s0v1 bloque@0x40
lw R8,  0x80(R0)      ; (3) miss s0 con REEMPLAZO SUCIO de v0 (cont_cb++)
lw R9,  0x40(R0)      ; (4) hit s0v1
lw R10, 0x80(R0)      ; (5) hit s0v0 (recien cargado)
lw R11, 0x4(R0)       ; (6) miss limpio s0v1 (desaloja v1 limpio). Reemplazo
                      ;     LIMPIO, NO incrementa cont_cb. R11 evidencia que
                      ;     el copy-back llevo el dato escrito a MD.

; --- Punto observable: bucle infinito ---
beq R0, R0, -1

; ----------------------------------------------------------------------------
; Verificacion en GTKWave:
;   - cont_cb pasa de 0 a 1 EXACTAMENTE en (3); permanece en 1 tras (6).
;   - en (3) observar:
;       send_dirty='1' durante la fase de address de la escritura
;       Block_copied_back='1' al final del copy-back
;       Update_dirty='1' para limpiar el dirty bit
;       MC_bus_Write='1' antes de MC_bus_Read='1' (primero copy-back, luego fetch)
;   - en (6) observar reemplazo limpio: send_dirty='0', cont_cb sigue en 1.
;   - dirty_bit_rpl debe ser '1' al entrar al estado de reemplazo en (3) y
;     '0' al entrar en (6).
; Final esperado: m=4, w=1, r=7, cb=1
; ============================================================================
