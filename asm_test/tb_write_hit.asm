; ============================================================================
; tb_write_hit.asm
; Caso: WRITE HIT (escritura sobre bloque presente en MC)
; ----------------------------------------------------------------------------
; Configuracion MC: 2-way, 4 sets, 4 palabras/bloque (16 B), FIFO, copy-back,
;                   write-around en write miss.
; Direcciones [tag(26) | set(2) | word(2) | byte(2)]
; ----------------------------------------------------------------------------
; Datos preinicializados en MD (memoriaRAM_128_32_..._lectura.vhd):
;   MD[0x00]=0x00000001  MD[0x04]=0x0000CACA  MD[0x08]=0x0000BEBE  MD[0x0C]=0x0000CAFE
; ----------------------------------------------------------------------------
; Plan de eventos. Estado MC inicial = vacio. Contadores (m,w,r,cb).
;   (1) lw R1, 0(R0)    MISS limpio  set0 via0 bloque @0x00..0x0F   (1,0,1,0)
;   (2) lw R2, 4(R0)    HIT          set0 via0 word1                (1,0,2,0)
;   (3) sw R3, 8(R0)    WRITE HIT    set0 via0 word2 dirty=1         (1,1,2,0)
;   (4) lw R4, 8(R0)    HIT          lee el dato recien escrito      (1,1,3,0)
;   (5) sw R5, 0xC(R0)  WRITE HIT    set0 via0 word3 dirty sigue 1   (1,2,3,0)
;   (6) lw R6, 0xC(R0)  HIT          verifica persistencia          (1,2,4,0)
; ----------------------------------------------------------------------------
; Bus: una sola transferencia de bloque (CrB) en (1). Las (3)(5) NO suben datos
; al bus (copy-back). El bloque queda dirty en MC pendiente de futuro reemplazo.
; ============================================================================

; --- Carga de constantes distintivas para escribir (MIPS sin addi) ---
lw R3, 0x4(R0)        ; R3 = 0x0000CACA  (dato para el primer sw)
lw R5, 0x8(R0)        ; R5 = 0x0000BEBE  (dato para el segundo sw)
                      ; OJO: estos lw provocan miss/hit; se hacen ANTES del caso
                      ; bajo prueba para que los contadores partan de un estado
                      ; conocido. En las anotaciones de arriba se asume que el
                      ; "estado inicial" es justo despues de estas dos cargas:
                      ;   tras este preludio: m=1, w=0, r=2, cb=0
                      ;   (set0 via0 bloque@0x00 ya esta en MC, limpio)
                      ;
                      ; Por tanto, reinterpretado desde el reset real:
                      ;   pre1) lw R3,0x4(R0)  MISS limpio s0v0  -> (1,0,1,0)
                      ;   pre2) lw R5,0x8(R0)  HIT s0v0           -> (1,0,2,0)

; --- Caso bajo prueba ---
lw  R1, 0x0(R0)       ; (1') HIT s0v0 word0  R1=0x00000001    (1,0,3,0)
lw  R2, 0x4(R0)       ; (2') HIT s0v0 word1  R2=0x0000CACA    (1,0,4,0)
sw  R3, 0x8(R0)       ; (3') WRITE HIT s0v0 word2 dirty=1     (1,1,4,0)
lw  R4, 0x8(R0)       ; (4') HIT  R4=0x0000CACA               (1,1,5,0)
sw  R5, 0xC(R0)       ; (5') WRITE HIT s0v0 word3 dirty=1     (1,2,5,0)
lw  R6, 0xC(R0)       ; (6') HIT  R6=0x0000BEBE               (1,2,6,0)

; --- Punto observable: bucle infinito ---
beq R0, R0, -1        ; bucle infinito (offset -1 = misma instr)

; ----------------------------------------------------------------------------
; Verificacion en GTKWave (senales clave a observar):
;   - estado de la FSM de MC (Completar_UC_MC_2026)
;   - hit0/hit1, MC_WE0/MC_WE1, dirty bit (en Via_2026_CB)
;   - cont_m, cont_w, cont_r, cont_cb -> al final: 1,2,6,0
;   - Bus_Frame: solo activo durante el primer miss; despues siempre '0'
;   - send_dirty / Block_copied_back: nunca activos en este test
; ============================================================================
