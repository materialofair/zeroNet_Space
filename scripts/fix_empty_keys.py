#!/usr/bin/env python3
"""Find and fix empty keys in Localizable.xcstrings."""

import json


def find_and_fix_empty_keys():
    file_path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/Resources/Localizable.xcstrings"

    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    empty_keys = []
    fixed_keys = {}

    # Find all empty keys
    for key, value in data["strings"].items():
        if not value or not value.get("localizations"):
            empty_keys.append(key)

    print(f"Found {len(empty_keys)} empty keys:")
    for key in empty_keys[:20]:  # Show first 20
        print(f"  - {key}")

    # Define translations for common empty keys
    translations = {
        "files.search.placeholder": {"en": "Search files", "zh-Hans": "搜索文件"},
        "photos.search.placeholder": {"en": "Search photos", "zh-Hans": "搜索照片"},
        "videos.search.placeholder": {"en": "Search videos", "zh-Hans": "搜索视频"},
        "folders.search.placeholder": {"en": "Search folders", "zh-Hans": "搜索文件夹"},
        "tags.search.placeholder": {"en": "Search tags", "zh-Hans": "搜索标签"},
        "gallery.search.placeholder": {"en": "Search gallery", "zh-Hans": "搜索相册"},
        "common.search.placeholder": {"en": "Search", "zh-Hans": "搜索"},
    }

    # Fix known keys
    for key, trans in translations.items():
        if key in empty_keys:
            data["strings"][key] = {
                "extractionState": "manual",
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": trans["en"]}},
                    "zh-Hans": {
                        "stringUnit": {"state": "translated", "value": trans["zh-Hans"]}
                    },
                },
            }
            fixed_keys[key] = trans
            print(f"\n✓ Fixed: {key}")
            print(f"  en: {trans['en']}")
            print(f"  zh-Hans: {trans['zh-Hans']}")

    # Remove remaining empty keys (they might be auto-extracted junk)
    remaining_empty = [k for k in empty_keys if k not in fixed_keys]
    if remaining_empty:
        print(f"\n⚠️  Removing {len(remaining_empty)} remaining empty/junk keys...")
        for key in remaining_empty:
            del data["strings"][key]

    # Write back
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Fixed {len(fixed_keys)} keys")
    print(f"✅ Removed {len(remaining_empty)} empty/junk keys")
    print(f"✅ Total valid keys remaining: {len(data['strings'])}")


if __name__ == "__main__":
    find_and_fix_empty_keys()
