CFLAGS := -std=c99 -Wall -O2
SSE2   := yes

TARGET ?= $(shell uname -s 2>/dev/null || echo unknown)
override TARGET := $(shell echo $(TARGET) | tr A-Z a-z)
ARCH ?= $(if $(shell which dpkg),$(shell dpkg --print-architecture))
JAVA_HOME ?= $(realpath $(dir $(realpath $(shell which java)))../)

ifeq ($(TARGET), darwin)
	DYLIB     := dylib
	LDFLAGS   := -dynamiclib -Wl,-undefined -Wl,dynamic_lookup -Wl,-single_module
	CFLAGS    += -I $(JAVA_HOME)/include -I $(JAVA_HOME)/include/$(TARGET)
else
	DYLIB     := so
	LDFLAGS   := -shared
ifneq ($(TARGET), android)
	CFLAGS    += -fPIC -I $(JAVA_HOME)/include -I $(JAVA_HOME)/include/$(TARGET)
ifeq ($(TARGET), linux)
ifeq ($(ARCH), armhf)
	CC        := arm-linux-gnueabihf-gcc
	CFLAGS    += -march=armv6 -mfloat-abi=hard -mfpu=vfp
	SSE2      :=
endif
ifeq ($(ARCH), arm64)
	CC        := aarch64-linux-gnu-gcc
	CFLAGS    += -march=armv8-a+fp+simd
	SSE2      :=
endif
endif
endif
endif

CFLAGS += -DHAVE_CONFIG_H -I src/main/include

SRC := $(wildcard src/main/c/*.c)
OBJ  = $(patsubst src/main/c/%.c,$(OBJ_DIR)/%.o,$(SRC))

ifeq ($(TARGET), android)
	CC      := arm-linux-androideabi-gcc
	SYSROOT := $(NDK_ROOT)/platforms/android-9/arch-arm/
	CFLAGS  += --sysroot=$(SYSROOT)
	LDFLAGS += -lc -Wl,--fix-cortex-a8 --sysroot=$(SYSROOT)
	SSE2    :=
endif

SRC     := $(filter-out $(if $(SSE2),%-nosse.c,%-sse.c),$(SRC))
OBJ_DIR := target/$(ARCH)/obj
LIB     := target/$(ARCH)/libscrypt.$(DYLIB)

all: $(LIB)

clean:
	$(RM) $(LIB) $(OBJ)

$(LIB): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

$(OBJ): | $(OBJ_DIR)

$(OBJ_DIR):
	@mkdir -p $@

$(OBJ_DIR)/%.o : src/main/c/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

.PHONY: all clean
