# Entorno experimental — MEMARCH

**Proyecto:** MEMARCH — Memory + Architecture
**Documento:** `docs/environment.md` — Especificación detallada del hardware y software usados en las mediciones
**Versión:** 1.0 — Mayo 2026

---

## Propósito de este documento

La reproducibilidad de los resultados de MEMARCH depende críticamente del hardware donde se ejecutan los benchmarks. Métricas como ciclos de CPU, IPC, tasa de fallos de caché y comportamiento del predictor de saltos son **dependientes de la microarquitectura**, no de la ISA. Por ello este documento describe con precisión cada plataforma usada en las mediciones, siguiendo las recomendaciones del *System V ABI Implementation Notes* y de las guías de optimización de Intel y Agner Fog.

MEMARCH ejecuta cada experimento en **dos escenarios** complementarios:

- **Escenario A — Plataforma principal de desarrollo:** equipo de alto rendimiento basado en Intel Raptor Lake (i7-13700HX). Representa hardware contemporáneo de gama alta con arquitectura híbrida P-core/E-core.
- **Escenario B — Plataforma de referencia de bajo perfil:** equipo basado en Intel Ivy Bridge (i5-3320M). Representa hardware aún en uso en entornos académicos y administrativos del TecNM, sin arquitectura híbrida ni extensiones AVX2.

El contraste entre ambos permite estudiar la **portabilidad de los hallazgos** a través de 11 años de evolución microarquitectónica.

---

## Tabla de contenido

1. [Escenario A — Intel Core i7-13700HX (Raptor Lake)](#escenario-a--intel-core-i7-13700hx-raptor-lake)
2. [Escenario B — Intel Core i5-3320M (Ivy Bridge)](#escenario-b--intel-core-i5-3320m-ivy-bridge)
3. [Comparativa lado a lado](#comparativa-lado-a-lado)
4. [Implicaciones para las mediciones](#implicaciones-para-las-mediciones)
5. [Procedimiento de captura de especificaciones](#procedimiento-de-captura-de-especificaciones)
6. [Plantilla de bitácora por corrida](#plantilla-de-bitácora-por-corrida)

---

## Escenario A — Intel Core i7-13700HX (Raptor Lake)

### A.1 Procesador

| Atributo | Valor |
|---|---|
| Modelo | Intel® Core™ i7-13700HX |
| Familia/Modelo/Stepping (CPUID) | Family 6, Model 191 (0xBF), Stepping 2 |
| Identificador interno | GenuineIntel B06F2 |
| Microarquitectura | Raptor Lake-HX |
| Nodo de fabricación | Intel 7 (≈10 nm) |
| Año de lanzamiento | Q1 2023 |
| Frecuencia base | 2.10 GHz |
| Frecuencia turbo máxima | 5.00 GHz (P-cores) |
| TDP base / máximo | 55 W / 157 W |
| Socket | FCBGA1964 |

### A.2 Topología de núcleos (arquitectura híbrida)

| Tipo de núcleo | Cantidad | Hilos por núcleo | Total hilos |
|---|---|---|---|
| Performance (P-core, Raptor Cove) | 8 | 2 (Hyper-Threading) | 16 |
| Efficient (E-core, Gracemont) | 8 | 1 | 8 |
| **Total** | **16** | — | **24** |

> **Implicación MEMARCH:** la coexistencia de P-cores y E-cores introduce variabilidad entre corridas si el planificador del SO migra el proceso entre tipos de núcleos. Las mediciones se deben fijar al CPU con `taskset -c 0` (P-core 0) para garantizar consistencia.

### A.3 Jerarquía de caché

| Nivel | Capacidad por núcleo | Total | Latencia típica |
|---|---|---|---|
| L1 instrucciones (P-core) | 32 KB | 8 × 32 KB | 4–5 ciclos |
| L1 datos (P-core) | 48 KB | 8 × 48 KB | 4–5 ciclos |
| L1 (E-core, compartido por pares) | 64 KB I + 32 KB D | — | 4–5 ciclos |
| L2 (P-core) | 2 MB | 8 × 2 MB = 16 MB | 14–16 ciclos |
| L2 (E-core, compartido por cluster de 4) | 4 MB por cluster | 2 × 4 MB = 8 MB | 14–16 ciclos |
| **L2 total** | — | **24 MB** | — |
| **L3 (compartido entre todos los núcleos)** | — | **30 MB** | 40–60 ciclos |

### A.4 Memoria

| Atributo | Valor |
|---|---|
| Tipo soportado | DDR4-3200 / DDR5-4800 |
| Canales | 2 |
| Capacidad máxima | 128 GB |
| ECC | No (variante consumer) |

### A.5 Extensiones de ISA relevantes

`x86-64`, `SSE4.1`, `SSE4.2`, `AVX`, `AVX2`, `AVX-VNNI`, `AES-NI`, `RDRAND`, `RDSEED`, `FSGSBASE`, `BMI1`, `BMI2`, `FMA3`, `POPCNT`, `Intel VT-x`, `VT-d`, `EPT`.

> MEMARCH no usa AVX/AVX2 en las rutinas analizadas (son enteras y escalares), pero su presencia es relevante porque el SO y la libc sí pueden usarlas en rutas de soporte (`memset`, `memcpy`, etc.) lo que altera mediciones marginales.

### A.6 Sistema operativo y herramientas

| Componente | Versión |
|---|---|
| Host OS | Windows 11 Pro 24H2 |
| Subsystem | WSL2 (Windows Subsystem for Linux v2) |
| Guest OS | Ubuntu 24.04.1 LTS |
| Kernel | Linux 5.15.x (WSL2) |
| Compilador C | GCC 13.2.0 |
| Ensamblador | NASM 2.16.01 |
| Linker | GNU ld 2.42 |
| Profiler | perf (linux-tools 6.5+) |
| Depurador | GDB 14.0 |
| Desensamblador | objdump (binutils 2.42) |

---

## Escenario B — Intel Core i5-3320M (Ivy Bridge)

### B.1 Procesador

| Atributo | Valor |
|---|---|
| Modelo | Intel® Core™ i5-3320M |
| Familia/Modelo/Stepping (CPUID) | Family 6, Model 58 (0x3A), Stepping 9 |
| Identificador interno | GenuineIntel |
| Microarquitectura | Ivy Bridge |
| Nodo de fabricación | 22 nm (con transistores tri-gate, primera generación) |
| Año de lanzamiento | Q2 2012 |
| Frecuencia base | 2.60 GHz |
| Frecuencia turbo máxima | 3.30 GHz (1 núcleo activo) / 3.10 GHz (2 núcleos) |
| TDP | 35 W |
| Socket | FCBGA1023 / FCPGA988 (G2) |

### B.2 Topología de núcleos (homogénea)

| Tipo de núcleo | Cantidad | Hilos por núcleo | Total hilos |
|---|---|---|---|
| Núcleo único tipo (sin segmentación P/E) | 2 | 2 (Hyper-Threading) | 4 |

> **Implicación MEMARCH:** topología homogénea. No hay riesgo de migración entre tipos de núcleo, pero la baja cantidad de núcleos exige fijar el proceso para evitar interferencia de otros procesos del sistema.

### B.3 Jerarquía de caché

| Nivel | Capacidad por núcleo | Total | Latencia típica |
|---|---|---|---|
| L1 instrucciones | 32 KB | 2 × 32 KB = 64 KB | 4 ciclos |
| L1 datos | 32 KB | 2 × 32 KB = 64 KB | 4 ciclos |
| L2 (privado por núcleo) | 256 KB | 2 × 256 KB = 512 KB | 11–12 ciclos |
| L3 (Smart Cache, compartido) | — | **3 MB** | 26–31 ciclos |

> **Observación:** el L3 de 3 MB es **10× menor** que el del i7-13700HX. Este factor es central para el contraste experimental: estructuras de datos que caben holgadamente en L3 del escenario A pueden desbordar al escenario B y provocar fallos a memoria principal.

### B.4 Memoria

| Atributo | Valor |
|---|---|
| Tipo soportado | DDR3 / DDR3L 1333–1600 MT/s |
| Canales | 2 |
| Capacidad máxima | 32 GB |
| Ancho de banda máximo | 25.6 GB/s |
| ECC | No |

### B.5 Extensiones de ISA relevantes

`x86-64`, `SSE4.1`, `SSE4.2`, `AVX` (primera generación), `AES-NI`, `RDRAND`, `F16C`, `FSGSBASE`, `Intel VT-x`, `EPT`.

> **Crítico para MEMARCH:** **no soporta AVX2** ni BMI2. Esto significa que las versiones de libc compiladas para AVX2 no se ejecutan; el sistema debe usar variantes SSE4.2 o AVX1. La libc seleccionará automáticamente la variante apropiada vía `ifunc`.

### B.6 Sistema operativo y herramientas

| Componente | Versión |
|---|---|
| Host OS | Linux nativo (sin Windows ni virtualización) |
| Guest OS | Ubuntu 22.04 LTS |
| Kernel | Linux 6.5.x |
| Compilador C | GCC 11.4.0 |
| Ensamblador | NASM 2.15.05 |
| Linker | GNU ld 2.38 |
| Profiler | perf (linux-tools 6.5+) |
| Depurador | GDB 12.1 |
| Desensamblador | objdump (binutils 2.38) |

> **Nota:** el escenario B se ejecuta sobre Linux nativo (no WSL2) porque el i5-3320M es de generación pre-Windows-11 y muchos equipos del TecNM con este CPU ejecutan Linux directamente como solución de extensión de vida útil.

---

## Comparativa lado a lado

| Característica | Escenario A — i7-13700HX | Escenario B — i5-3320M | Factor A/B |
|---|---|---|---|
| Año de lanzamiento | 2023 | 2012 | +11 años |
| Microarquitectura | Raptor Lake (híbrida) | Ivy Bridge (homogénea) | — |
| Nodo de fabricación | Intel 7 (~10 nm) | 22 nm | ~2.2× |
| Núcleos físicos | 16 (8P + 8E) | 2 | 8× |
| Hilos totales | 24 | 4 | 6× |
| Frecuencia base | 2.10 GHz | 2.60 GHz | 0.81× |
| Frecuencia turbo | 5.00 GHz | 3.30 GHz | 1.52× |
| L1D por P-core | 48 KB | 32 KB | 1.5× |
| L2 total | 24 MB | 0.5 MB | 48× |
| L3 compartido | 30 MB | 3 MB | 10× |
| Memoria | DDR5-4800 | DDR3-1600 | ~3× ancho de banda |
| TDP | 55 W (base) | 35 W | 1.57× |
| AVX2 | Sí | **No** | — |
| ISA usada por MEMARCH | x86-64 | x86-64 | idéntica |

---

## Implicaciones para las mediciones

### En el comportamiento del predictor de saltos (RSB)

Ambas microarquitecturas tienen un **Return Stack Buffer** de aproximadamente 16 entradas. Esto significa que el punto de quiebre de la predicción de `RET` en `fib_rec(n)` debería aparecer en torno a `n ≈ 16` en ambos escenarios. **Esta predicción es una de las hipótesis verificables de MEMARCH.**

### En la jerarquía de caché para `fib_memo`

La tabla `int64_t memo[128]` ocupa 1024 bytes. Cabe completamente en L1D de ambos escenarios. Por tanto, los efectos diferenciales por caché en `fib_memo` deberían ser pequeños. Para forzar diferencias observables, MEMARCH puede extender el experimento a tablas de tamaño creciente (hasta exceder L1 → L2 → L3 → DRAM en cada plataforma).

### En el costo absoluto de las llamadas recursivas

El procesador Raptor Lake tiene un front-end más ancho (6 µops/ciclo decodificadas vs 4 en Ivy Bridge), retire de hasta 8 µops/ciclo y una ventana de ejecución fuera de orden mayor (≈512 entradas en ROB vs 168 en Ivy Bridge). Se espera que el costo absoluto en nanosegundos de `fib_rec(30)` sea **significativamente menor** en el escenario A, mientras que la **proporción** entre `fib_rec` y `fib_iter` se mantenga aproximadamente constante. Si la proporción cambia significativamente, hay un efecto microarquitectónico interesante que documentar.

### En la sensibilidad a optimizaciones del compilador

Las optimizaciones de GCC para Ivy Bridge usan un modelo de costo distinto al de Raptor Lake. El mismo `final.c` compilado con `-O2` puede generar secuencias ligeramente distintas en cada plataforma. Para aislar el efecto de las rutinas en NASM (que son idénticas binariamente entre plataformas) de los efectos del código C generado, MEMARCH compila también con `-O0` en cada escenario y compara.

---

## Procedimiento de captura de especificaciones

Antes de cada campaña de mediciones, ejecutar el siguiente protocolo en cada equipo y archivar la salida en `docs/captures/<host>-<YYYYMMDD>.txt`:

```bash
# Identidad del CPU
cat /proc/cpuinfo > captura.txt
lscpu >> captura.txt

# Topología y caché
lscpu --extended >> captura.txt
lstopo-no-graphics --of console >> captura.txt 2>/dev/null

# Memoria
free -h >> captura.txt
sudo dmidecode --type memory >> captura.txt 2>/dev/null

# Núcleo y sistema operativo
uname -a >> captura.txt
cat /etc/os-release >> captura.txt

# Versiones de herramientas
gcc --version >> captura.txt
nasm -v >> captura.txt
perf --version >> captura.txt
ld --version >> captura.txt

# Estado del sistema durante la corrida
uptime >> captura.txt
sysctl kernel.perf_event_paranoid >> captura.txt
sysctl kernel.randomize_va_space >> captura.txt
```

Para Windows / WSL2 adicionalmente:

```powershell
# Información de CPU desde Windows
wmic cpu get Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
Get-WmiObject Win32_Processor | Format-List *
```

---

## Plantilla de bitácora por corrida

Cada ejecución del benchmark debe acompañarse de una entrada en `data/raw/log.md` con esta estructura mínima:

```yaml
corrida_id:       2026-05-20-A-001
escenario:        A
fecha_hora:       2026-05-20T14:32:11-06:00
host:             memarch-laptop
cpu:              Intel Core i7-13700HX
cpu_fijado_a:     0           # P-core 0 vía taskset
gobernador_freq:  performance
estado_termico:   normal      # sensors antes y después
compilacion:
  cc:             gcc-13.2.0
  cflags:         "-O2 -g -Wall -no-pie"
  asm:            nasm-2.16.01
  asmflags:       "-f elf64 -g -F dwarf"
n_repeticiones:   30
seed:             42
salida:           data/raw/2026-05-20-A-001.csv
observaciones: |
  Sistema en reposo, sin procesos de usuario activos.
  AC conectado. Brillo al mínimo. Wi-Fi desactivado.
```

---

<p align="center"><em>MEMARCH — donde la memoria y la arquitectura se encuentran.</em></p>
