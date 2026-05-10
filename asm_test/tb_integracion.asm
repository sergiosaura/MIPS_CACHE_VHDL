; ============================================================================
; tb_integracion.asm
; Test de INTEGRACION: ejercita en una unica simulacion la mayor parte de los
; eventos posibles de la jerarquia de memoria, en un orden que expone posibles
; efectos cruzados que los unit tests aislados podrian no detectar.
;
; NO incluye los casos de Data_abort (gestionados en tb_abort.asm con su ROM
; precompilada): este .asm es directamente compilable con script.py.
; ----------------------------------------------------------------------------
; Resumen de fases:
;   F0) Cargar constantes utiles desde MD (R3,R5 datos a escribir; R7 base
;       scratch; R12 dir Addr_Error_Reg)
;   F1) Llenar via 0 de los 4 sets con misses limpios
;   F2) Llenar via 1 de los 4 sets con misses limpios
;   F3) Hits de lectura sobre los 8 bloques presentes
;   F4) Escrituras hit que ensucian la via 0 de los 4 sets
;   F5) Escritura miss (write-around) sobre direccion no presente
;   F6) Lecturas que fuerzan reemplazo SUCIO de via 0 (4 cb)
;   F7) Accesos a MD scratch (lw/sw)
;   F8) Accesos a registros IO (Output_Reg, Input_Reg, ACK_Reg)
;   F9) Bucle infinito
; ----------------------------------------------------------------------------
; Cuenta esperada de eventos (solo cacheable cuenta):
;   F1: 4 misses, 4 reads             m=4   r=4
;   F2: 4 misses, 4 reads             m=8   r=8
;   F3: 8 reads (todos hit)                  r=16
;   F4: 4 writes (todos hit)                w=4
;   F5: 1 miss (write-around, NO inc_w)  m=9
;   F6: 4 misses con reemplazo dirty   m=13  r=20  cb=4
;   F7: scratch (no cuenta)
;   F8: IO (no cuenta)
;   F0 cuenta tambien:
;       lw R3 ->  miss s0v0 (cuenta en F1 para no doblar; lo tratamos como
;                 parte de F1: el bloque@0x00 es justamente s0v0)
;
; FINAL ESPERADO:  cont_m=13   cont_w=4   cont_r=20   cont_cb=4
;
; Ojo: el orden importa para los reemplazos. Tras F1+F2, FIFO de cada set:
; [v0, v1]. En F6 cada miss desaloja v0 (sucio por F4) -> 4 copy-backs.
; ============================================================================

; --- F0: constantes ---
lw R3,  0x4(R0)       ; F0/F1.s0v0 word1 -> MISS s0v0 bloque@0x00..0x0F
                      ; R3 = 0x0000CACA (dato distintivo a escribir)
lw R5,  0x8(R0)       ; HIT s0v0 word2 -> R5 = 0x0000BEBE
lw R7,  0x100(R0)     ; F1.s0v1? NO: bloque@0x100 set bits 00 -> set 0 via 1
                      ; R7 = 0x10000000 (base scratch)
lw R12, 0x108(R0)     ; HIT s0v1 (recien cargado) word2 -> R12 = 0x01000000

; --- F1: llenar resto de via 0 (s1, s2, s3) ---
lw R20, 0x10(R0)      ; MISS s1v0 bloque@0x10..0x1F
lw R21, 0x20(R0)      ; MISS s2v0 bloque@0x20..0x2F
lw R22, 0x30(R0)      ; MISS s3v0 bloque@0x30..0x3F

; --- F2: llenar via 1 de s1, s2, s3 ---
lw R20, 0x50(R0)      ; MISS s1v1 bloque@0x50..0x5F
lw R21, 0x60(R0)      ; MISS s2v1 bloque@0x60..0x6F
lw R22, 0x70(R0)      ; MISS s3v1 bloque@0x70..0x7F

; --- F3: hits de lectura sobre todos los bloques presentes ---
lw R1, 0x4(R0)        ; HIT s0v0
lw R1, 0x14(R0)       ; HIT s1v0
lw R1, 0x24(R0)       ; HIT s2v0
lw R1, 0x34(R0)       ; HIT s3v0
lw R1, 0x104(R0)      ; HIT s0v1
lw R1, 0x54(R0)       ; HIT s1v1
lw R1, 0x64(R0)       ; HIT s2v1
lw R1, 0x74(R0)       ; HIT s3v1

; --- F4: escrituras hit que ensucian via 0 de cada set ---
sw R3, 0x0(R0)        ; WRITE HIT s0v0 word0 dirty=1
sw R3, 0x10(R0)       ; WRITE HIT s1v0 word0 dirty=1
sw R3, 0x20(R0)       ; WRITE HIT s2v0 word0 dirty=1
sw R3, 0x30(R0)       ; WRITE HIT s3v0 word0 dirty=1

; --- F5: write miss (write-around) ---
sw R3, 0x80(R0)       ; WRITE MISS s0 (no presente). cont_m++, NO cont_w.
                      ; Bus: 1 escritura word a MD. MD[0x80]=0x0000CACA

; --- F6: lecturas que fuerzan reemplazo SUCIO en cada set ---
lw R1, 0x80(R0)       ; MISS s0 -> reemplazo SUCIO (desaloja s0v0 dirty)
                      ; cont_cb++. Tras esto s0v0 = bloque@0x80
                      ; (NOTA: F5 ya escribio MD[0x80]=0xCACA; el fetch lo trae)
lw R1, 0x90(R0)       ; MISS s1 -> reemplazo SUCIO (desaloja s1v0 dirty)  cb++
lw R1, 0xA0(R0)       ; MISS s2 -> reemplazo SUCIO (desaloja s2v0 dirty)  cb++
lw R1, 0xB0(R0)       ; MISS s3 -> reemplazo SUCIO (desaloja s3v0 dirty)  cb++

; --- F7: scratch ---
sw R3, 0x0(R7)        ; SCRATCH WRITE @0x10000000 (sin contadores MC)
lw R1, 0x0(R7)        ; SCRATCH READ  @0x10000000 -> R1=0x0000CACA

; --- F8: IO ---
sw R3, 0x7004(R0)     ; IO_output <= 0x0000CACA
lw R1, 0x7000(R0)     ; R1 <- IO_input
sw R5, 0x7008(R0)     ; ACK pulse 1 ciclo (R5=0x0000BEBE bit0=0... ACK no se
                      ; activa; util ver precision: bit0=0 -> ACK_Reg='0')

; --- F9: punto observable ---
beq R0, R0, -1        ; bucle infinito

; ============================================================================
; CALCULO DE SPEEDUP (para el informe)
;
; Sea N_acc = cont_m + cont_w + cont_r + (lecturas/escrituras a scratch e IO)
; medido por simulacion. T_con_MC = ciclos totales hasta entrar en bucle (F9).
;
; El sistema "sin MC" no existe fisicamente en el SoC; se calcula como:
;   T_sin_MC = (N_lw_cacheable + N_sw_cacheable) * (CwW(MD) + arb)
; donde CwW(MD) es el coste de un acceso palabra a MD (medido en simulacion).
; Como cada lw/sw no-cacheable ya cuesta lo mismo en ambos sistemas, NO se
; cuentan en el speedup.
;
; Speedup = T_sin_MC / T_con_MC.
; ============================================================================
