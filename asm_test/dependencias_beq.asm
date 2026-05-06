; RAM IRQ
lw  r1, 4(r0)      ; r1 = 1
lw  r2, 4(r0)      ; r2 = 1  
add r3, r1, r2     ; r3 = 2 
sub r3, r3, r1     ; r3 = 1  
beq r3, r1, 2      ; dist 1 con el sub anterior: r3 = 1, aún no escrito
                   ; SIN UA: r3 = 2, r1 = 1 → 2 ≠ 1 → NO salta
                   ; CON UA: r3 = 1, r1 = 1 → 1 = 1 → SÍ salta
sw  r1, 16(r0)     ; matada por kill_IF 
sw  r1, 20(r0)     ; matada por kill_IF
sw  r3, 24(r0)     ; Mem[24] = 1
beq r0, r0, -1