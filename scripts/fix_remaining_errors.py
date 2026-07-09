#!/usr/bin/env python3
"""Fix remaining compilation errors in NetworkVerificationView and TagManagementView."""


def fix_network_verification():
    file_path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Security/NetworkVerificationView.swift"

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Fix line 185: Broken PermissionRow for bluetooth
    old = """                   String(localized: "network.permission.notNeeded")rmissionRow(
                            icon: "antenna.radiowaves.left.and.right",
                            name: String(localized: "network.permission.bluetooth"),
                            purpose: "完全不需要",
                            status: .denied
                        )"""

    new = """                        PermissionRow(
                            icon: "antenna.radiowaves.left.and.right",
                            name: String(localized: "network.permission.bluetooth"),
                            purpose: String(localized: "network.permission.notNeeded"),
                            status: .denied
                        )"""

    if old in content:
        content = content.replace(old, new)
        print("✓ Fixed NetworkVerificationView bluetooth PermissionRow")
    else:
        print("⚠ Pattern not found in NetworkVerificationView")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)


def fix_tagmanagement():
    file_path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Tags/TagManagementView.swift"

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Fix line 61: Broken Button label
    old = """          String(localized: "common.edit")                  Label("编辑", systemImage: "pencil")"""
    new = """                                Label(String(localized: "common.edit"), systemImage: "pencil")"""

    if old in content:
        content = content.replace(old, new)
        print("✓ Fixed TagManagementView edit button label")
    else:
        print("⚠ Pattern not found in TagManagementView")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)


def verify_structure():
    """Check EditTagView structure for missing closing brace."""
    file_path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Tags/TagManagementView.swift"

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Check line 420 area for proper closing
    print("\n--- Checking EditTagView closing structure ---")
    for i in range(415, min(425, len(lines))):
        print(f"Line {i + 1}: {lines[i].rstrip()}")


if __name__ == "__main__":
    fix_network_verification()
    fix_tagmanagement()
    verify_structure()
    print("\n✅ Applied all fixes")
