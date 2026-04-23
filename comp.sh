#!/bin/bash

# Script estilo AOC2/GHDL+GTKWave para la práctica 3
# Compila el contenido del zip, simula el testbench y abre GTKWave.
# Señales objetivo para la captura:
#   reset, clk, PC, registros usados en decimal y señales útiles.

WORKDIR="WORK"
TB="testbench"
WAVE="testbench.ghw"
GTKW="testbench.gtkw"
STOPTIME="5us"
RUN_MODE="${1:-exec}"  # "exec", "ghdl" o "auto"
set -eu

echo "==> 0) Preparando WORK"
mkdir -p "$WORKDIR"
ghdl --clean --workdir="$WORKDIR" 2>/dev/null || true
rm -f Makefile "$TB" "$WAVE" 2>/dev/null || true

echo "==> 1) Importando fuentes VHDL"
VHDL_FILES=$(ls *.vhd 2>/dev/null || true)
if [ -z "$VHDL_FILES" ]; then
echo "ERROR: no hay .vhd en este directorio"
exit 1
fi

ghdl -i --ieee=synopsys -fexplicit --workdir="$WORKDIR" $VHDL_FILES

echo "==> 2) Generando Makefile para $TB"
ghdl --gen-makefile --ieee=synopsys -fexplicit --workdir="$WORKDIR" "$TB" > Makefile

echo "==> 3) Compilando $TB"
ghdl -m --ieee=synopsys -fexplicit --workdir="$WORKDIR" "$TB"

echo "==> 4) Ejecutando -> $WAVE"
if [ "$RUN_MODE" = "ghdl" ]; then
ghdl -r --ieee=synopsys -fexplicit --workdir="$WORKDIR" "$TB" --stop-time="$STOPTIME" --wave="$WAVE"
else
./"$TB" --stop-time="$STOPTIME" --wave="$WAVE"
fi
echo "==> 5) GTKWave"
if command -v gtkwave >/dev/null 2>&1; then
if [ -f "$GTKW" ]; then
if gtkwave --help 2>&1 | grep -qi -- "--save"; then
gtkwave "$WAVE" --save="$GTKW" >/dev/null 2>&1 &
else
gtkwave "$WAVE" "$GTKW" >/dev/null 2>&1 &
fi
else
gtkwave "$WAVE" >/dev/null 2>&1 &
fi
else
echo "INFO: gtkwave no está disponible en este entorno. Abre $WAVE manualmente."
fi