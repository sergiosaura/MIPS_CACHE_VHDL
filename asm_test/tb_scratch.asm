; ============================================================================
; tb_scratch.asm
; Caso: ACCESOS A MD SCRATCH (no cacheable, palabra a palabra)
; ----------------------------------------------------------------------------
; Rango: 0x10000000-0x100000FF. La MC reenvia el lw/sw directamente al bus
; (single-word, sin burst, sin fetch a MC). NO incrementa cont_m, cont_w,
; cont_r ni cont_cb. Verifica ademas que los bloques cacheables presentes
; en MC NO se ven afectados por accesos al scratch.
; ----------------------------------------------------------------------------
; Cargar la base 0x10000000 en un registro: el inmediato de lw/sw es de 16
; bits con signo, asi que no podemos escribir 0x10000000 directo. Usamos
; el dato preinicializado en MD[0x100] = 0x10000000 (memoriaRAM_128_32).
; ----------------------------------------------------------------------------
; Eventos esperados (m,w,r,cb):
;   pre1) lw R3, 0x4(R0)     MISS s0v0 bloque@0x00     R3=0x0000CACA   (1,0,1,0)
;   pre2) lw R7, 0x100(R0)   MISS s0v1 bloque@0x100    R7=0x10000000   (2,0,2,0)
;
;   (1) sw R3, 0x0(R7)       SCRATCH WRITE @0x10000000                 (2,0,2,0)
;   (2) lw R1, 0x0(R7)       SCRATCH READ  @0x10000000   R1=0x0000CACA (2,0,2,0)
;   (3) sw R3, 0xFC(R7)      SCRATCH WRITE @0x100000FC                 (2,0,2,0)
;   (4) lw R2, 0xFC(R7)      SCRATCH READ  @0x100000FC   R2=0x0000CACA (2,0,2,0)
;
;   (5) lw R6, 0x4(R0)       HIT  s0v0 (cacheable intacto)             (2,0,3,0)
;   (6) lw R8, 0x100(R0)     HIT  s0v1 (cacheable intacto)             (2,0,4,0)
; ----------------------------------------------------------------------------

; --- Preludio: cargar bloque@0x00 (constante) y bloque@0x100 (base scratch) ---
lw R3, 0x4(R0)        ; pre1: MISS s0v0  R3=0x0000CACA
lw R7, 0x100(R0)      ; pre2: MISS s0v1  R7=0x10000000  (base scratch)

; --- Caso bajo prueba: scratch ---
sw R3, 0x0(R7)        ; (1) SCRATCH WRITE  primer word
lw R1, 0x0(R7)        ; (2) SCRATCH READ   R1=0x0000CACA
sw R3, 0xFC(R7)       ; (3) SCRATCH WRITE  ultimo word
lw R2, 0xFC(R7)       ; (4) SCRATCH READ   R2=0x0000CACA

; --- Verificacion: cacheable sigue en MC ---
lw R6, 0x4(R0)        ; (5) HIT s0v0
lw R8, 0x100(R0)      ; (6) HIT s0v1

; --- Punto observable ---
beq R0, R0, -1

; ----------------------------------------------------------------------------
; Verificacion en GTKWave:
;   - durante (1)..(4) cont_m, cont_w, cont_r, cont_cb NO cambian
;   - addr_non_cacheable='1' en cada acceso a scratch
;   - Bus_Frame se activa solo durante el ciclo de transferencia (single word)
;     - el primer scratch usa CrW/CwW(MDscratch) (medible aqui)
;   - MD_scratch_Bus_DEVsel='1' en la fase de address de scratch
;   - MD_Bus_DEVsel='0' durante scratch (la MD principal NO responde)
;   - tras (5)(6): hit0/hit1 activos -> cont_r=3 y cont_r=4 respectivamente
; Final esperado: m=2, w=0, r=4, cb=0
; ----------------------------------------------------------------------------
; Como BONUS, observar IO_M_count: con tantos accesos a scratch (single-word)
; el bus queda libre con frecuencia y el IO_Master conseguira mas grants.
; ============================================================================
