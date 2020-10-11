ASM=asl
ASMFLAGS=-cpu Z80 -Werror

BIN_GEN=p2bin
BIN_FLAGS=-r \$$-\$$ -k
DEFINES=-D POST

DEP=./tools/asmdep.py
MAKEDEPEND=$(DEP) -t $@ $< $(DEP_DIR)/$*.d

PROGRAMMER=minipro
#EEPROM=AT28C25
EEPROM=CAT28C16A

SRC_DIR=./src
BIN_DIR=./build
PLS_DIR=$(BIN_DIR)
DEP_DIR=$(BIN_DIR)/deps

vpath %.s $(SRC_DIR)

SRC_FILES = $(wildcard $(SRC_DIR)/*.s)
BIN_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(BIN_DIR)/%.bin)
PLS_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(PLS_DIR)/%.p)
DEP_FILES = $(SRC_FILES:$(SRC_DIR)/%.s=$(DEP_DIR)/%.d)

dir_guard=@mkdir -p $(@D)

all: $(BIN_FILES)

what:
	@echo $(DEP_FILES)

$(BIN_DIR)/%.bin: $(SRC_DIR)/%.s
$(BIN_DIR)/%.bin: $(SRC_DIR)/%.s $(DEP_DIR)/%.d | $(DEP_DIR)
	$(dir_guard)
	@$(MAKEDEPEND)
	$(ASM) $(ASMFLAGS) $(DEFINES) -o $(PLS_DIR)/$*.p $< 
	$(BIN_GEN) $(PLS_DIR)/$*.p $@ $(BIN_FLAGS)


#seg_test: seg_test.bin
#	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

bios:	$(BIN_DIR)/bios.bin
	@echo "Building bios..."

console: $(BIN_DIR)/console.bin
	$(PROGRAMMER) -p $(EEPROM) -z -w build/console.bin

.PHONY: clean help

clean:
	@echo "Cleaning build directory..."
	@rm -f $(BIN_FILES) $(DEP_FILES) $(PLS_FILES)
	@if [ -d $(DEP_DIR) ]; then rmdir $(DEP_DIR); fi

$(DEP_DIR): ; @mkdir -p $@

$(DEP_FILES):

include $(wildcard $(DEP_FILES))
