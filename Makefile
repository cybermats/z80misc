ASM=vasmz80_oldstyle
ASMFLAGS=-Fbin -dotdir
PROGRAMMER=minipro
EEPROM=CAT28C16A

%.bin: %.s
	$(ASM) $(ASMFLAGS) -o $@ $<

seg_test: seg_test.bin
	$(PROGRAMMER) -p $(EEPROM) -w seg_test.bin

.PHONY: clean

clean:
	rm -f *.bin
