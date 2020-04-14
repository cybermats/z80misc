ASM=asl
ASMFLAGS=-cpu Z80
BIN_GEN=p2bin
BIN_FLAGS=-r \$$-\$$ +k
DEP=./tools/asmdep.py
MAKEDEPEND=$(DEP) $< $(DEP_DIR)/$*.d

PROGRAMMER=minipro
EEPROM=AT28C25
#EEPROM=CAT28C16A

SRC_DIR=./src
BIN_DIR=./build
PLS_DIR=$(BIN_DIR)/plist
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

$(PLS_DIR)/%.p: $(SRC_DIR)/%.s
$(PLS_DIR)/%.p: $(SRC_DIR)/%.s $(DEP_DIR)/%.d | $(DEP_DIR)
	$(dir_guard)
	@$(MAKEDEPEND)
	$(ASM) $(ASMFLAGS) -o $@ $<

$(BIN_DIR)/%.bin: $(PLS_DIR)/%.p
	$(dir_guard)
	$(BIN_GEN) $< $@ $(BIN_FLAGS)

#seg_test: seg_test.bin
#	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

.PHONY: clean help

clean:
	rm -f $(BIN_FILES) $(DEP_FILES) $(PLS_FILES)
	rmdir $(PLS_DIR)
	rmdir $(DEP_DIR)

$(DEP_DIR): ; @mkdir -p $@

$(DEP_FILES):

include $(wildcard $(DEP_FILES))
