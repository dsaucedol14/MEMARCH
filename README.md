# MEMARCH — Memory + Architecture

> Análisis comparativo a nivel de máquina de algoritmos recursivos e iterativos en arquitectura x86-64, mediante implementaciones en NASM y C, con medición de contadores de rendimiento de hardware.

[![Licencia: GPL v3](https://img.shields.io/badge/Licencia-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Lenguajes](https://img.shields.io/badge/lenguajes-NASM%20%7C%20C%20%7C%20Python-orange.svg)]()
[![Plataforma](https://img.shields.io/badge/plataforma-Linux%20%7C%20WSL2-lightgrey.svg)]()
[![Arquitectura](https://img.shields.io/badge/arquitectura-x86--64-red.svg)]()
[![Estado](https://img.shields.io/badge/estado-en%20desarrollo-yellow.svg)]()

---

## Tabla de contenido

1. [Resumen](#resumen)
2. [Motivación](#motivación)
3. [Objetivos](#objetivos)
4. [Metodología](#metodología)
5. [Estructura del repositorio](#estructura-del-repositorio)
6. [Requisitos](#requisitos)
7. [Instalación y compilación](#instalación-y-compilación)
8. [Ejecución de experimentos](#ejecución-de-experimentos)
9. [Reproducibilidad](#reproducibilidad)
10. [Resultados](#resultados)
11. [Roadmap](#roadmap)
12. [Cómo citar](#cómo-citar)
13. [Licencia](#licencia)
14. [Agradecimientos](#agradecimientos)
15. [Contacto](#contacto)

---

## Resumen

**MEMARCH** (Memory + Architecture) es un proyecto de investigación aplicada que estudia el comportamiento real, a nivel de máquina, de algoritmos implementados de forma recursiva e iterativa sobre la arquitectura x86-64. A diferencia de los análisis basados únicamente en complejidad asintótica, MEMARCH cuantifica el impacto de cada paradigma sobre el crecimiento de la pila, el comportamiento del pipeline, la jerarquía de memoria caché y los contadores de rendimiento de hardware (PMC). El proyecto produce evidencia experimental reproducible que vincula decisiones algorítmicas con su costo microarquitectónico.

**Palabras clave:** x86-64, NASM, recursión, iteración, pipeline, stack growth, cache hierarchy, hardware performance counters, perf, microbenchmarking.

---

## Motivación

La enseñanza tradicional de algoritmos suele detenerse en el análisis asintótico (notación Big-O), dejando fuera el costo real que cada paradigma impone sobre la microarquitectura. Sin embargo, dos algoritmos con la misma complejidad teórica pueden mostrar diferencias significativas en:

- Profundidad y crecimiento de la pila de llamadas.
- Predicción de saltos y comportamiento del pipeline.
- Eficiencia del prefetcher y tasa de aciertos de caché (L1/L2/L3).
- Instrucciones retiradas por ciclo (IPC).
- Consumo energético derivado de patrones de acceso a memoria.

MEMARCH aborda esta brecha generando mediciones controladas y reproducibles que permiten contrastar paradigmas algorítmicos desde el nivel del lenguaje ensamblador hasta los eventos observables por el sistema operativo.

---

## Objetivos

### Objetivo general

Caracterizar experimentalmente el comportamiento microarquitectónico de algoritmos recursivos e iterativos en x86-64, estableciendo correspondencias entre decisiones de implementación (C, NASM) y métricas de rendimiento de hardware.

### Objetivos específicos

- Implementar versiones recursivas e iterativas de un conjunto representativo de algoritmos en C y en NASM.
- Medir y comparar contadores de hardware relevantes (ciclos, instrucciones, branch misses, cache misses, IPC, stack usage).
- Analizar el desensamblado generado por GCC y compararlo con NASM escrito a mano.
- Documentar los hallazgos en formato IEEE/ASME para difusión académica.
- Publicar el conjunto de datos crudos y los scripts de análisis para garantizar reproducibilidad.

---

## Metodología

### Algoritmos seleccionados

| Algoritmo | Versión recursiva | Versión iterativa |
|-----------|-------------------|-------------------|
| Factorial | `factorial_rec` | `factorial_iter` |
| Fibonacci | `fib_rec`, `fib_memo` | `fib_iter` |



### Implementaciones

- **C:** compilado con `gcc` bajo flags controlados (`-O0`, `-O2`, `-O3`) para observar el efecto de las optimizaciones.
- **NASM:** ensamblador x86-64 escrito a mano, siguiendo la convención de llamadas System V AMD64.

### Métricas

- Ciclos de CPU (`cycles`).
- Instrucciones retiradas (`instructions`).
- IPC (instructions per cycle).
- Branch instructions y branch misses.
- Cache references y cache misses (L1, LLC).
- Profundidad máxima de pila (vía `/proc/self/status` y análisis de `%rsp`).
- Tiempo de pared (wall-clock) y CPU time.

### Herramientas

- `nasm` — ensamblador.
- `gcc` — compilador C.
- `perf` — contadores de rendimiento de hardware.
- `objdump`, `gdb` — inspección de binarios y depuración.
- `valgrind` / `cachegrind` — simulación de jerarquía de caché.
- `python3` + `pandas` + `matplotlib` — análisis estadístico y visualización.

### Entorno experimental

- **Sistema operativo:** Ubuntu 24.04 LTS sobre WSL2.
- **Kernel:** Linux 5.15+ (WSL2).
- **Compilador:** GCC 13.x.
- **NASM:** 2.16.x.
- **Arquitectura objetivo:** x86-64 (la CPU exacta usada en mediciones se documenta en `docs/environment.md`).

---

## Estructura del repositorio

```
memarch/
├── src/
│   ├── asm/              # Implementaciones en NASM (.asm)
│   ├── c/                # Implementaciones en C (.c, .h)
│   └── common/           # Headers, utilidades, macros de medición
├── benchmarks/
│   ├── runners/          # Scripts que ejecutan perf y recogen métricas
│   └── configs/          # Configuraciones de eventos perf
├── analysis/
│   └── script/          # Scripts Linux de procesamiento y gráficas
│   └── csv/              # CSV 's de resultados
├── docs/
│   ├── paper/            # Documento principal en formato IEEE/ASME
│   ├── figures/          # Figuras finales
│   └── environment.md    # Especificación detallada del hardware
│   └── pruebas/           # Documentos con los resultados de las pruebas
├── results/              # Reportes y gráficas publicables
├── tests/                # Verificación de correctitud de cada implementación
├── Makefile              # Compilación, benchmarks y limpieza
├── LICENSE               # GPL-3.0
└── README.md
```

---

## Requisitos

### Sistema operativo

- Linux (Ubuntu 22.04+ recomendado) o WSL2 sobre Windows.

### Paquetes del sistema

```bash
sudo apt update
sudo apt install -y build-essential nasm gcc make \
                    linux-tools-common linux-tools-generic \
                    valgrind gdb python3 python3-pip
```

### Configuración de `perf` en WSL2

WSL2 requiere ajustar el nivel de paranoia para permitir lectura de contadores:

```bash
sudo sysctl -w kernel.perf_event_paranoid=1
```

Para persistirlo:

```bash
echo 'kernel.perf_event_paranoid=1' | sudo tee -a /etc/sysctl.conf
```

### Paquetes de Python

```bash
pip install -r requirements.txt
```

Contenido mínimo de `requirements.txt`: `pandas`, `numpy`, `matplotlib`, `seaborn`, `scipy`, `jupyter`.

---

## Instalación y compilación

Clonar el repositorio:

```bash
git clone https://github.com/<usuario>/memarch.git
cd memarch
```

Compilar todas las implementaciones:

```bash
make all
```

Compilación selectiva:

```bash
make c          # solo versiones en C
make asm        # solo versiones en NASM
make tests      # construir y ejecutar pruebas de correctitud
```

Limpieza:

```bash
make clean
```

---

## Ejecución de experimentos

### Benchmark individual

```bash
./benchmarks/runners/run_single.sh factorial recursive 20
```

Argumentos: `<algoritmo> <variante> <tamaño_de_entrada>`.

### Suite completa

```bash
./benchmarks/runners/run_all.sh
```

Esto ejecuta cada algoritmo en sus dos variantes, con múltiples tamaños de entrada y `N` repeticiones por configuración (por defecto `N=30`). La salida se escribe en `data/raw/` como archivos CSV con marca de tiempo.

### Análisis y gráficas

```bash
python analysis/scripts/process.py data/raw/
python analysis/scripts/plot.py data/processed/
```

Las figuras se generan en `results/`.

---

## Reproducibilidad

MEMARCH se diseña bajo principios de ciencia abierta y reproducibilidad:

- **Versionado estricto** de compiladores, ensamblador y bibliotecas (ver `docs/environment.md`).
- **Semilla fija** para cualquier componente estocástico (`SEED=42` por defecto).
- **Repeticiones:** cada configuración se ejecuta 30 veces; se reportan media, desviación estándar y mediana.
- **Manejo de outliers:** se descartan valores fuera de 3σ y se documenta su frecuencia.
- **Datos crudos** preservados en `data/raw/` bajo control de versiones (o vinculados vía Zenodo cuando excedan el tamaño práctico de Git).
- **Aislamiento de CPU:** los scripts intentan fijar el proceso a un núcleo (`taskset`) y deshabilitar SMT cuando es posible.

---

## Resultados

> *Sección en construcción.* Los resultados preliminares se publicarán en `docs/paper/` y se sintetizarán aquí conforme avancen los experimentos.

Resumen previsto:

- Curvas de IPC vs. tamaño de entrada para cada algoritmo y variante.
- Comparativas de branch misses entre versiones recursivas e iterativas.
- Mapas de calor del comportamiento de caché.
- Tabla resumen de ganancias/pérdidas relativas.

---

## Roadmap

- [x] Definición del marco experimental.
- [x] Implementación en C de los cuatro algoritmos base.
- [x] Implementación en NASM de los cuatro algoritmos base.
- [ ] Suite automatizada de benchmarks con `perf`.
- [ ] Análisis estadístico y generación de figuras.
- [ ] Redacción del artículo en formato IEEE.
- [ ] Publicación del dataset en Zenodo con DOI.
- [ ] Extensión a algoritmos de ordenamiento (quicksort, mergesort).

---

## Cómo citar

Si utilizas MEMARCH en tu trabajo académico, por favor cítalo como:

```bibtex
@misc{saucedo_hernandez_memarch_2026,
  author       = {Saucedo León, Daniel and Hernández, Manuel},
  title        = {{MEMARCH}: Análisis comparativo a nivel de máquina de algoritmos recursivos e iterativos en x86-64},
  year         = {2026},
  institution  = {UNISUR},
  howpublished = {\url{https://github.com/<usuario>/memarch}},
  note         = {Proyecto de investigación doctoral}
}
```

---

## Licencia

Este proyecto se distribuye bajo los términos de la **GNU General Public License v3.0 (GPL-3.0)**. Consulta el archivo [LICENSE](LICENSE) para el texto completo.

En resumen: puedes usar, modificar y redistribuir este código siempre que cualquier obra derivada se distribuya también bajo GPL-3.0 y conserve los créditos de autoría.

---

## Agradecimientos



---

## Contacto

**Daniel Saucedo León**
**Manuel Hernández**
Estudiante doctoral — Sistemas Computacionales





---

<p align="center">
  <em>MEMARCH</em>
</p>
