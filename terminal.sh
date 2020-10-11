#!/bin/sh

picocom /dev/ttyUSB0 -b 115200 -f x --omap crlf,delbs --imap lfcrlf,bsdel
