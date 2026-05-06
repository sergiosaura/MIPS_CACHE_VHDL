; RAM IRQ
lw   r1,  4(r0)     ; r1  = 1
jal  r5, 5          ; R5 = PC+4
sw   r1,  16(r0)    ; no se va a ejecutar
sw   r1,  12(r0)    ; no se va a ejecutar
add  r2,  r1, r1    ; donde se retornará
sw   r2,  20(r0)
beq  r0,  r0, -1
; rutina:
lw   r3,  8(r0)     ; r3 = 8 
add  r5,  r5, r3    ; R5 = R5 + 8 → apunta a add r2, r1, r1
ret  r5             ; RAW dist 1: para 2 ciclos