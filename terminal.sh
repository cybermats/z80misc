#!/bin/sh

picocom /dev/ttyUSB0 -b 115200 -f x --omap crlf,delbs --imap lfcrlf, \
	--send-cmd "sx -vv" --receive-cmd "rx -vv"
