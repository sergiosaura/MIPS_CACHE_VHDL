; RAM IRQ test
lw  r1, 4(r0)      ; r1 = 1
lw  r2, 8(r0)      ; r2 = 8   (lw-uso con la siguiente → 1 stall)
add r3, r1, r2     ; r3 = 9   (r1 fwd WB, r2 fwd MEM tras stall)
add r4, r3, r3     ; r4 = 18  (Rs y Rt fwd dist 1 desde MEM)
add r5, r4, r3     ; r5 = 27  (Rs fwd dist 1 MEM, Rt fwd dist 2 WB)
add r6, r5, r4     ; r6 = 45  (encadenamiento)
sw  r6, 16(r0)
beq r0, r0, -1