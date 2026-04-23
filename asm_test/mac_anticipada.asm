lw r1, 0(r0)            ; F D E M W
lw r2, 0(r0)            ;  F D E M W  
lw r5, 4(r0)            ;    F D E M W
mac_ini r3, r1, r5      ;      F D E E M W  
mac r4, r3, r1          ;        F D D E E E M W
beq r4, r5, -2          ;          F F D D D E M W
beq r1, r1, -1          ;
