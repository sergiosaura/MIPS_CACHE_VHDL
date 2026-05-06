;Programa Principal
LW  R31, 0(R0)          ; 081F0000 - R31 = MEM[0] (puntero de pila para guardar contexto en ISR)
LW  R1, 4(R0)           ; 08010004 - R1 = MEM[4]
LW  R2, 12(R0)
SW  R1, 0x7004(R6)      ; 0CC17004 - Escribe R1 en el puerto de salida (R6=0)
MAC_ini R1, R1, R2
MAC R1, R1, R2
SW  R1, 0x7004(R6)      ; 0CC17004 - Escribe R1 en el puerto de salida
BEQ R1, R1, -3          ; 1021FFFD - Bucle: vuelve al MAC_ini (bucle infinito)

;Padding
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

; Rutina de Servicio de IRQ 
; -- Guardar contexto (push) --
SW  R1, 0(R31)          ; 0FE10000 - Guarda R1 en MEM[R31]
SW  R2, 4(R31)          ; 0FE20004 - Guarda R2 en MEM[R31+4]
LW  R1, 8(R0)           ; 08010008 - R1 = MEM[8] = 8 (tamaño del frame)
ADD R31, R31, R1        ; 07E1F800 - R31 = R31 + 8 (avanza puntero de pila)

; -- Cuerpo de la ISR --
LW  R2, 0x0C(R0)        ; 0802000C - R2 = MEM[12] (acumulador persistente entre IRQs)
LW  R1, 4(R0)           ; 08010004 - R1 = MEM[4]
LW  R3, 12(R0)
ADD R2, R1, R2          ; 04221000 - R2 = R1 + R2
MAC R7, R1, R3
SW  R7, 0x7004(R6)      ; 0CC27004 - Escribe R2 en el puerto de salida
SW  R2, 0x0C(R0)        ; 0C02000C - MEM[12] = R2 (guarda acumulador actualizado)
SW  R7, 0x7008(R6)      ; 0CC17008 - Escribe R1 en puerto de salida secundario (ACK IRQ)

; -- Restaurar contexto (pop) --
LW  R1, 8(R0)           ; 08010008 - R1 = 8 (tamaño del frame)
SUB R31, R31, R1        ; 07E1F801 - R31 = R31 - 8 (retrocede puntero de pila)
LW  R1, 0(R31)          ; 0BE10000 - Restaura R1 desde MEM[R31]
LW  R2, 4(R31)          ; 0BE20004 - Restaura R2 desde MEM[R31+4]

; -- Retorno --
RTE                      ; 20000000 - Retorno de excepción
LW  R1, 0x7FFF(R6)      ; 08C17FFF - Guardia: acceso fuera de rango (no debería ejecutarse)

; ----- Padding Words 82-95 -----
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

; Rutina de Servicio de Data Abort (Words 96-99, @0x180)
LW  R1, 0x14(R6)        ; 08C10014 - R1 = MEM[0x14] (código 0x00000AB0)
SW  R1, 0x7004(R6)      ; 0CC17004 - Escribe código de abort en puerto de salida
BEQ R0, R0, -1          ; 1000FFFF - Bucle infinito
RTE                      ; 20000000 - (nunca se ejecuta)

;Padding
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

; Rutina de Servicio de UNDEF
LW  R1, 0x1C(R6)        ; 08C1001C - R1 = MEM[0x1C] (código 0x0BAD0C0D)
SW  R1, 0x7004(R6)      ; 0CC17004 - Escribe código de undef en puerto de salida
BEQ R0, R0, -1          ; 1000FFFF - Bucle infinito
RTE                      ; 20000000 - (nunca se ejecuta)
