lw      r31, 0(r0)
lw      r1, 32(r0)
lw      r2, 36(r0)
lw      r3, 40(r0)
lw      r4, 44(r0)
lw      r5, 48(r0)
lw      r6, 52(r0)
lw      r7, 56(r0)
lw      r8, 60(r0)
mac_ini r10, r1, r5
mac     r10, r2, r6
mac     r10, r3, r7
mac     r10, r4, r8
lw      r9, 64(r0)
add     r10, r9, r10
lw      r11, 16(r0)
and     r11, r10, r11
beq     r11, r0, 1
and     r10, r10, r0
lw      r12, 68(r0)
beq     r10, r12, 3
lw      r1, 24(r0)
sw      r1, 7004(r0)
beq     r0, r0, -1
sw      r10, 72(r0)
sw      r10, 7004(r0)
beq     r0, r0, -1