LW R1, 4(R0)         ; R1 = MEM[4]
LW R2, 8(R0)         ; R2 = MEM[8]
NOP                   ; Evitar lw-uso de R2
NOP

; Test 1: Forward rs distancia 1 (MUX_A = "01")
ADD R3, R1, R2        ; R3 = R1 + R2
ADD R4, R3, R0        ; UA detecta R3 en MEM → forward a rs
SW R4, 0x7004(R0)     ; Salida: R1+R2
NOP
NOP

; Test 2: Forward rt distancia 1 (MUX_B = "01")
ADD R5, R1, R2        ; R5 = R1 + R2
ADD R6, R0, R5        ; UA detecta R5 en MEM → forward a rt
SW R6, 0x7004(R0)     ; Salida: R1+R2
NOP
NOP

; Test 3: Forward rs distancia 2 (MUX_A = "10")
ADD R3, R1, R2        ; R3 = R1 + R2
NOP                   ; Separador: R3 pasa a WB
ADD R4, R3, R0        ; UA detecta R3 en WB → forward a rs
SW R4, 0x7004(R0)     ; Salida: R1+R2
NOP
NOP

; Test 4: Forward rt distancia 2 (MUX_B = "10")
ADD R5, R1, R2        ; R5 = R1 + R2
NOP                   ; Separador
ADD R6, R0, R5        ; UA detecta R5 en WB → forward a rt
SW R6, 0x7004(R0)     ; Salida: R1+R2
NOP
NOP

; Test 5: Forward rs y rt simultáneo distancia 1 (MUX_A = "01", MUX_B = "01")
ADD R3, R1, R2        ; R3 = R1 + R2
ADD R4, R3, R3        ; UA forward R3 a rs Y rt desde MEM
SW R4, 0x7004(R0)     ; Salida: 2*(R1+R2)
NOP
NOP

; Test 6: Forward mixto dist.1 (rs) + dist.2 (rt)
ADD R3, R1, R0        ; R3 = R1
ADD R5, R2, R0        ; R5 = R2 (R3 pasa a WB)
ADD R6, R3, R5        ; R3 desde WB (dist.2, MUX_A="10"), R5 desde MEM (dist.1, MUX_B="01")
SW R6, 0x7004(R0)     ; Salida: R1+R2
NOP
NOP

; Test 7: Prioridad dist.1 sobre dist.2 (mismo registro destino)
ADD R3, R1, R0        ; R3 = R1 (estará en WB)
ADD R3, R2, R0        ; R3 = R2 (estará en MEM, sobreescribe)
ADD R4, R3, R0        ; Debe usar R3 = R2 (dist.1 gana)
SW R4, 0x7004(R0)     ; Salida: R2
NOP
NOP

; Test 8: Forward ARIT → SW dato (rt) distancia 1
ADD R3, R1, R2        ; R3 = R1 + R2
SW R3, 0x7004(R0)     ; UA forward R3 desde MEM a rt (dato del SW)
NOP
NOP

; Test 9: Forward ARIT → LW base (rs) distancia 1
ADD R3, R0, R0        ; R3 = 0
LW R4, 4(R3)          ; UA forward R3 desde MEM a rs
NOP                   ; Evitar lw-uso
SW R4, 0x7004(R0)     ; Salida: MEM[4]
NOP
NOP

; Test 10: Forward JAL → uso (MUX = "11")
JAL R10, 1            ; R10 = PC+4, salta 2 posiciones adelante
NOP                   ; Se mata (Kill_IF)
ADD R4, R10, R0       ; UA forward PC+4 de JAL desde MEM (MUX="11")
SW R4, 0x7004(R0)     ; Salida: dirección de retorno
NOP
NOP

; Test 11: Forward LW dist.2 tras detención por lw-uso
LW R3, 4(R0)          ; R3 = MEM[4]
ADD R4, R3, R0        ; lw-uso: UD para 1 ciclo, luego forward R3 desde WB
SW R4, 0x7004(R0)     ; Salida: MEM[4]
NOP
NOP
; --- Fin ---
BEQ R0, R0, -1        ; Bucle infinito
