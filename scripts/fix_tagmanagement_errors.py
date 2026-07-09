#!/usr/bin/env python3
"""Fix TagManagementView.swift compilation errors."""


def fix_tagmanagement():
    file_path = "/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space/ZeroNet-Space/Views/Tags/TagManagementView.swift"

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Fix all the broken Section headers
    fixes = [
        # Line 322: TextField section
        (
            'SectString(localized: "tags.name.placeholder")                    TextField("标签名称", text: $tagName)\n                } heaString(localized: "folders.basicInfo")\n                    Text("基本信息")',
            'Section {\n                    TextField(String(localized: "tags.name.placeholder"), text: $tagName)\n                } header: {\n                    Text(String(localized: "folders.basicInfo"))',
        ),
        # Line 360: Icon section
        (
            '} heString(localized: "folders.selectIcon"){\n                    Text("选择图标")',
            '} header: {\n                    Text(String(localized: "folders.selectIcon"))',
        ),
        # Line 387: Color section
        (
            '} hString(localized: "folders.selectColor") {\n                    Text("选择颜色")',
            '} header: {\n                    Text(String(localized: "folders.selectColor"))',
        ),
        # Line 400: Preview section
        (
            '} heaString(localized: "folders.preview") {\n                    Text("预览")',
            '} header: {\n                    Text(String(localized: "folders.preview"))',
        ),
        # Line 404: Fix navigationTitle
        (
            '.navigationTitle("编辑标签")',
            '.navigationTitle(String(localized: "tags.edit.title"))',
        ),
        # Line 407: Fix ToolbarItem with broken placement
        (
            'ToolbarItem(placement: .cancellationAction)String(localized: "common.cancel")                   Button("取消") {',
            'ToolbarItem(placement: .cancellationAction) {\n                    Button(String(localized: "common.cancel")) {',
        ),
        # Remove extra closing brace that will appear after the fixes
        (
            "        }\n\n    private func saveChanges()",
            "    }\n\n    private func saveChanges()",
        ),
    ]

    for old, new in fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"✓ Fixed: {old[:50]}...")
        else:
            print(f"⚠ Not found: {old[:50]}...")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"\n✅ Fixed TagManagementView.swift")


if __name__ == "__main__":
    fix_tagmanagement()
