#!/usr/bin/python3

import argparse
import re
import os

import_pattern = re.compile(r"^[^;]*include *\"([^ ]+)\"",
                            re.IGNORECASE)

def find_dependencies(file):
    output = []
    root = os.path.dirname(file)
    with open(file) as reader:
        for line in reader:
            m = import_pattern.search(line)
            if m:
                include_name = m.group(1)
                include_path = os.path.join(".", root, include_name)
                output.append(include_path)
    return output


def main(input_file, output_file, target):
    print(f"creating dependencies for {input_file} in {output_file}...")
    deps = {
        input_file: False
    }

    while True:
        unsearch = [k for k, v in deps.items() if not v]
        if len(unsearch) == 0:
            break
        for item in unsearch:
            included = find_dependencies(item)
            for file in included:
                if file not in deps:
                    deps[file] = False
            deps[item] = True


    del deps[input_file]
    dep_file = input_file
    if target:
        dep_file = target
        
    with open(output_file, "w") as writer:
        dependencies = " ".join(deps.keys())
        writer.write(f"{dep_file} : {dependencies}\n")
        writer.write(f"{dependencies}:\n")
    return deps


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Extract dependencies.")
    parser.add_argument("input", type=str, help="input file")
    parser.add_argument("output", type=str, help="output file")
    parser.add_argument("-t", "--target", type=str, dest='target',
                        help="target extension")

    args = parser.parse_args()
    main(args.input, args.output, args.target)
    exit(0)
