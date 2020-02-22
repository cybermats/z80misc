ASM=vasmz80_oldstyle
ASMFLAGS=-Fbin -dotdir
PROGRAMMER=minipro
EEPROM=AT28C256

%.bin: %.s
	$(ASM) $(ASMFLAGS) -o $@ $<

seg_test: seg_test.bin
	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

.PHONY: clean

clean:
	rm -f *.bin
