#!/usr/bin/env python3
"""
Update Localizable.xcstrings with all missing localization keys
"""

import json


def create_string_entry(key, en_value, zh_value, comment=""):
    """Create a localization string entry"""
    entry = {
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en_value}},
            "zh-Hans": {"stringUnit": {"state": "translated", "value": zh_value}},
        },
    }
    if comment:
        entry["comment"] = comment
    return entry


# Load existing file
with open("Resources/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

# Backup
with open("Resources/Localizable.xcstrings.backup", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("✅ Backup created: Localizable.xcstrings.backup")

# New keys to add
new_keys = {
    # Export Module (20 keys)
    "export.title": ("Batch Export", "批量导出"),
    "export.selectedCount": ("Selected %d items", "已选择 %d 项"),
    "export.selectAll": ("Select All", "全选"),
    "export.deselectAll": ("Deselect All", "取消全选"),
    "export.exportSelected": ("Export Selected", "导出选中项"),
    "export.clear": ("Clear", "清空"),
    "export.failed": ("Export Failed", "导出失败"),
    "export.inProgress": ("Exporting...", "正在导出..."),
    "export.decrypting": (
        "Decrypting and preparing files, please wait...",
        "正在解密并准备文件，请稍候...",
    ),
    "export.decryptingProgress": (
        "Decrypting file %d of %d",
        "正在解密第 %d/%d 个文件",
    ),
    "export.preparingShare": ("Preparing to share...", "正在准备分享..."),
    "export.empty.title": ("No files to export", "没有可导出的文件"),
    "export.empty.subtitle": ("Please import some files first", "请先导入一些文件"),
    "export.error.noPassword": (
        "Cannot get password, please login again",
        "无法获取密码,请重新登录",
    ),
    # Folders Module (25 keys)
    "folders.title": ("Folders", "文件夹"),
    "folders.select.title": ("Select Folder", "选择文件夹"),
    "folders.selectTarget.title": ("Select Target Folder", "选择目标文件夹"),
    "folders.new.title": ("New Folder", "新建文件夹"),
    "folders.edit.title": ("Edit Folder", "编辑文件夹"),
    "folders.allMedia": ("All Media", "所有媒体"),
    "folders.allMedia.default": ("All Media (Default)", "所有媒体（默认）"),
    "folders.allMedia.remove": (
        "All Media (Remove from Folder)",
        "所有媒体（移除文件夹）",
    ),
    "folders.system": ("System Folders", "系统文件夹"),
    "folders.custom": ("Custom Folders", "自定义文件夹"),
    "folders.name.placeholder": ("Folder Name", "文件夹名称"),
    "folders.itemCount": ("%d items", "%d 个项目"),
    "folders.selectIcon": ("Select Icon", "选择图标"),
    "folders.selectColor": ("Select Color", "选择颜色"),
    "folders.basicInfo": ("Basic Info", "基本信息"),
    "folders.preview": ("Preview", "预览"),
    "folders.empty.title": ("Folder is Empty", "文件夹是空的"),
    "folders.empty.subtitle": (
        "Move media files to this folder",
        "将媒体文件移动到此文件夹",
    ),
    # Tags Module (15 keys)
    "tags.title": ("Tags", "标签"),
    "tags.management.title": ("Tag Management", "标签管理"),
    "tags.add.title": ("Add Tags", "添加标签"),
    "tags.select.title": ("Select Tags", "选择标签"),
    "tags.create.title": ("Create New Tag", "创建新标签"),
    "tags.name.placeholder": ("Tag Name", "标签名称"),
    "tags.empty": ("No tags yet", "还没有标签"),
    "tags.usageCount": ("%d uses", "%d 次使用"),
    "tags.inputPrompt": ("Enter new tag name", "输入新标签的名称"),
    # Disguise Mode (40 keys)
    "disguise.title": ("Disguise Mode", "伪装模式"),
    "disguise.enable.title": ("Enable Disguise Mode", "启用伪装模式"),
    "disguise.enable.description": (
        "When enabled, the app will launch with calculator interface instead of login screen",
        "启用后，应用启动时将显示计算器界面而非登录界面",
    ),
    "disguise.calculator.title": ("Disguise Calculator", "伪装计算器"),
    "disguise.passwordSequence": ("Password Sequence", "密码序列"),
    "disguise.setPassword.title": ("Set Password Sequence", "设置密码序列"),
    "disguise.useDefault": ("Use Default Password", "使用默认密码"),
    "disguise.isSet": ("Set", "已设置"),
    "disguise.unlockPassword": ("Unlock Password", "解锁密码"),
    "disguise.instructions.title": ("Instructions", "使用说明"),
    "disguise.instructions.howTo": (
        "Enter this number sequence in calculator and press = to unlock",
        "在计算器中输入此数字序列后按 = 号即可解锁应用",
    ),
    "disguise.instructions.example": (
        "Example: Enter 1234.56 then press =",
        "示例: 输入 1234.56 再按 =",
    ),
    "disguise.warning.defaultPassword": (
        "⚠️ Currently using default password 1234, custom password recommended",
        "⚠️ 当前使用默认密码 1234，建议设置自定义密码",
    ),
    "disguise.tip.calculator": (
        "Calculator is fully functional for normal calculations",
        "计算器完全可用，可进行正常计算",
    ),
    "disguise.tip.numbersOnly": (
        "Password sequence supports only numbers and decimal point",
        "密码序列仅支持数字和小数点",
    ),
    "disguise.tip.noDisplay": (
        "Password sequence won't appear in calculation results",
        "密码序列不会显示在计算结果中",
    ),
    "disguise.tip.noFeedback": (
        "No feedback for wrong password (disguise feature)",
        "密码错误时不会有任何提示（伪装特性）",
    ),
    "disguise.security.title": ("Disguise Mode Security Tips", "伪装模式安全提示"),
    "disguise.security.tips": (
        "• Calculator interface is fully realistic and undetectable\\n• No calculation history is retained\\n• Please memorize your password sequence",
        "• 计算器界面完全真实，无法被识破\\n• 不会保留任何计算历史记录\\n• 请牢记您的密码序列",
    ),
    "disguise.changePassword.required.title": (
        "Password Change Required",
        "需要修改主密码",
    ),
    "disguise.changePassword.required.message": (
        "Disguise mode requires main password to contain only numbers and decimal point.\\n\\nCurrent password contains letters or special characters. Please change to numbers and decimal point only.",
        "伪装模式要求主密码仅包含数字和小数点。\\n\\n当前主密码包含字母或特殊字符，请修改为仅包含数字和小数点的密码。",
    ),
    "disguise.changePassword.action": ("Change Password", "修改密码"),
    "disguise.passwordSetup.title": ("Password Sequence Setup", "密码序列设置"),
    "disguise.passwordSetup.warning": (
        "⚠️ Current password contains letters or special characters",
        "⚠️ 当前主密码包含字母或特殊字符",
    ),
    "disguise.passwordSetup.instruction1": (
        "Please set a new password with only numbers and decimal point",
        "请设置一个仅包含数字和小数点的新密码",
    ),
    "disguise.passwordSetup.instruction2": (
        "After changing, you'll need to reimport files (old files will be undecryptable)",
        "修改后，需要重新导入文件（旧文件将无法解密）",
    ),
    "disguise.passwordSetup.compatible": (
        "Current password meets disguise mode requirements",
        "当前主密码符合伪装模式要求",
    ),
    "disguise.passwordSetup.canUse": (
        "Can use directly or set to another numeric password",
        "可以直接使用，或设置为其他数字密码",
    ),
    "disguise.passwordSetup.rule1": (
        "Only supports numbers (0-9) and decimal point (.)",
        "仅支持数字 (0-9) 和小数点 (.)",
    ),
    "disguise.passwordSetup.rule2": ("Recommend 4-8 digits", "建议使用 4-8 位数字"),
    "disguise.example.title": ("Example Passwords", "示例密码"),
    "disguise.example.simple": ("Simple Numbers", "简单数字"),
    "disguise.example.sequential": ("Sequential Numbers", "连续数字"),
    "disguise.example.decimal": ("With Decimal Point", "带小数点"),
    "disguise.example.date": ("Date Numbers", "日期数字"),
    "disguise.confirmChange.title": ("Confirm Password Change", "确认修改密码"),
    "disguise.confirmChange.continue": ("Continue Change", "继续修改"),
    "disguise.confirmChange.message": (
        "After changing password, you'll need to use the new password for next login.\\n\\nEncrypted files will continue using the original key, no reencryption needed.",
        "修改主密码后，下次登录需要使用新密码。\\n\\n加密文件会继续使用最初设置的密钥，无需等待重新加密。",
    ),
    "disguise.updating": ("Updating password...", "正在更新密码..."),
    "disguise.error.numbersOnly": (
        "Password can only contain numbers and decimal point",
        "密码仅能包含数字和小数点",
    ),
    "disguise.error.minLength": (
        "Password must be at least 4 characters",
        "密码至少需要4位",
    ),
    "disguise.error.noPassword": (
        "Cannot get current password, please login again",
        "无法获取当前密码，请重新登录",
    ),
    "disguise.error.changeFailed": ("Password change failed: %@", "密码修改失败: %@"),
    "disguise.input.placeholder": ("Enter password sequence", "输入密码序列"),
    # File Preview (15 keys)
    "filePreview.exporting": ("Exporting...", "正在导出..."),
    "filePreview.decrypting": ("Decrypting file...", "正在解密文件..."),
    "filePreview.alert.title": ("Notice", "提示"),
    "filePreview.pdf.title": ("PDF Preview", "PDF 预览"),
    "filePreview.pdf.instruction": (
        "Tap share button to export and view",
        "点击分享按钮导出查看",
    ),
    "filePreview.loading": ("Loading...", "正在加载..."),
    "filePreview.text.error": ("Cannot display this text file", "无法显示此文本文件"),
    "filePreview.unsupported": (
        "Preview not supported for this file type",
        "暂不支持预览此文件类型",
    ),
    "filePreview.export": ("Export File", "导出文件"),
    "filePreview.error.noPassword": (
        "Cannot get password, please login and try again.",
        "无法获取密码，请重新登录后再试。",
    ),
    "filePreview.error.generic": (
        "Operation failed, please try again later.",
        "操作失败，请稍后重试。",
    ),
    # Gallery (15 keys)
    "gallery.title": ("ZeroNet Space", "零网络空间"),
    "gallery.search.placeholder": (
        "Search filename or extension",
        "搜索文件名或扩展名",
    ),
    "gallery.delete.title": ("Delete Media", "删除媒体"),
    "gallery.deleteConfirmation": (
        'Delete "%@"? This action cannot be undone.',
        '确定要删除"%@"吗？此操作无法撤销。',
    ),
    "gallery.empty.title": ("No Media Yet", "还没有媒体文件"),
    "gallery.empty.subtitle": (
        "Tap the + button in top right to import photos, videos or files",
        "点击右上角 + 按钮导入照片、视频或文件",
    ),
    "gallery.selectedCount": ("Selected %d items", "已选择 %d 项"),
    "gallery.move": ("Move", "移动"),
    "gallery.moveToFolder": ("Move to Folder", "移动到文件夹"),
    "gallery.addTags": ("Add Tags", "添加标签"),
    # Import (17 keys)
    "import.title": ("Import Media", "导入媒体"),
    "import.failed": ("Import Failed", "导入失败"),
    "import.saveToFolder": ("Save to Folder", "保存到文件夹"),
    "import.selectMethod.title": ("Select Import Method", "选择导入方式"),
    "import.selectMethod.subtitle": (
        "Imported files will be automatically encrypted",
        "导入的文件将被自动加密保护",
    ),
    "import.fromPhotos.title": ("From Photos", "从相册导入"),
    "import.fromPhotos.subtitle": ("Select photos and videos", "选择照片和视频"),
    "import.fromFiles.title": ("From Files", "从文件导入"),
    "import.fromFiles.subtitle": ("Select any files", "选择任意文件"),
    "import.stop": ("Stop Import", "停止导入"),
    "import.formats.title": ("Supported Formats:", "支持的格式："),
    "import.formats.photos": (
        "• Photos: JPG, PNG, HEIC, GIF, etc.",
        "• 照片: JPG, PNG, HEIC, GIF 等",
    ),
    "import.formats.videos": (
        "• Videos: MP4, MOV, M4V, etc.",
        "• 视频: MP4, MOV, M4V 等",
    ),
    "import.formats.documents": (
        "• Documents: PDF, DOC, TXT, all types",
        "• 文档: PDF, DOC, TXT 等所有类型",
    ),
    "import.success.title": ("Import Successful!", "导入成功！"),
    "import.success.count": ("Imported %d files", "已导入 %d 个文件"),
    "import.cloudNotice": (
        "Note: If you select files from iCloud Drive or other cloud storage that are 'cloud-only', iOS will briefly use network to download them and may prompt for cellular data usage. This is system behavior for downloading cloud files, not app-initiated network requests.",
        "提示：如果您从 iCloud Drive 或其他云盘中选择「仅保存在云端」的文件，iOS 系统会为下载该文件短暂使用网络，并可能弹出「是否允许使用无线数据」提示。这属于系统为帮您下载云端文件触发的网络行为，本应用自身不会主动发起任何网络请求。",
    ),
    # Network Verification (40+ keys)
    "network.verification.method": ("Verification Method", "验证方式"),
    "network.offline.title": ("Offline Verification", "离线验证"),
    "network.promises.title": ("Four Zero Promises", "四个「零」承诺"),
    "network.promise.zero.network": ("Zero Network", "零网络"),
    "network.promise.zero.network.desc": (
        "No network requests in code, no network permission",
        "代码中无任何网络请求，无网络权限",
    ),
    "network.promise.zero.upload": ("Zero Upload", "零上传"),
    "network.promise.zero.upload.desc": (
        "All data saved locally only, never uploaded to cloud",
        "所有数据仅保存本地，绝不上传云端",
    ),
    "network.promise.zero.tracking": ("Zero Tracking", "零追踪"),
    "network.promise.zero.tracking.desc": (
        "No analytics SDK, no ads SDK, no user tracking",
        "无统计SDK，无广告SDK，无用户行为追踪",
    ),
    "network.promise.zero.risk": ("Zero Risk", "零风险"),
    "network.promise.zero.risk.desc": (
        "No cloud = No leak risk",
        "没有云端 = 没有泄露风险",
    ),
    "network.permissions.requested": ("✅ Requested Permissions", "✅ 已请求权限"),
    "network.permission.photos": ("Photo Library Access", "照片库访问"),
    "network.permission.photos.purpose": (
        "Import photos and videos to encrypted space",
        "导入照片和视频到加密空间",
    ),
    "network.permissions.notRequested": (
        "❌ Explicitly NOT Requested",
        "❌ 明确不请求的权限",
    ),
    "network.permission.network": ("Network Access", "网络访问"),
    "network.permission.notNeeded": ("Not Needed", "完全不需要"),
    "network.permission.location": ("Location", "位置信息"),
    "network.permission.microphone": ("Microphone", "麦克风"),
    "network.permission.camera": ("Camera", "相机"),
    "network.permission.bluetooth": ("Bluetooth", "蓝牙"),
    "network.encryption.title": ("🔐 Local Encryption", "🔐 本地加密技术"),
    "network.encryption.algorithm": ("Algorithm", "加密算法"),
    "network.encryption.keyDerivation": ("Key Derivation", "密钥派生"),
    "network.encryption.pbkdf2": ("PBKDF2 (100k iterations)", "PBKDF2 (10万次迭代)"),
    "network.encryption.hash": ("Hash Algorithm", "哈希算法"),
    "network.encryption.keyStorage": ("Key Storage", "密钥存储"),
    "network.storage.title": ("💾 Data Storage", "💾 数据存储方式"),
    "network.storage.location": ("Storage Location", "存储位置"),
    "network.storage.sandbox": ("App Sandbox (Local)", "应用沙盒 (本地)"),
    "network.storage.database": ("Database", "数据库"),
    "network.storage.swiftdata": ("SwiftData (Local)", "SwiftData (本地)"),
    "network.storage.encryption": ("File Encryption", "文件加密"),
    "network.storage.encryption.yes": ("Yes (All Encrypted)", "是 (全部加密)"),
    "network.storage.cloudSync": ("Cloud Sync", "云端同步"),
    "network.storage.cloudSync.disabled": (
        "Disabled (iCloud Off)",
        "禁用 (iCloud关闭)",
    ),
    "network.code.guarantees.title": ("📝 Code-Level Guarantees", "📝 代码层面保证"),
    "network.code.noURLSession": (
        "No URLSession network code",
        "无任何URLSession网络请求代码",
    ),
    "network.code.noThirdPartySDK": (
        "No third-party network SDK",
        "无第三方网络SDK集成",
    ),
    "network.code.noAnalytics": (
        "No analytics SDK (e.g. Google Analytics)",
        "无统计分析SDK (如Google Analytics)",
    ),
    "network.code.noAds": ("No ads SDK", "无广告SDK"),
    "network.code.noCloudStorage": (
        "No cloud storage SDK (e.g. AWS S3)",
        "无云存储SDK (如AWS S3)",
    ),
    "network.code.noNetworkPermission": (
        "No network permission in Info.plist",
        "Info.plist中无网络权限声明",
    ),
    "network.dataFlow.import.title": ("📥 Data Import Flow", "📥 数据导入流程"),
    "network.dataFlow.selectFile": ("User Selects File", "用户选择文件"),
    "network.dataFlow.selectFromPhotos": (
        "Select photos/videos/files from library",
        "从相册选择照片/视频/文件",
    ),
    "network.cloudImportNotice": (
        "[Important] If you import files from iCloud Drive or other cloud storage 'cloud-only' locations, iOS system will briefly use network to download files and may prompt for cellular usage. This is system behavior for cloud file downloads, not app-initiated networking. The app itself has no network code.",
        "【重要说明】如果您从 iCloud Drive、云盘等「仅在云端」的位置导入文件，iOS 系统会为下载该文件短暂使用网络，并可能弹出「是否允许使用无线数据」提示。这是系统为云端文件下载触发的网络行为，不是应用在主动联网，本应用自身没有任何网络请求代码。",
    ),
    # Media Detail (20+ keys)
    "media.delete.title": ("Delete Media", "删除媒体"),
    "media.delete.confirmation": (
        "Delete this media? This action cannot be undone.",
        "确定要删除此媒体吗？此操作无法撤销。",
    ),
    "media.delete.failed": ("Delete failed: %@", "删除失败: %@"),
    "media.decrypting": ("Decrypting...", "正在解密..."),
    "media.loadFailed": ("Load Failed", "加载失败"),
    "media.fullscreen": ("Fullscreen", "全屏播放"),
    "media.preparing": ("Preparing document preview...", "正在准备文档预览..."),
    "media.readMode.original": ("Original", "原文"),
    "media.readMode.article": ("Article Mode", "文章模式"),
    "media.toc": ("Table of Contents", "目录"),
    "media.toc.title": ("Table of Contents", "目录"),
    "media.text.parseError": ("Cannot parse as text content.", "无法解析为文本内容。"),
    "media.error.noPassword": ("Cannot get password", "无法获取密码"),
    "media.error.fileNotFound": ("Encrypted file not found: %@", "加密文件不存在: %@"),
    "media.page.prefix": ("Page", "第"),
    "media.page.format": ("Page %d of %d", "第 %d/%d 页"),
    "media.chapter": ("Chapter", "章"),
    "media.section": ("Section", "节"),
    "media.chapter.alt": ("Episode", "回"),
    "media.article.generating": ("Generating article mode…", "正在生成文章模式…"),
    "media.pdf.extractFailed": (
        "Cannot extract text from this PDF.",
        "无法从此 PDF 中提取文本内容。",
    ),
    "media.generating": ("Generating...", "正在生成..."),
    "media.extractFailed": ("Extract Failed", "提取失败"),
    # Common Actions & States (20+ keys)
    "common.cancel": ("Cancel", "取消"),
    "common.ok": ("OK", "确定"),
    "common.confirm": ("Confirm", "确认"),
    "common.delete": ("Delete", "删除"),
    "common.done": ("Done", "完成"),
    "common.save": ("Save", "保存"),
    "common.edit": ("Edit", "编辑"),
    "common.create": ("Create", "创建"),
    "common.continue": ("Continue", "继续"),
    "common.close": ("Close", "关闭"),
    "common.select": ("Select", "选择"),
    "common.export": ("Export", "导出"),
    "common.share": ("Share", "分享"),
    "common.search": ("Search", "搜索"),
    "common.loading": ("Loading...", "加载中..."),
    "common.processing": ("Processing...", "正在处理..."),
    "common.importing.photos": ("Importing photos", "正在导入图片"),
    "common.error": ("Error", "错误"),
    "common.error.noPassword": (
        "Cannot get password, please login again",
        "无法获取密码，请重新登录",
    ),
}

# Add new keys to data
existing_count = len(data["strings"])
added_count = 0
skipped_count = 0

for key, (en_val, zh_val) in new_keys.items():
    if key not in data["strings"]:
        data["strings"][key] = create_string_entry(key, en_val, zh_val)
        added_count += 1
    else:
        skipped_count += 1
        print(f"⚠️  Skipped existing key: {key}")

# Save updated file
with open("Resources/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"\n✅ Localizable.xcstrings updated successfully!")
print(f"   Existing keys: {existing_count}")
print(f"   Added keys: {added_count}")
print(f"   Skipped (already exist): {skipped_count}")
print(f"   Total keys now: {len(data['strings'])}")
