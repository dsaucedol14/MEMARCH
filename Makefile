# ==============================================================================
# MEMARCH — Memory + Architecture
# Makefile para el driver de benchmarks (final.c + rutinas ASM)
#
# Targets:
#   make           — compila el binario ./memarch_bench
#   make run       — compila y ejecuta el benchmark
#   make perf      — ejecuta bajo perf stat con contadores de hardware
#   make clean     — elimina objetos y binarios
# ==============================================================================

CC      := gcc
ASM     := nasm
CFLAGS  := -O2 -g -Wall -Wextra -no-pie
ASFLAGS := -f elf64 -g -F dwarf
LDFLAGS := -no-pie

BIN     := memarch_bench

ASM_SRC := factorial_rec.asm factorial_iter.asm \
           fibo_rec_lib.asm  fibo_iter_lib.asm  fibo_memo.asm
ASM_OBJ := factorial_rec.o   factorial_iter.o  \
           fibo_rec.o        fibo_iter.o       fibo_memo.o

C_SRC   := final.c

.PHONY: all run perf clean

all: $(BIN)

$(BIN): $(C_SRC) $(ASM_OBJ)
	$(CC) $(CFLAGS) $(C_SRC) $(ASM_OBJ) -o $(BIN)

# Reglas explícitas (los nombres de .asm y .o no coinciden uno a uno
# en los Fibonacci, donde *_lib.asm produce el .o sin sufijo).
factorial_rec.o:  factorial_rec.asm
	$(ASM) $(ASFLAGS) $< -o $@

factorial_iter.o: factorial_iter.asm
	$(ASM) $(ASFLAGS) $< -o $@

fibo_rec.o:       fibo_rec_lib.asm
	$(ASM) $(ASFLAGS) $< -o $@

fibo_iter.o:      fibo_iter_lib.asm
	$(ASM) $(ASFLAGS) $< -o $@

fibo_memo.o:      fibo_memo.asm
	$(ASM) $(ASFLAGS) $< -o $@

run: $(BIN)
	./$(BIN)

# Requiere perf disponible (linux-tools-generic) y
# kernel.perf_event_paranoid <= 1 en WSL2.
perf: $(BIN)
	perf stat -e cycles,instructions,branches,branch-misses,\
cache-references,cache-misses ./$(BIN)

clean:
	rm -f $(ASM_OBJ) $(BIN)
