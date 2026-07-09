#!/usr/bin/env python3
"""Fix Localizable.xcstrings by adding missing 'state' field to all stringUnits."""

import json


def fix_xcstrings():
    input_file = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/Resources/Localizable.xcstrings"

    print("📖 Reading Localizable.xcstrings...")
    with open(input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    fixed_count = 0
    total_strings = len(data.get("strings", {}))

    print(f"🔍 Processing {total_strings} string entries...")

    # Process each string entry
    for key, value in data.get("strings", {}).items():
        localizations = value.get("localizations", {})

        for lang, lang_data in localizations.items():
            string_unit = lang_data.get("stringUnit", {})

            # Add 'state' field if missing
            if "state" not in string_unit:
                string_unit["state"] = "translated"
                fixed_count += 1

                # Update the structure
                lang_data["stringUnit"] = string_unit
                localizations[lang] = lang_data

        value["localizations"] = localizations
        data["strings"][key] = value

    print(f"✅ Fixed {fixed_count} missing 'state' fields")

    # Write back to file
    print("💾 Writing updated file...")
    with open(input_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Successfully updated Localizable.xcstrings!")
    print(f"   Total entries: {total_strings}")
    print(f"   Fixed fields: {fixed_count}")

    # Verify the fix
    print("\n🔍 Verifying photos.title...")
    photos_title = data["strings"].get("photos.title", {})
    en_state = (
        photos_title.get("localizations", {})
        .get("en", {})
        .get("stringUnit", {})
        .get("state")
    )
    zh_state = (
        photos_title.get("localizations", {})
        .get("zh-Hans", {})
        .get("stringUnit", {})
        .get("state")
    )

    print(f"   en state: {en_state}")
    print(f"   zh-Hans state: {zh_state}")

    if en_state == "translated" and zh_state == "translated":
        print("\n✅ Verification passed! File is now valid.")
    else:
        print("\n⚠️  Verification failed. Check the file manually.")


if __name__ == "__main__":
    fix_xcstrings()
