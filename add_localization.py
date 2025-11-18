#!/usr/bin/env python3
"""Add zh-Hans localization to Xcode project."""

import re


def add_zh_hans_to_project():
    project_file = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space.xcodeproj/project.pbxproj"

    with open(project_file, "r", encoding="utf-8") as f:
        content = f.read()

    # Find and update knownRegions
    # Current: knownRegions = ( en, Base, );
    # Target: knownRegions = ( en, Base, "zh-Hans", );

    pattern = r"(knownRegions\s*=\s*\(\s*en,\s*Base,\s*)"
    replacement = r'\1"zh-Hans", '

    if '"zh-Hans"' in content:
        print("✓ zh-Hans already in knownRegions")
    else:
        content = re.sub(pattern, replacement, content)
        print("✓ Added zh-Hans to knownRegions")

    # Also ensure developmentRegion is set
    if "developmentRegion = en;" in content:
        print("✓ developmentRegion already set to en")

    with open(project_file, "w", encoding="utf-8") as f:
        f.write(content)

    print("\n✅ Project file updated successfully!")
    print("\n⚠️  重要提示：")
    print("1. 需要在 Xcode 中打开项目")
    print("2. 选择项目 -> Info -> Localizations")
    print("3. 点击 '+' 添加 'Chinese, Simplified (zh-Hans)'")
    print("4. 确保 Localizable.xcstrings 被包含在本地化中")


if __name__ == "__main__":
    add_zh_hans_to_project()
