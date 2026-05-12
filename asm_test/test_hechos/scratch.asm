; Test de MD Scratch (zona no cacheable @ 0x10000000)
; -----------------------------------------------------------------------------
; El inmediato de lw/sw es de 16 bits con signo, asi que 0x10000000 no se
; puede escribir directo. Cargamos la base de scratch desde MD[0x100], que
; esta preinicializado a X"10000000" en ram.txt (word 64).
;
; Ademas cargamos un valor cualquiera de MD (mem[4]) para tener algo no nulo
; en R1 y poder comprobar el round-trip a traves de scratch.
;
; NOTA: Usamos offset 0x4 (scratch palabra 1) en lugar de 0x0 porque el bus
; del IO_MD_subsystem tiene un bug: cuando el IO_Master entra en su fase de
; datos (IO_M_send_Data='1') el mux de Bus_Data_Addr no tiene rama para esa
; senal y el bus queda en ZZZ. El IO_Master escribe IO_input continuamente
; en scratch[0] (0x10000000), por lo que esa palabra acaba con ZZZ. Las demas
; (scratch[1..63]) no las toca y son seguras.
;
; Verificacion esperada en GTKWave:
;   - Durante el SW/LW a scratch:
;       addr_non_cacheable = '1'
;       state: Inicio -> Arbitro -> ADDR -> Scratch -> Inicio
;       MD_scratch_Bus_DEVsel = '1', MD_Bus_DEVsel = '0'
;       NO se incrementan cont_m, cont_w, cont_r, cont_cb
;       NO se activan MC_WE0/MC_WE1/MC_tags_WE
;   - Al final: R2 == R1 (round-trip a traves de scratch OK)
; -----------------------------------------------------------------------------

LW R1, 0x4(R0)         ; R1 = mem[4] = 0x1021003E (valor cualquiera para escribir)
LW R7, 0x100(R0)       ; R7 = 0x10000000 (base de scratch, preinit en ram.txt)
SW R1, 0x4(R7)         ; Scratch write @0x10000004 (palabra 1, no tocada por IO_Master)
LW R2, 0x4(R7)         ; Scratch read  @0x10000004  -> R2 == R1
BEQ R0, R0, -1
