ASM=vasmz80_oldstyle
ASMFLAGS=-Fbin -esc -x
PROGRAMMER=minipro
EEPROM=AT28C25
#EEPROM=CAT28C16A

SRC_DIR=./src
BIN_DIR=./build
DEP_DIR=./build/deps
LST_DIR=./build

vpath %.s $(SRC_DIR)

SOURCES = $(wildcard $(SRC_DIR)/*.s)
BINS = $(SOURCES:$(SRC_DIR)/%.s=$(BIN_DIR)/%.bin)
DEPS = $(SOURCES:$(SRC_DIR)/%.s=$(DEP_DIR)/%.d)
LSTS = $(SOURCES:$(SRC_DIR)/%.s=$(LST_DIR)/%.lst)

dir_guard=@mkdir -p $(@D)

all: $(BINS)
	@echo "Building..."

include $(DEPS)


$(DEP_DIR)/%.d: $(SRC_DIR)/%.s
	$(dir_guard)
	@set -e; rm -f $@; \
	$(ASM) $(ASMFLAGS) -dependall=make -quiet -o $(BIN_DIR)/$*.bin  $< > $@.$$$$; \
	sed 's,\($*\)\.bin[ :]*,\1.bin $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

$(BIN_DIR)/%.bin: $(SRC_DIR)/%.s
	$(dir_guard)
	$(ASM) $(ASMFLAGS) -L $(LST_DIR)/$*.lst -o $@ $<

#seg_test: seg_test.bin
#	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

.PHONY: clean help

clean:
	rm -f $(BINS) $(DEPS) $(LSTS)
