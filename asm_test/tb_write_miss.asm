; ============================================================================
; tb_write_miss.asm
; Caso: WRITE MISS con politica WRITE-AROUND
; ----------------------------------------------------------------------------
; Politica: en write-miss NO se sube el bloque a MC. La MC pide el bus para
; escribir solo la palabra (CwW) en MD. cont_m++ (es miss), cont_w NO se
; incrementa (no es escritura en MC). Posteriormente, una lectura a la misma
; direccion deberia devolver el valor recien escrito en MD.
; ----------------------------------------------------------------------------
; Plan de eventos. Estado MC inicial = vacio. Contadores (m,w,r,cb).
;   pre1) lw R3, 0x4(R0)   MISS s0v0 bloque@0x00   R3=0x0000CACA   (1,0,1,0)
;   pre2) lw R5, 0x8(R0)   HIT  s0v0 word2          R5=0x0000BEBE   (1,0,2,0)
;
;   (1) sw R3, 0x40(R0)    WRITE MISS  write-around          (2,0,2,0)
;       - cacheable, set0, no presente -> cont_m++
;       - NO se sube bloque, NO cont_w++
;       - Bus: una sola transaccion de escritura de palabra a MD
;       - MD[0x40] = 0x0000CACA (overwrite)
;
;   (2) lw R1, 0x40(R0)    READ MISS limpio  -> a set0 via1    (3,0,3,0)
;       - sube bloque@0x40..0x4F a MC, set0 via1 (via0 sigue ocupada)
;       - R1 = 0x0000CACA  (el valor escrito en (1), confirmando que llego a MD)
;
;   (3) sw R5, 0x44(R0)    WRITE HIT s0v1 word1 dirty=1        (3,1,3,0)
;
;   (4) lw R2, 0x40(R0)    HIT s0v1 word0  R2=0x0000CACA        (3,1,4,0)
; ----------------------------------------------------------------------------

; --- Constantes distintivas ---
lw R3, 0x4(R0)        ; pre1: miss s0v0   R3=0x0000CACA
lw R5, 0x8(R0)        ; pre2: hit  s0v0   R5=0x0000BEBE

; --- Caso bajo prueba ---
sw R3, 0x40(R0)       ; (1) WRITE MISS write-around. cont_m++, MD[0x40]=0xCACA
lw R1, 0x40(R0)       ; (2) READ MISS limpio s0v1. R1=0x0000CACA
sw R5, 0x44(R0)       ; (3) WRITE HIT s0v1 word1. cont_w++ dirty=1
lw R2, 0x40(R0)       ; (4) HIT  R2=0x0000CACA

; --- Punto observable: bucle infinito ---
beq R0, R0, -1

; ----------------------------------------------------------------------------
; Verificacion en GTKWave:
;   - tras (1): cont_m=2, cont_w=0, dirty del bloque @0x00 sin tocar
;   - tras (1): observar Bus_Frame activo solo el ciclo de la escritura word
;   - tras (2): cont_m=3, cont_r=3; bloque@0x40 cargado en s0v1 (via_2_rpl=1)
;   - tras (4): cont_r=4 sin mas misses
;   - send_dirty/Block_copied_back: SIEMPRE inactivos (no hay reemplazo)
; Final esperado: m=3, w=1, r=4, cb=0
; ============================================================================
