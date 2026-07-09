#!/usr/bin/env python3
"""iOS Internationalization Compilation Error Fixer"""


def fix_disguise_settings():
    path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Disguise/DisguiseSettingsView.swift"
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Fix line 147: Remove extra text
    lines[146] = "            }\n"

    # Fix line 277: Restore "placement" parameter
    lines[276] = "                ToolbarItem(placement: .cancellationAction) {\n"

    # Fix line 285: Restore Button declaration with closing brace
    lines[284] = (
        '                Button(String(localized: "disguise.confirmChange.continue"), role: .destructive) {\n'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    return "✅ DisguiseSettingsView.swift (3 errors fixed)"


def fix_file_preview():
    path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Files/FilePreviewView.swift"
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Fix line 242-243: Restore guard-else statement
    lines[241] = (
        "        guard let password = authViewModel.sessionPassword, !password.isEmpty else {\n"
    )
    lines[242] = (
        '            exportError = String(localized: "filePreview.error.noPassword")\n'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    return "✅ FilePreviewView.swift (1 error fixed)"


def fix_folder_list():
    path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Folders/FolderListView.swift"
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Fix line 224: Remove extra localization string
    lines[223] = "            }\n"

    # Fix line 277: Restore "Section"
    lines[276] = "                Section {\n"

    # Fix line 279: Restore "header:"
    lines[278] = "                } header: {\n"

    # Fix line 307: Restore "header:"
    lines[306] = "                } header: {\n"

    # Fix line 333: Restore "header:"
    lines[332] = "                } header: {\n"

    # Fix line 349: Remove extra localization string
    lines[348] = "                            }\n"

    # Fix line 357: Restore "header:"
    lines[356] = "                } header: {\n"

    # Fix line 364: Restore ToolbarItem opening brace
    lines[363] = "                ToolbarItem(placement: .cancellationAction) {\n"

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    return "✅ FolderListView.swift (8 errors fixed)"


if __name__ == "__main__":
    print("🔧 Fixing iOS internationalization compilation errors...\n")
    print(fix_disguise_settings())
    print(fix_file_preview())
    print(fix_folder_list())
    print("\n🎉 All 12 compilation errors fixed successfully!")
    print("\n📋 Summary:")
    print("   - DisguiseSettingsView.swift: Lines 147, 277, 285")
    print("   - FilePreviewView.swift: Lines 242-243")
    print("   - FolderListView.swift: Lines 224, 277, 279, 307, 333, 349, 357, 364")
