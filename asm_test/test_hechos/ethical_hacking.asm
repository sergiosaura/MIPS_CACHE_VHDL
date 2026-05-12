; ============================================================================
; Ethical hacking: ataque por inundacion de bloques sucios (cache flooding)
; ============================================================================
; Objetivo: degradar el rendimiento del MC saturando un conjunto con bloques
; sucios y forzando un copy-back + fetch en CADA miss tras el calentamiento.
;
; Organizacion del MC:
;   - 2 vias, 4 conjuntos, 4 palabras/bloque -> 8 bloques (128 B)
;   - FIFO replacement, copy-back, write-around en miss de escritura
;
; Como elegir direcciones:
;   bits [3:2] = palabra dentro del bloque
;   bits [5:4] = conjunto (set index)
;   bits [31:6] = tag
;   Para impactar el conjunto 0 hace falta bits[5:4]="00", es decir
;   direcciones multiplo de 0x40 (64 B = 4 bloques): 0x00, 0x40, 0x80, 0xC0,
;   0x100, 0x140, 0x180, 0x1C0 (la MD tiene 8 bloques que mapean al set 0).
;
; Patron de ataque (pathological):
;   3 bloques distintos en el mismo conjunto. Al ser 2-way + FIFO, traer el
;   tercero desaloja al primero. Como cada bloque ya esta dirty, el desalojo
;   provoca copy-back. Ciclando indefinidamente, CADA LW es miss + CB + fetch.
;
; Para ensuciar cada bloque:
;   write-around no asigna en miss de escritura, asi que tras cada LW (que SI
;   asigna) hacemos un SW al MISMO bloque -> write-hit -> bit dirty a 1.
;
; Rendimiento esperado vs un programa "limpio":
;   Cada iteracion del bucle ATTACK = 3 LW + 3 SW = 6 instrucciones de memoria.
;   Cada LW: miss con CrB(MD) + CwW(MD)*4 ~ L+3R+4*CwW(MD) ciclos de bus.
;   Cada SW: hit en MC = 1 ciclo.
;   cont_m += 3 por iteracion, cont_cb += 3 por iteracion, cont_w += 3, cont_r += 3.
;
; Detectabilidad (para el informe):
;   - Ratio cont_cb / cont_m muy alto (idealmente 1.0 tras warmup).
;   - cont_m crece linealmente con el tiempo (cada N ciclos un miss).
;   - IO_M_count crece muy lento porque MC monopoliza el bus con copy-backs.
;
; Contramedidas:
;   - Reemplazo random/LRU en lugar de FIFO (rompe el patron predictivo).
;   - Monitorizar cont_cb/cont_m y disparar alarma si supera umbral.
;   - Lockup-free / write buffer: amortiguaria los CB pero no el problema.
;   - Rate-limiting: limitar misses por ventana de tiempo.
; ============================================================================
;
; ENCODED RAM (copiar dentro de signal RAM := ( ... ) en
; memoriaRAM_I_test.bucle_lectura.P2.vhd, manteniendo padding hasta word 127):
;
;     X"10210003", X"1021003E", X"1021005D", X"1021006C", X"08010004", X"0C010000", X"08020040", X"0C010040", --word 0,1,...
;     X"08020080", X"0C010080", X"08020000", X"0C010000", X"08020040", X"0C010040", X"1000FFF9", X"00000000", --word 8,9,...
;     [resto a X"00000000" hasta word 127]
; ============================================================================

; --- Vectores de excepcion (estandar de los tests del proyecto) ---
@0x0  beq R1, R1, INI       ; word 0  (0x10210003)
@0x4  beq R1, R1, RTI       ; word 1  (0x1021003E) -> @0x100
@0x8  beq R1, R1, RT_Abort  ; word 2  (0x1021005D) -> @0x180
@0xC  beq R1, R1, RT_UNDEF  ; word 3  (0x1021006C) -> @0x1C0

; --- INI: calentamiento - traer y ensuciar 2 bloques en conjunto 0 ---
INI:
@0x10 lw R1, 0x4(R0)        ; word 4  R1 = MD[1] = 0xDADA. Como efecto colateral
                            ;         trae el bloque 0 (set 0, via 0). MISS#1.
@0x14 sw R1, 0x0(R0)        ; word 5  Write-hit, bloque 0 (set 0 via 0) -> dirty.
@0x18 lw R2, 0x40(R0)       ; word 6  MISS#2 -> trae bloque 4 (set 0, via 1).
@0x1C sw R1, 0x40(R0)       ; word 7  Write-hit, bloque 4 dirty.
                            ;         Estado: set 0 = [bloque0(d), bloque4(d)]
                            ;                 FIFO: bloque 0 es el mas viejo.

; --- ATTACK: bucle que provoca CB + fetch en cada LW ---
ATTACK:
@0x20 lw R2, 0x80(R0)       ; word 8  MISS, FIFO desaloja bloque 0 (dirty -> CB),
                            ;         trae bloque 8. set 0 = [bloque8, bloque4].
@0x24 sw R1, 0x80(R0)       ; word 9  Write-hit, bloque 8 dirty.
@0x28 lw R2, 0x0(R0)        ; word 10 MISS, FIFO desaloja bloque 4 (dirty -> CB),
                            ;         trae bloque 0. set 0 = [bloque8, bloque0].
@0x2C sw R1, 0x0(R0)        ; word 11 Write-hit, bloque 0 dirty.
@0x30 lw R2, 0x40(R0)       ; word 12 MISS, FIFO desaloja bloque 8 (dirty -> CB),
                            ;         trae bloque 4. set 0 = [bloque4, bloque0].
@0x34 sw R1, 0x40(R0)       ; word 13 Write-hit, bloque 4 dirty.
@0x38 beq R0, R0, ATTACK    ; word 14 (0x1000FFF9) salto a word 8 (offset -7).
                            ;         Bucle infinito: 3 misses + 3 CB por vuelta.
