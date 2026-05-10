; ============================================================================
; tb_io.asm
; Caso: ACCESOS A REGISTROS IO MAPEADOS EN MEMORIA
; ----------------------------------------------------------------------------
; IO_MD_subsystem decodifica internamente:
;   0x00007000 -> Input_Reg  (lectura: devuelve IO_input)
;   0x00007004 -> Output_Reg (escritura: IO_output, lectura: ultimo escrito)
;   0x00007008 -> ACK_Reg    (escritura: bit0 -> INT_ACK pulso 1 ciclo)
; Estos accesos NO llegan a la MC ni al bus de memoria. Los contadores
; cont_m, cont_w, cont_r, cont_cb NO deben tocarse durante accesos a IO.
; ----------------------------------------------------------------------------
; Eventos esperados (m,w,r,cb):
;   pre1) lw R3, 0x4(R0)     MISS s0v0  R3=0x0000CACA               (1,0,1,0)
;   pre2) lw R5, 0x0(R0)     HIT  s0v0  R5=0x00000001  (bit0=1)     (1,0,2,0)
;
;   (1) sw R3, 0x7004(R0)    IO WRITE Output_Reg = 0x0000CACA       (1,0,2,0)
;       (sin cambios en contadores, IO_output visible)
;
;   (2) lw R1, 0x7000(R0)    IO READ Input_Reg  R1 = IO_input       (1,0,2,0)
;       (testbench pone IO_input=0x00000000, asi que R1=0)
;
;   (3) lw R2, 0x7004(R0)    IO READ Output_Reg R2 = 0x0000CACA     (1,0,2,0)
;
;   (4) sw R5, 0x7008(R0)    ACK_Reg <- bit0 de R5 = '1'             (1,0,2,0)
;       INT_ACK = '1' durante un ciclo, auto-clear al ciclo siguiente
;
;   (5) lw R6, 0x4(R0)       HIT s0v0 (MC intacta tras los IO)        (1,0,3,0)
; ----------------------------------------------------------------------------

; --- Preludio: cargar constantes en MC ---
lw R3, 0x4(R0)        ; pre1: MISS s0v0  R3=0x0000CACA
lw R5, 0x0(R0)        ; pre2: HIT  s0v0  R5=0x00000001  (bit0=1 para ACK)

; --- Caso bajo prueba: IO ---
sw R3, 0x7004(R0)     ; (1) IO_output <= 0x0000CACA
lw R1, 0x7000(R0)     ; (2) R1 <- IO_input
lw R2, 0x7004(R0)     ; (3) R2 <- Output_Reg = 0x0000CACA
sw R5, 0x7008(R0)     ; (4) INT_ACK pulso 1 ciclo

; --- Verificacion: MC intacta ---
lw R6, 0x4(R0)        ; (5) HIT s0v0

; --- Punto observable ---
beq R0, R0, -1

; ----------------------------------------------------------------------------
; Verificacion en GTKWave:
;   - durante (1)-(4): cont_m/w/r/cb sin cambios; Bus_Frame inactivo
;     (los IO no usan el bus de memoria)
;   - IO_addr='1', addr_input/addr_output/addr_ack alternan segun corresponda
;   - en (1): IO_output cambia a 0x0000CACA (visible en el puerto del SoC)
;   - en (4): INT_ACK pulso de 1 ciclo
;   - en (5): hit0/hit1 activos, cont_r incrementa
; Final esperado: m=1, w=0, r=3, cb=0
; ----------------------------------------------------------------------------
; Para testear el IO_input se puede modificar el testbench para asignar otro
; valor a IO_input antes de la simulacion (linea: IO_input <= x"DEADBEEF";).
; ============================================================================
