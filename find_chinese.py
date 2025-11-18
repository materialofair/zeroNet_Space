#!/usr/bin/env python3
import os
import re
import sys


def find_chinese_strings(file_path):
    """Find all Chinese strings in a Swift file"""
    chinese_pattern = re.compile(r'"[^"]*[\u4e00-\u9fa5]+[^"]*"')
    results = []

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            lines = content.split("\n")

            for line_num, line in enumerate(lines, 1):
                matches = chinese_pattern.findall(line)
                for match in matches:
                    # Skip if it's already using String(localized:)
                    if "String(localized:" not in line:
                        results.append(
                            {
                                "file": os.path.basename(file_path),
                                "line": line_num,
                                "string": match,
                                "context": line.strip(),
                            }
                        )
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)

    return results


def main():
    base_path = "ZeroNet-Space/Views"
    all_results = []

    for root, dirs, files in os.walk(base_path):
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                results = find_chinese_strings(file_path)
                all_results.extend(results)

    # Group by file
    by_file = {}
    for result in all_results:
        file_name = result["file"]
        if file_name not in by_file:
            by_file[file_name] = []
        by_file[file_name].append(result)

    # Print results
    print(
        f"Found {len(all_results)} hardcoded Chinese strings in {len(by_file)} files:\n"
    )

    for file_name in sorted(by_file.keys()):
        print(f"\n{'=' * 60}")
        print(f"File: {file_name}")
        print(f"{'=' * 60}")
        for item in by_file[file_name]:
            print(f"Line {item['line']}: {item['string']}")
            print(f"  Context: {item['context'][:80]}")

    print(f"\n\nTotal: {len(all_results)} hardcoded Chinese strings")


if __name__ == "__main__":
    main()
