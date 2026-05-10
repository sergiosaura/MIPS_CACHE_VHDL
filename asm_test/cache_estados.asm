; Test estados cache: FETCH, WRITEAROUND, COPYBACK, SCRATCH
;
; RAM de datos (memoriaRAM_128_32_2026_bucle_lectura.vhd):
;   0x000 = 0x00000001  -> set0, tag0
;   0x040 = 0x00000001  -> set0, tag1  (mismo conjunto que 0x000)
;   0x050 = 0x00000001  -> set1, tag1  (para WriteAround)
;   0x080 = 0x00000010  -> set0, tag2  (para CopyBack)
;   0x100 = 0x10000000  -> set0, tag4  (base de la scratch)
;
; Geometria cache: 2 vias, 4 conjuntos, 4 palabras/bloque (16 B)
;   [1:0]=byte  [3:2]=palabra en bloque  [5:4]=conjunto  [31:6]=tag

; --- FETCH 1: fallo frio, carga bloque {0x000..0x00C} en set0/way0 ---
lw r1, 0(r0)        ; r1=0x1.  FIFO[set0]: next=1

; --- FETCH 2: fallo frio, carga bloque {0x040..0x04C} en set0/way1 ---
lw r2, 0x40(r0)     ; r2=0x1.  FIFO[set0]: next=0

; --- Escritura con acierto: pone dirty en set0/way0 (sin acceso a bus) ---
sw r1, 0(r0)        ; HIT set0/way0 -> dirty bit activo

; --- WRITEAROUND: fallo escritura en set1 (vacio) -> escribe directo a RAM ---
sw r2, 0x50(r0)     ; Miss set1/tag1 -> WriteAround

; --- COPYBACK + FETCH: fallo set0, FIFO=0 -> way0 DIRTY -> vuelca + trae nuevo bloque ---
lw r3, 0x80(r0)     ; r3=0x10. CopyBack way0 + Fetch {0x080..0x08C} set0/way0

; --- FETCH: carga el puntero base de la scratch (0x10000000) en r4 ---
lw r4, 0x100(r0)    ; r4=0x10000000. Fetch {0x100..0x10C}

; --- Burbuja: resuelve la dependencia de carga de r4 ---
nop

; --- SCRATCH read: addr_non_cacheable (Addr[31:8] = 0x100000) ---
lw r5, 0(r4)        ; r5 = scratch[0x10000000]

; --- SCRATCH write ---
sw r1, 0(r4)        ; scratch[0x10000000] = r1

; --- Fin: bucle infinito ---
beq r0, r0, -1
