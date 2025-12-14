# Target binary name (must match BINARY_NAME in deploy_binary.sh)
TARGET = glochidia_app

# Source files
SRC = glochidia_app.c

# Flags for compilation
CFLAGS = -Wall -Werror -Os -std=c99 -static

# Cross-compiler: wrapper script uses podman to run in musl container
CC = x86_64-linux-musl-gcc

all: $(TARGET)

$(TARGET): $(SRC)
	# Cross-compiling for x86_64 with musl static linking using podman container
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f $(TARGET)

install-wrapper:
	cp x86_64-linux-musl-gcc ~/bin/
	chmod +x ~/bin/x86_64-linux-musl-gcc

# Optional: Add .PHONY targets to avoid file conflicts
.PHONY: all clean install-wrapper
