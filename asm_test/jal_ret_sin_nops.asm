lw  r1, 4(r0)
lw  r2, 4(r0)
jal r5, 2
sw  r1, 12(r0)
beq r0, r0, -1
add r1, r1, r2
ret r5