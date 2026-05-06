lw   r1, 4(r0)
add  r2, r1, r1
lw   r3, 8(r0)
lw   r4, 8(r0)
beq  r3, r4, 2
sw   r0, 16(r0)
sw   r2, 12(r0)
beq  r0, r0, -1