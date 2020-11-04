#!/usr/bin/python3

import argparse
import sys
import re
import contextlib

line_pattern = re.compile(r"""^(?P<include>\(.*\))?\s+(?P<line_no>\d+)\/\s+(?P<mem_no>\w+)\s+:(?P<rest>.*)$""", re.X)

HEADER = """--------------------------------------------------
Z80 DISASSEMBLER LISTING
Line   Addr Opcodes     Label   Instruction
--------------------------------------------------
"""


@contextlib.contextmanager
def smart_open(filename=None, mode='r'):
    if filename and filename != '-':
        file_handle = open(filename, mode)
    else:
        if 'w' in mode:
            file_handle = sys.stdout
        else:
            file_handle = sys.stdin

    try:
        yield file_handle
    finally:
        if (file_handle is not sys.stdout and
                file_handle is not sys.stdin):
            file_handle.close()


def parse(line):
    m = line_pattern.search(line)
    if not m:
        return None
    result = (int(m.group('line_no')),
              True if m.group('include') else None,
              int(m.group('mem_no'), 16),
              m.group('rest'))
    return result


def main(input_file, output_file):
    """Main entry point"""
    print(f'Parsing {input_file} into {output_file}')
    with smart_open(output_file, 'w') as writer:
        with smart_open(input_file) as reader:
            writer.write(HEADER)
            for line in reader:
                if 'Symbol Table' in line:
                    break
                if len(line) == 0 or 'Source File' in line:
                    continue
                result = parse(line)
                if result is None:
                    continue
                (line_no, include, mem_no, rest) = result
                include_str = '+' if include else ' '
                writer.write(f'{line_no:04}{include_str}  '
                             f'{mem_no:04X}{rest}\r\n')


if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(
        description="Extract dependencies.")
    PARSER.add_argument("input", type=str, help="input file")
    PARSER.add_argument("output", type=str, help="output file")

    ARGS = PARSER.parse_args()
    main(ARGS.input, ARGS.output)
    sys.exit(0)
