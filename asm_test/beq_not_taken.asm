lw  r1, 4(r0)
lw  r2, 8(r0)
beq r1, r2, 2
lw  r3, 12(r0)
sw  r3, 16(r0)
beq r0, r0, -1