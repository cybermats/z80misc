ASM=asl
ASMFLAGS=-cpu Z80 -Werror -L

BIN_GEN=p2bin
BIN_FLAGS=-r \$$-\$$
DEFINES=-D POST

HEX_GEN=p2hex
HEX_FLAGS=-r \$$-\$$

DEP=./tools/asmdep.py
MAKEDEPEND=$(DEP) -t $@ $< $(DEP_DIR)/$*.d

LST_PRG=./tools/lstfile.py

PROGRAMMER=minipro
#EEPROM=AT28C25
EEPROM=CAT28C16A

SRC_DIR=./src
BIN_DIR=./build
PLS_DIR=$(BIN_DIR)/pls
DEP_DIR=$(BIN_DIR)/deps
HEX_DIR=$(BIN_DIR)
LST_DIR=$(BIN_DIR)
Z80_DIR=$(BIN_DIR)

vpath %.s $(SRC_DIR)

SRC_FILES = $(wildcard $(SRC_DIR)/*.s)
BIN_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(BIN_DIR)/%.bin)
PLS_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(PLS_DIR)/%.p)
DEP_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(DEP_DIR)/%.d)
HEX_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(HEX_DIR)/%.hex)
LST_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(LST_DIR)/%.lst)
Z80_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(Z80_DIR)/%.z80)

dir_guard=@mkdir -p $(@D)

all: $(BIN_FILES)

what:
	@echo $(DEP_FILES)

$(PLS_DIR)/%.p: $(SRC_DIR)/%.s
$(PLS_DIR)/%.p: $(SRC_DIR)/%.s $(DEP_DIR)/%.d | $(DEP_DIR)
	$(dir_guard)
	@$(MAKEDEPEND)
#	@mv $(SRC_DIR)/$*.lst $(LST_DIR)
	@$(LST_PRG) $(SRC_DIR)/$*.lst $(LST_DIR)/$*.lst
	$(ASM) $(ASMFLAGS) $(DEFINES) -o $(PLS_DIR)/$*.p $<

$(BIN_DIR)/%.bin: $(PLS_DIR)/%.p
	@echo Building $@
	$(dir_guard)
	$(BIN_GEN) $(PLS_DIR)/$*.p $@ $(BIN_FLAGS)

$(BIN_DIR)/%.hex: $(PLS_DIR)/%.p
	@echo Building $@
	$(dir_guard)
	$(HEX_GEN) $(PLS_DIR)/$*.p $@ $(HEX_FLAGS)

$(Z80_DIR)/%.z80: $(BIN_DIR)/%.bin
	@echo Building $@
	$(dir_guard)
	@printf "Z80ASM\x1a\xa\0\0" | cat - $< > $@

#seg_test: seg_test.bin
#	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

bios:	$(BIN_DIR)/bios.bin
	@echo "Building bios..."

console: $(BIN_DIR)/console.bin
	$(PROGRAMMER) -p $(EEPROM) -z -w build/console.bin

lisp:	$(BIN_DIR)/lisp.bin $(HEX_DIR)/lisp.hex $(Z80_DIR)/lisp.z80
	@echo "Building lisp..."

.PHONY: clean help

clean:
	@echo "Cleaning build directory..."
	@rm -f $(BIN_FILES) $(DEP_FILES) $(PLS_FILES) $(HEX_FILES) \
		$(LST_FILES) $(Z80_FILES)
	@if [ -d $(DEP_DIR) ]; then rmdir $(DEP_DIR); fi

$(DEP_DIR): ; @mkdir -p $@

$(DEP_FILES):

include $(wildcard $(DEP_FILES))
