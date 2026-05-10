; ============================================================================
; tb_abort.asm
; Caso: GESTION DE ERRORES (Data_abort) y limpieza del registro de error
; ----------------------------------------------------------------------------
; La FSM secundaria (Memory_error / No_error) debe activar Mem_Error y cargar
; Addr_Error_Reg cuando ocurre alguno de:
;   (a) Acceso desalineado
;   (b) No DevSel (direccion fuera de los rangos validos)
;   (c) Escritura a Addr_Error_Reg (read-only)
; El error se limpia leyendo 0x01000000.
; ----------------------------------------------------------------------------
; ATENCION: este test depende de la rutina RT_Abort situada en word 96 de la
; ROM de instrucciones (ya que el vector 2 = beq +93). El .asm no puede
; controlar la posicion absoluta, asi que ENTREGAMOS LA ROM YA COMPILADA en
; memoriaRAM_I_abort.vhd (sustituir el archivo actual por ese al simular).
; Si se quiere regenerar via script.py habria que rellenar con 90 nops entre
; la prueba y la rutina; es mas limpio usar la ROM precompilada.
; ----------------------------------------------------------------------------
; Programa principal (words 4-7):
;   word 4: lw R12, 0x108(R0)   ; R12 = MD[0x108] = 0x01000000 (dir Addr_Error_Reg)
;                                 MISS s0v? bloque@0x100   (cont_m=1, cont_r=1)
;   word 5: lw R1, 0x1(R0)       ; (a) DESALINEADO -> abort
;                                  El MIPS salta al vector 2 -> RT_Abort en word 96.
;                                  Mem_Error='1' durante el ciclo del fallo.
;                                  Addr_Error_Reg <- 0x00000001 (la dir desalineada)
;   word 6: nop                  ; (no se llega: rte vuelve a word 5)
;   word 7: beq R0, R0, -1       ; bucle infinito (no se llega)
;
; RT_Abort (word 96-97):
;   word 96: lw R20, 0(R12)      ; R20 <- *(0x01000000)
;                                  Esta lectura LIMPIA Mem_Error y devuelve la
;                                  dir que causo el fallo (R20 debe quedar 0x1).
;                                  Tras este ciclo Mem_Error vuelve a '0'.
;   word 97: rte                 ; vuelve a word 5 -> el lw desalineado vuelve a
;                                  fallar -> ciclo de error/limpieza repetido.
; ----------------------------------------------------------------------------
; PARA PROBAR LOS OTROS DOS TIPOS DE ERROR (b) y (c) basta con cambiar
; la instruccion de word 5:
;   (b) lw R1, 0x300(R0)         ; 0x300 esta fuera de todos los rangos -> no DevSel
;   (c) sw R1, 0(R12)            ; escritura a Addr_Error_Reg (RO) -> abort
; (El comportamiento de la rutina RT_Abort y la limpieza es identico.)
; ----------------------------------------------------------------------------
; Verificacion en GTKWave:
;   - Mem_Error pasa de '0' a '1' el ciclo del lw desalineado (word 5)
;   - load_addr_error='1' ese mismo ciclo, Addr_Error_Reg <- 0x00000001
;   - Data_abort='1' ese ciclo (lo recibe la UC del MIPS, que salta al vector)
;   - Tras el lw R20, 0(R12) en word 96: Mem_Error vuelve a '0'
;   - Como rte vuelve al lw, el patron se repite: util para ver oscilacion clara
;   - cont_m, cont_w, cont_r, cont_cb estables salvo por el preludio del lw R12
; ============================================================================
; Codigo equivalente sin padding (representacion logica del programa) abajo:

lw R12, 0x108(R0)     ; word 4: cargar 0x01000000 en R12
lw R1,  0x1(R0)       ; word 5: ABORT (a) desalineado

; --- Rutina RT_Abort (debe estar en word 96 de la ROM) ---
; lw R20, 0(R12)
; rte
; ============================================================================
