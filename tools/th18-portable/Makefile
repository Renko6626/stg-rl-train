TOOLCHAIN ?= $(HOME)/Tools/llvm-mingw-20260826-msvcrt-ubuntu-22.04-x86_64
WINCC := $(TOOLCHAIN)/bin/i686-w64-mingw32-clang
HOSTCC ?= cc
OUT ?= ../../dist/th18-portable/TH18-AI.exe
HOST_TEST ?= /tmp/th18-launcher-helpers-test
CFLAGS := -std=c11 -O2 -Wall -Wextra -Werror

.PHONY: all check
all: $(OUT)

$(OUT): launcher.c
	mkdir -p "$(dir $(OUT))"
	$(WINCC) $(CFLAGS) -municode -mwindows -static -Wl,--nxcompat,--dynamicbase -o "$@" "$<" -lcomdlg32 -lshell32 -ladvapi32

check:
	$(HOSTCC) $(CFLAGS) -DTH18_LAUNCHER_TEST launcher.c -o "$(HOST_TEST)"
	"$(HOST_TEST)"
