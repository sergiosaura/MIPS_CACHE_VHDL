# Informe AOC2 P2 - Compilación

## Estructura

```
informe/
├── informe.tex             # documento maestro
├── secciones/
│   ├── 01_resumen.tex
│   ├── 02_grafo_estados.tex
│   ├── 03_address_breakdown.tex
│   ├── 04_latencias_bus.tex
│   ├── 05_cpi_medio.tex
│   ├── 06_unit_tests.tex
│   ├── 07_integracion_speedup.tex
│   ├── 08_administrativo.tex
│   └── A1_listings_asm.tex
└── figuras/                # capturas GTKWave (vacío hasta simular)
```

## Cómo compilar

```bash
cd informe
pdflatex informe.tex
pdflatex informe.tex      # 2ª pasada para referencias cruzadas
```

## Qué falta por rellenar (marcado con `[TODO: ...]` y `[TBD]` en rojo y azul)

Todas las marcas son en español y se buscan con grep:

```bash
grep -n "TODO\|TBD\|dato{" secciones/*.tex
```

### Lista de medidas a obtener tras simular (FASE 3)

1. **Latencias del bus** (`secciones/04_latencias_bus.tex`):
   - L (latencia 1ª palabra MD) — ciclos en GTKWave entre `MC_send_addr_ctrl=1` y la 1ª palabra
   - R (latencia palabras siguientes) — ciclos entre palabras consecutivas en Fetch
   - CrB(MD) = L + 3R
   - CwB(MD) — copy-back completo, simétrico
   - CwW(MD) — escritura word de write-around
   - CrW/CwW(MDscratch) — debería ser 1
   - CrW/CwW(IO_REG) — debería ser 1

2. **Tests unitarios** (`secciones/06_unit_tests.tex`):
   - Para cada test, anotar el ciclo (en ns) donde se observa el evento principal en el cronograma
   - Confirmar que los contadores finales coinciden con la tabla `tab:contadores-esperados`
   - Si NO coincide → revisar el VHDL (puede haber bug en el caso correspondiente)

3. **Test de integración** (`secciones/07_integracion_speedup.tex`):
   - Contadores finales medidos
   - T_con_MC (ciclos totales hasta entrar en F9)
   - Cálculo numérico del speedup

4. **CPI medio** (`secciones/05_cpi_medio.tex`):
   - Sustituir las probabilidades en la fórmula con los conteos reales
   - Calcular T

5. **Administrativo** (`secciones/08_administrativo.tex`):
   - Horas por tarea/miembro
   - Agradecimientos
   - Autoevaluación

### Capturas GTKWave para insertar en `figuras/`

Recomendaciones (cada captura debe centrarse en lo que demuestra):
- `fig_write_hit.png` — sw que activa MC_WE y dirty bit
- `fig_dirty_repl.png` — secuencia CopyBack → ADDR → Fetch con cont_cb subiendo
- `fig_scratch.png` — Bus_Frame mínimo, addr_non_cacheable=1
- `fig_io.png` — accesos a 0x7000–0x7008 sin tocar bus
- `fig_abort.png` — Mem_Error ascendente, Addr_Error_Reg cargado
- `fig_speedup_cycles.png` — marca de inicio y fin del test integración

Para insertar:

```latex
\begin{figure}[htbp]
  \centering
  \includegraphics[width=0.9\textwidth]{figuras/fig_write_hit.png}
  \caption{Cronograma del test write hit; el sw en el ciclo $t_1$ activa
           MC\_WE0 y el bit dirty del bloque pasa a `1'.}
  \label{fig:tb-write-hit}
\end{figure}
```
