lw r1, 4(r0)         
lw r2, 4(r0)
lw r3, 8(r0)                   
jal r5, 4                      
nop 
beq r0, r0, -1
nop                  
add r1, r1, r2             
beq r1, r2, -2
nop                                    
ret r5                         