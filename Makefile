ASM = nasm
CC = gcc
ASMFLAGS = -f elf64 -g
CFLAGS = -no-pie -g
SDLFLAGS = $(shell sdl2-config --cflags --libs)

TARGET = play-voidrunner
all: $(TARGET)

build/main.o: src/main.asm
	mkdir -p build
	$(ASM) $(ASMFLAGS) -o $@ $<

$(TARGET): build/main.o
	$(CC) $(CFLAGS) -o $@ $^ $(SDLFLAGS)

clean:
	rm -rf build $(TARGET)

run: $(TARGET)
	./$(TARGET)
