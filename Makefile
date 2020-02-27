ASM=vasmz80_oldstyle
ASMFLAGS=-Fbin -dotdir
PROGRAMMER=minipro
EEPROM=AT28C256

SRC_DIR=./src
BIN_DIR=./build
DEP_DIR=./build

vpath %.s $(SRC_DIR)

SOURCES = $(wildcard $(SRC_DIR)/*.s)
BINS = $(SOURCES:$(SRC_DIR)/%.s=$(BIN_DIR)/%.bin)
DEPS = $(SOURCES:$(SRC_DIR)/%.s=$(DEP_DIR)/%.d)


help:
	@echo "No default goal."
	@echo $(SOURCES)
	@echo $(BINS)
	@echo $(DEPS)

include $(DEPS)

$(DEP_DIR)/%.d: $(SRC_DIR)/%.s
	@set -e; rm -f $@; \
	$(ASM) $(ASMFLAGS) -dependall=make -quiet -o $*.bin  $< > $@.$$$$; \
	sed 's,\($*\)\.bin[ :]*,\1.bin $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

$(BIN_DIR)/%.bin: $(SRC_DIR)/%.s
	$(ASM) $(ASMFLAGS) -o $@ $<

#seg_test: seg_test.bin
#	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

.PHONY: clean help

clean:
	rm -f $(BINS) $(DEPS)
