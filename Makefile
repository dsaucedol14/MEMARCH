# ==============================================================================
# MEMARCH — TB-01: Profundidad de stack según paradigma
# ==============================================================================
#
# Targets:
#   make           — compila ./tb01_driver
#   make run       — ejecuta y muestra en pantalla
#   make data      — ejecuta y guarda CSV en data/
#   make verify    — verifica que el crecimiento es lineal O(n)
#   make clean     — elimina objetos, binario y CSVs
# ==============================================================================

CC      := gcc
ASM     := nasm
CFLAGS  := -O2 -g -Wall -Wextra -no-pie
ASFLAGS := -f elf64 -g -F dwarf

BIN     := tb01_driver
ASM_DIR := ..
ASM_OBJ := factorial_rec.o factorial_iter.o
CSV     := data/tb01_$(shell hostname)_$(shell date +%Y%m%d).csv

.PHONY: all run data verify clean

all: $(BIN)

$(BIN): tb01_driver.c $(ASM_OBJ)
	$(CC) $(CFLAGS) tb01_driver.c $(ASM_OBJ) -o $(BIN)

factorial_rec.o: $(ASM_DIR)/factorial_rec.asm
	$(ASM) $(ASFLAGS) $< -o $@

factorial_iter.o: $(ASM_DIR)/factorial_iter.asm
	$(ASM) $(ASFLAGS) $< -o $@

run: $(BIN)
	./$(BIN)

data: $(BIN)
	mkdir -p data
	./$(BIN) > $(CSV)
	@echo "CSV escrito en $(CSV)"
	@cat $(CSV)

verify: data
	@echo ""
	@echo "--- Verificación de crecimiento lineal O(n) ---"
	@awk -F, 'NR>1 && $$2=="rec" { \
		if (n_ant > 0) { \
			r_n = $$1 / n_ant; \
			r_b = $$3 / b_ant; \
			printf "n=%4d->%4d  bytes=%6d->%6d  ratio_n=%.2f  ratio_bytes=%.2f  bytes/nivel=%.2f\n", \
				n_ant, $$1, b_ant, $$3, r_n, r_b, $$4; \
		} \
		n_ant = $$1; b_ant = $$3; \
	}' $(CSV)

clean:
	rm -f $(ASM_OBJ) $(BIN)
	rm -rf data
