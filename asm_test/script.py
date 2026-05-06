import sys
"""
Autor: Jose Secadura
Fecha: 28/03/2025
Descripción:
Este script permite codificar instrucciones de ensamblador a hexadecimal contempla las instrucciones de la practica3 y el proyecto 1 de 2025.
Puede leer instrucciones desde un archivo .asm pasado por parametros o leer instruccion a instruccion o pasarle varias por parametros.
Nos devuelve la instruccion en ensamblador con su codificacion ademas de un archivo .txt con la RAM en hexadecimal para copiar y pegar.
Funciones:
- ensamblador_a_hex(instruccion): Convierte una instrucción en ensamblador a su representación hexadecimal.
- generar_archivo_ram(instrucciones_hex): Genera un archivo de inicialización de RAM en VHDL con las instrucciones en hexadecimal proporcionadas.
- procesar_entrada(entrada, instrucciones_hex): Procesa la entrada, ya sea desde un archivo o directamente del usuario, y la convierte a hexadecimal.
- main(): Punto de entrada del script. Maneja el modo interactivo o los argumentos de línea de comandos y genera el archivo RAM.
Uso:
- Ejecuta el script con archivos de ensamblador como argumentos o en modo interactivo para ingresar instrucciones directamente.
- La salida es un archivo RAM en VHDL llamado 'ram.txt'.
Nota:
- El script asume un formato específico de instrucciones y mapeo de opcodes puede ser cambiado dependiendo de las que se indiquen.
- Las instrucciones que excedan las 128 palabras serán truncadas en el archivo RAM.
- El programa contempla las todas las instrucciones que aparecen en el manual y aqui tambien se puede ver en el campo de opcodes.
"""
from datetime import datetime


def ensamblador_a_hex(instruccion):
    try:
        partes = instruccion.replace(',', ' ').split()
        if not partes:
            return "00000000"

        opcode = partes[0].lower()

        opcodes = {
            'nop': '000000',
            'add': '000001',
            'sub': '000001',
            'mac': '000001',
            'mac_ini': '000001',
            'and': '000001',
            'or': '000001',
            'mov': '000001',
            'lw': '000010',
            'sw': '000011',
            'beq': '000100',
            'jal': '000101',
            'ret': '000110',
            'lw_inc': '010000',
            'rte': '001000'
        }

        functs = {
            'add': '00000000000',
            'sub': '00000000001',
            'mov': '00000000000',   # mov rd, rs  -> add rd, rs, r0
            'and': '00000000010',
            'or':  '00000000011',
            'mac': '00000000100',
            'mac_ini': '00000000101'
        }

        rs = '00000'
        rt = '00000'
        rd = '00000'
        imm = '0000000000000000'

        if opcode in ['nop', 'rte']:
            pass

        elif opcode == 'ret':
            rs = format(int(partes[1][1:]), '05b')

        elif opcode in ['add', 'sub', 'and', 'or', 'mac', 'mac_ini']:
            # formato: op rd, rs, rt
            rd = format(int(partes[1][1:]), '05b')
            rs = format(int(partes[2][1:]), '05b')
            rt = format(int(partes[3][1:]), '05b')

        elif opcode == 'mov':
            # mov rd, rs  --> add rd, rs, r0
            rd = format(int(partes[1][1:]), '05b')
            rs = format(int(partes[2][1:]), '05b')
            rt = '00000'

        elif opcode in ['lw', 'sw', 'lw_inc']:
            rt = format(int(partes[1][1:]), '05b')
            imm_rs = partes[2].split('(')
            imm_val = int(imm_rs[0], 0)
            if imm_val < 0:
                imm_val = (1 << 16) + imm_val
            imm = format(imm_val & 0xFFFF, '016b')
            rs = format(int(imm_rs[1][1:-1]), '05b')

        elif opcode == 'beq':
            rt = format(int(partes[1][1:]), '05b')
            rs = format(int(partes[2][1:]), '05b')
            imm_val = int(partes[3], 0)
            if imm_val < 0:
                imm_val = (1 << 16) + imm_val
            imm = format(imm_val & 0xFFFF, '016b')

        elif opcode == 'jal':
            rt = format(int(partes[1][1:]), '05b')
            imm_val = int(partes[2], 0)
            if imm_val < 0:
                imm_val = (1 << 16) + imm_val
            imm = format(imm_val & 0xFFFF, '016b')

        else:
            return f"Error procesando '{instruccion}': instrucción no soportada"

        binario = opcodes[opcode] + rs + rt

        if opcode in ['add', 'sub', 'and', 'or', 'mov', 'mac', 'mac_ini']:
            binario += rd + functs[opcode]
        else:
            binario += imm

        hexadecimal = format(int(binario, 2), '08X')
        return hexadecimal

    except Exception as e:
        return f"Error procesando '{instruccion}': {str(e)}"

def generar_archivo_ram(instrucciones_hex):
    # Plantilla base de la RAM
    ram_template = """-- Autor: Jose Secadura, 2º Ing. Informática UNIZAR a fecha de {fecha}

signal RAM : RamType := (
    X"{0}", X"{1}", X"{2}", X"{3}", X"{4}", X"{5}", X"{6}", X"{7}", --word 0,1,...
    X"{8}", X"{9}", X"{10}", X"{11}", X"{12}", X"{13}", X"{14}", X"{15}", --word 8,9,...
    X"{16}", X"{17}", X"{18}", X"{19}", X"{20}", X"{21}", X"{22}", X"{23}", --word 16,...
    X"{24}", X"{25}", X"{26}", X"{27}", X"{28}", X"{29}", X"{30}", X"{31}", --word 24,...
    X"{32}", X"{33}", X"{34}", X"{35}", X"{36}", X"{37}", X"{38}", X"{39}", --word 32,...
    X"{40}", X"{41}", X"{42}", X"{43}", X"{44}", X"{45}", X"{46}", X"{47}", --word 40,...
    X"{48}", X"{49}", X"{50}", X"{51}", X"{52}", X"{53}", X"{54}", X"{55}", --word 48,...
    X"{56}", X"{57}", X"{58}", X"{59}", X"{60}", X"{61}", X"{62}", X"{63}", --word 56,...
    X"{64}", X"{65}", X"{66}", X"{67}", X"{68}", X"{69}", X"{70}", X"{71}", --word 64,...
    X"{72}", X"{73}", X"{74}", X"{75}", X"{76}", X"{77}", X"{78}", X"{79}", --word 72,...
    X"{80}", X"{81}", X"{82}", X"{83}", X"{84}", X"{85}", X"{86}", X"{87}", --word 80,...
    X"{88}", X"{89}", X"{90}", X"{91}", X"{92}", X"{93}", X"{94}", X"{95}", --word 88,...
    X"{96}", X"{97}", X"{98}", X"{99}", X"{100}", X"{101}", X"{102}", X"{103}", --word 96,...
    X"{104}", X"{105}", X"{106}", X"{107}", X"{108}", X"{109}", X"{110}", X"{111}", --word 104,...
    X"{112}", X"{113}", X"{114}", X"{115}", X"{116}", X"{117}", X"{118}", X"{119}", --word 112,...
    X"{120}", X"{121}", X"{122}", X"{123}", X"{124}", X"{125}", X"{126}", X"{127}");--word 120,..."""

    # Crear lista de 128 elementos inicializados a "00000000"
    ram_data = ["00000000"] * 128
    
    # Insertar las instrucciones proporcionadas
    for i, hex_code in enumerate(instrucciones_hex):
        if i >= 128:
            break  # No sobrepasar el tamaño de la RAM
        ram_data[i] = hex_code
    
    # Obtener la fecha actual
    fecha_actual = datetime.now().strftime("%d-%m-%Y")
    
    # Generar el archivo
    with open("ram.txt", "w") as f:
        f.write(ram_template.format(*ram_data, fecha=fecha_actual))

def procesar_entrada(entrada, instrucciones_hex):
    if entrada.strip().lower().endswith('.asm'):
        # Es un archivo
        try:
            with open(entrada, 'r') as f:
                lineas = f.readlines()
            for linea in lineas:
                linea = linea.split(';')[0].strip()  # Ignorar comentarios
                if linea:
                    hex_code = ensamblador_a_hex(linea)
                    instrucciones_hex.append(hex_code)
                    print(f"{linea:30} --> {hex_code}")
        except FileNotFoundError:
            print(f"Error: Archivo '{entrada}' no encontrado")
    else:
        # Es una instrucción directa
        hex_code = ensamblador_a_hex(entrada)
        instrucciones_hex.append(hex_code)
        print(f"{entrada:30} --> {hex_code}")

def main():
    instrucciones_hex = []
    
    if len(sys.argv) > 1:
        # Procesar argumentos de línea de comandos
        for arg in sys.argv[1:]:
            procesar_entrada(arg, instrucciones_hex)
    else:
        # Modo interactivo
        print("Modo interactivo (escribe 'salir' para terminar):")
        while True:
            entrada = input("> ").strip()
            if entrada.lower() == 'salir':
                break
            if entrada:
                procesar_entrada(entrada, instrucciones_hex)

    instrucciones_hex.insert(0, "1021006C")  # Word 3: UNDEF vector
    instrucciones_hex.insert(0, "1021005D")  # Word 2: Data Abort vector
    instrucciones_hex.insert(0, "1021003E")  # Word 1: IRQ vector
    instrucciones_hex.insert(0, "10210003")  # Word 0: Reset vector
    
    # Generar archivo RAM
    generar_archivo_ram(instrucciones_hex)
    print("\nArchivo 'ram.txt' generado con el contenido de la RAM")

if __name__ == "__main__":
    main()