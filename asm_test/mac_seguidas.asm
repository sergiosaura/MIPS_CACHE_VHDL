lw      r1, 0(r0)
lw      r2, 4(r0)
mac_ini r3, r1, r2
mac     r3, r3, r1
mac     r3, r3, r1
sw      r3, 12(r0)
beq     r0, r0, -1