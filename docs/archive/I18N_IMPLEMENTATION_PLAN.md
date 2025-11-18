# iOS App Internationalization - Complete Implementation Plan

## Executive Summary

**Goal**: Complete internationalization of iOS app by adding ~150 missing localization keys and updating 24 view files to use `String(localized:)` instead of hardcoded Chinese strings.

**Current State**: 
- Localizable.xcstrings has ~60 keys
- 590 hardcoded Chinese strings found across 24 view files
- 13 view files already partially internationalized

**Target State**:
- Localizable.xcstrings with ~210 comprehensive keys
- All 24 view files using String(localized:) exclusively
- Zero hardcoded Chinese strings remaining
- Full English + Simplified Chinese localization

**Estimated Time**: 2-3 hours
**Risk Level**: Low (cosmetic changes, no logic modification)

---

## Phase 1: Generate Comprehensive Localization Keys (30 mins)

### Step 1.1: Create Key Generation Script
**File**: `generate_localization_keys.py`

**Action**: Create Python script to:
1. Parse all Swift files for Chinese strings
2. Categorize by module (export, folders, tags, etc.)
3. Generate semantic key names
4. Create JSON mapping file

**Verification**: Script outputs `localization_keys.json` with ~150 new keys

### Step 1.2: Define Key Naming Convention
**Convention**:
```
{module}.{submodule}.{purpose}

Examples:
export.title                    → "批量导出"
export.selectedCount            → "已选择 %d 项"
folders.select.title            → "选择文件夹"
disguise.enable.description     → "启用后，应用启动时..."
common.cancel                   → "取消"
```

**Verification**: All keys follow consistent naming pattern

---

## Phase 2: Update Localizable.xcstrings (45 mins)

### Step 2.1: Backup Current File
**Action**: 
```bash
cp Resources/Localizable.xcstrings Resources/Localizable.xcstrings.backup
```

**Verification**: Backup file exists

### Step 2.2: Add Missing Keys by Category

**File**: `Resources/Localizable.xcstrings`

**Categories to Add**:

#### A. Export Module (20 keys)
```json
"export.title": "批量导出" / "Batch Export"
"export.selectedCount": "已选择 %d 项" / "Selected %d items"
"export.selectAll": "全选" / "Select All"
"export.deselectAll": "取消全选" / "Deselect All"
"export.exportSelected": "导出选中项" / "Export Selected"
"export.clear": "清空" / "Clear"
"export.failed": "导出失败" / "Export Failed"
"export.inProgress": "正在导出..." / "Exporting..."
"export.decrypting": "正在解密并准备文件，请稍候..." / "Decrypting and preparing files, please wait..."
"export.decryptingProgress": "正在解密第 %d/%d 个文件" / "Decrypting file %d of %d"
"export.preparingShare": "正在准备分享..." / "Preparing to share..."
"export.empty.title": "没有可导出的文件" / "No files to export"
"export.empty.subtitle": "请先导入一些文件" / "Please import some files first"
```

#### B. Folders Module (25 keys)
```json
"folders.title": "文件夹" / "Folders"
"folders.select.title": "选择文件夹" / "Select Folder"
"folders.selectTarget.title": "选择目标文件夹" / "Select Target Folder"
"folders.new.title": "新建文件夹" / "New Folder"
"folders.edit.title": "编辑文件夹" / "Edit Folder"
"folders.allMedia": "所有媒体" / "All Media"
"folders.allMedia.default": "所有媒体（默认）" / "All Media (Default)"
"folders.allMedia.remove": "所有媒体（移除文件夹）" / "All Media (Remove from Folder)"
"folders.system": "系统文件夹" / "System Folders"
"folders.custom": "自定义文件夹" / "Custom Folders"
"folders.name.placeholder": "文件夹名称" / "Folder Name"
"folders.itemCount": "%d 个项目" / "%d items"
"folders.selectIcon": "选择图标" / "Select Icon"
"folders.selectColor": "选择颜色" / "Select Color"
"folders.basicInfo": "基本信息" / "Basic Info"
"folders.preview": "预览" / "Preview"
"folders.empty.title": "文件夹是空的" / "Folder is Empty"
"folders.empty.subtitle": "将媒体文件移动到此文件夹" / "Move media files to this folder"
```

#### C. Tags Module (15 keys)
```json
"tags.title": "标签" / "Tags"
"tags.management.title": "标签管理" / "Tag Management"
"tags.add.title": "添加标签" / "Add Tags"
"tags.select.title": "选择标签" / "Select Tags"
"tags.create.title": "创建新标签" / "Create New Tag"
"tags.name.placeholder": "标签名称" / "Tag Name"
"tags.empty": "还没有标签" / "No tags yet"
"tags.usageCount": "%d 次使用" / "%d uses"
"tags.inputPrompt": "输入新标签的名称" / "Enter new tag name"
```

#### D. Disguise Mode (40 keys)
```json
"disguise.title": "伪装模式" / "Disguise Mode"
"disguise.enable.title": "启用伪装模式" / "Enable Disguise Mode"
"disguise.enable.description": "启用后，应用启动时将显示计算器界面而非登录界面" / "When enabled, the app will launch with calculator interface instead of login screen"
"disguise.calculator.title": "伪装计算器" / "Disguise Calculator"
"disguise.passwordSequence": "密码序列" / "Password Sequence"
"disguise.setPassword.title": "设置密码序列" / "Set Password Sequence"
"disguise.useDefault": "使用默认密码" / "Use Default Password"
"disguise.isSet": "已设置" / "Set"
"disguise.unlockPassword": "解锁密码" / "Unlock Password"
"disguise.instructions.title": "使用说明" / "Instructions"
"disguise.instructions.howTo": "在计算器中输入此数字序列后按 = 号即可解锁应用" / "Enter this number sequence in calculator and press = to unlock"
"disguise.instructions.example": "示例: 输入 1234.56 再按 =" / "Example: Enter 1234.56 then press ="
"disguise.warning.defaultPassword": "⚠️ 当前使用默认密码 1234，建议设置自定义密码" / "⚠️ Currently using default password 1234, custom password recommended"
"disguise.tip.calculator": "计算器完全可用，可进行正常计算" / "Calculator is fully functional for normal calculations"
"disguise.tip.numbersOnly": "密码序列仅支持数字和小数点" / "Password sequence supports only numbers and decimal point"
"disguise.tip.noDisplay": "密码序列不会显示在计算结果中" / "Password sequence won't appear in calculation results"
"disguise.tip.noFeedback": "密码错误时不会有任何提示（伪装特性）" / "No feedback for wrong password (disguise feature)"
"disguise.security.title": "伪装模式安全提示" / "Disguise Mode Security Tips"
"disguise.security.tips": "• 计算器界面完全真实，无法被识破\\n• 不会保留任何计算历史记录\\n• 请牢记您的密码序列" / "• Calculator interface is fully realistic and undetectable\\n• No calculation history is retained\\n• Please memorize your password sequence"
"disguise.changePassword.required.title": "需要修改主密码" / "Password Change Required"
"disguise.changePassword.required.message": "伪装模式要求主密码仅包含数字和小数点。\\n\\n当前主密码包含字母或特殊字符，请修改为仅包含数字和小数点的密码。" / "Disguise mode requires main password to contain only numbers and decimal point.\\n\\nCurrent password contains letters or special characters. Please change to numbers and decimal point only."
"disguise.changePassword.action": "修改密码" / "Change Password"
"disguise.passwordSetup.title": "密码序列设置" / "Password Sequence Setup"
"disguise.passwordSetup.warning": "⚠️ 当前主密码包含字母或特殊字符" / "⚠️ Current password contains letters or special characters"
"disguise.passwordSetup.instruction1": "请设置一个仅包含数字和小数点的新密码" / "Please set a new password with only numbers and decimal point"
"disguise.passwordSetup.instruction2": "修改后，需要重新导入文件（旧文件将无法解密）" / "After changing, you'll need to reimport files (old files will be undecryptable)"
"disguise.passwordSetup.compatible": "当前主密码符合伪装模式要求" / "Current password meets disguise mode requirements"
"disguise.passwordSetup.canUse": "可以直接使用，或设置为其他数字密码" / "Can use directly or set to another numeric password"
"disguise.passwordSetup.rule1": "仅支持数字 (0-9) 和小数点 (.)" / "Only supports numbers (0-9) and decimal point (.)"
"disguise.passwordSetup.rule2": "建议使用 4-8 位数字" / "Recommend 4-8 digits"
"disguise.example.title": "示例密码" / "Example Passwords"
"disguise.example.simple": "简单数字" / "Simple Numbers"
"disguise.example.sequential": "连续数字" / "Sequential Numbers"
"disguise.example.decimal": "带小数点" / "With Decimal Point"
"disguise.example.date": "日期数字" / "Date Numbers"
"disguise.confirmChange.title": "确认修改密码" / "Confirm Password Change"
"disguise.confirmChange.continue": "继续修改" / "Continue Change"
"disguise.confirmChange.message": "修改主密码后，下次登录需要使用新密码。\\n\\n加密文件会继续使用最初设置的密钥，无需等待重新加密。" / "After changing password, you'll need to use the new password for next login.\\n\\nEncrypted files will continue using the original key, no reencryption needed."
"disguise.updating": "正在更新密码..." / "Updating password..."
"disguise.error.numbersOnly": "密码仅能包含数字和小数点" / "Password can only contain numbers and decimal point"
"disguise.error.minLength": "密码至少需要4位" / "Password must be at least 4 characters"
"disguise.error.noPassword": "无法获取当前密码，请重新登录" / "Cannot get current password, please login again"
"disguise.error.changeFailed": "密码修改失败: %@" / "Password change failed: %@"
"disguise.input.placeholder": "输入密码序列" / "Enter password sequence"
```

#### E. File Preview (15 keys)
```json
"filePreview.exporting": "正在导出..." / "Exporting..."
"filePreview.decrypting": "正在解密文件..." / "Decrypting file..."
"filePreview.alert.title": "提示" / "Notice"
"filePreview.pdf.title": "PDF 预览" / "PDF Preview"
"filePreview.pdf.instruction": "点击分享按钮导出查看" / "Tap share button to export and view"
"filePreview.loading": "正在加载..." / "Loading..."
"filePreview.text.error": "无法显示此文本文件" / "Cannot display this text file"
"filePreview.unsupported": "暂不支持预览此文件类型" / "Preview not supported for this file type"
"filePreview.export": "导出文件" / "Export File"
"filePreview.error.noPassword": "无法获取密码，请重新登录后再试。" / "Cannot get password, please login and try again."
"filePreview.error.generic": "操作失败，请稍后重试。" / "Operation failed, please try again later."
```

#### F. Gallery (15 keys)
```json
"gallery.title": "零网络空间" / "ZeroNet Space"
"gallery.search.placeholder": "搜索文件名或扩展名" / "Search filename or extension"
"gallery.delete.title": "删除媒体" / "Delete Media"
"gallery.deleteConfirmation": "确定要删除\"%@\"吗？此操作无法撤销。" / "Delete \"%@\"? This action cannot be undone."
"gallery.empty.title": "还没有媒体文件" / "No Media Yet"
"gallery.empty.subtitle": "点击右上角 + 按钮导入照片、视频或文件" / "Tap the + button in top right to import photos, videos or files"
"gallery.selectedCount": "已选择 %d 项" / "Selected %d items"
"gallery.move": "移动" / "Move"
"gallery.moveToFolder": "移动到文件夹" / "Move to Folder"
"gallery.addTags": "添加标签" / "Add Tags"
```

#### G. Import (15 keys)
```json
"import.title": "导入媒体" / "Import Media"
"import.failed": "导入失败" / "Import Failed"
"import.saveToFolder": "保存到文件夹" / "Save to Folder"
"import.selectMethod.title": "选择导入方式" / "Select Import Method"
"import.selectMethod.subtitle": "导入的文件将被自动加密保护" / "Imported files will be automatically encrypted"
"import.fromPhotos.title": "从相册导入" / "From Photos"
"import.fromPhotos.subtitle": "选择照片和视频" / "Select photos and videos"
"import.fromFiles.title": "从文件导入" / "From Files"
"import.fromFiles.subtitle": "选择任意文件" / "Select any files"
"import.stop": "停止导入" / "Stop Import"
"import.formats.title": "支持的格式：" / "Supported Formats:"
"import.formats.photos": "• 照片: JPG, PNG, HEIC, GIF 等" / "• Photos: JPG, PNG, HEIC, GIF, etc."
"import.formats.videos": "• 视频: MP4, MOV, M4V 等" / "• Videos: MP4, MOV, M4V, etc."
"import.formats.documents": "• 文档: PDF, DOC, TXT 等所有类型" / "• Documents: PDF, DOC, TXT, all types"
"import.success.title": "导入成功！" / "Import Successful!"
"import.success.count": "已导入 %d 个文件" / "Imported %d files"
"import.cloudNotice": "提示：如果您从 iCloud Drive 或其他云盘中选择「仅保存在云端」的文件，iOS 系统会为下载该文件短暂使用网络，并可能弹出「是否允许使用无线数据」提示。这属于系统为帮您下载云端文件触发的网络行为，本应用自身不会主动发起任何网络请求。" / "Note: If you select files from iCloud Drive or other cloud storage that are 'cloud-only', iOS will briefly use network to download them and may prompt for cellular data usage. This is system behavior for downloading cloud files, not app-initiated network requests."
```

#### H. Network Verification (30 keys)
```json
"network.verification.method": "验证方式" / "Verification Method"
"network.offline.title": "离线验证" / "Offline Verification"
"network.promises.title": "四个「零」承诺" / "Four Zero Promises"
"network.promise.zero.network": "零网络" / "Zero Network"
"network.promise.zero.network.desc": "代码中无任何网络请求，无网络权限" / "No network requests in code, no network permission"
"network.promise.zero.upload": "零上传" / "Zero Upload"
"network.promise.zero.upload.desc": "所有数据仅保存本地，绝不上传云端" / "All data saved locally only, never uploaded to cloud"
"network.promise.zero.tracking": "零追踪" / "Zero Tracking"
"network.promise.zero.tracking.desc": "无统计SDK，无广告SDK，无用户行为追踪" / "No analytics SDK, no ads SDK, no user tracking"
"network.promise.zero.risk": "零风险" / "Zero Risk"
"network.promise.zero.risk.desc": "没有云端 = 没有泄露风险" / "No cloud = No leak risk"
"network.permissions.requested": "✅ 已请求权限" / "✅ Requested Permissions"
"network.permission.photos": "照片库访问" / "Photo Library Access"
"network.permission.photos.purpose": "导入照片和视频到加密空间" / "Import photos and videos to encrypted space"
"network.permissions.notRequested": "❌ 明确不请求的权限" / "❌ Explicitly NOT Requested"
"network.permission.network": "网络访问" / "Network Access"
"network.permission.notNeeded": "完全不需要" / "Not Needed"
"network.permission.location": "位置信息" / "Location"
"network.permission.microphone": "麦克风" / "Microphone"
"network.permission.camera": "相机" / "Camera"
"network.permission.bluetooth": "蓝牙" / "Bluetooth"
"network.encryption.title": "🔐 本地加密技术" / "🔐 Local Encryption"
"network.encryption.algorithm": "加密算法" / "Algorithm"
"network.encryption.keyDerivation": "密钥派生" / "Key Derivation"
"network.encryption.pbkdf2": "PBKDF2 (10万次迭代)" / "PBKDF2 (100k iterations)"
"network.encryption.hash": "哈希算法" / "Hash Algorithm"
"network.encryption.keyStorage": "密钥存储" / "Key Storage"
"network.storage.title": "💾 数据存储方式" / "💾 Data Storage"
"network.storage.location": "存储位置" / "Storage Location"
"network.storage.sandbox": "应用沙盒 (本地)" / "App Sandbox (Local)"
"network.storage.database": "数据库" / "Database"
"network.storage.swiftdata": "SwiftData (本地)" / "SwiftData (Local)"
"network.storage.encryption": "文件加密" / "File Encryption"
"network.storage.encryption.yes": "是 (全部加密)" / "Yes (All Encrypted)"
"network.storage.cloudSync": "云端同步" / "Cloud Sync"
"network.storage.cloudSync.disabled": "禁用 (iCloud关闭)" / "Disabled (iCloud Off)"
"network.code.guarantees.title": "📝 代码层面保证" / "📝 Code-Level Guarantees"
"network.code.noURLSession": "无任何URLSession网络请求代码" / "No URLSession network code"
"network.code.noThirdPartySDK": "无第三方网络SDK集成" / "No third-party network SDK"
"network.code.noAnalytics": "无统计分析SDK (如Google Analytics)" / "No analytics SDK (e.g. Google Analytics)"
"network.code.noAds": "无广告SDK" / "No ads SDK"
"network.code.noCloudStorage": "无云存储SDK (如AWS S3)" / "No cloud storage SDK (e.g. AWS S3)"
"network.code.noNetworkPermission": "Info.plist中无网络权限声明" / "No network permission in Info.plist"
"network.dataFlow.import.title": "📥 数据导入流程" / "📥 Data Import Flow"
"network.dataFlow.selectFile": "用户选择文件" / "User Selects File"
"network.dataFlow.selectFromPhotos": "从相册选择照片/视频/文件" / "Select photos/videos/files from library"
"network.cloudImportNotice": "【重要说明】如果您从 iCloud Drive、云盘等「仅在云端」的位置导入文件，iOS 系统会为下载该文件短暂使用网络，并可能弹出「是否允许使用无线数据」提示。这是系统为云端文件下载触发的网络行为，不是应用在主动联网，本应用自身没有任何网络请求代码。" / "[Important] If you import files from iCloud Drive or other cloud storage 'cloud-only' locations, iOS system will briefly use network to download files and may prompt for cellular usage. This is system behavior for cloud file downloads, not app-initiated networking. The app itself has no network code."
```

#### I. Media Detail (20 keys)
```json
"media.delete.title": "删除媒体" / "Delete Media"
"media.delete.confirmation": "确定要删除此媒体吗？此操作无法撤销。" / "Delete this media? This action cannot be undone."
"media.delete.failed": "删除失败: %@" / "Delete failed: %@"
"media.decrypting": "正在解密..." / "Decrypting..."
"media.loadFailed": "加载失败" / "Load Failed"
"media.fullscreen": "全屏播放" / "Fullscreen"
"media.preparing": "正在准备文档预览..." / "Preparing document preview..."
"media.readMode.original": "原文" / "Original"
"media.readMode.article": "文章模式" / "Article Mode"
"media.toc": "目录" / "Table of Contents"
"media.toc.title": "目录" / "Table of Contents"
"media.text.parseError": "无法解析为文本内容。" / "Cannot parse as text content."
"media.error.noPassword": "无法获取密码" / "Cannot get password"
"media.error.fileNotFound": "加密文件不存在: %@" / "Encrypted file not found: %@"
"media.page.prefix": "第" / "Page"
"media.page.format": "第 %d/%d 页" / "Page %d of %d"
"media.chapter": "章" / "Chapter"
"media.section": "节" / "Section"
"media.chapter.alt": "回" / "Episode"
"media.article.generating": "正在生成文章模式…" / "Generating article mode…"
"media.pdf.extractFailed": "无法从此 PDF 中提取文本内容。" / "Cannot extract text from this PDF."
```

#### J. Common Actions & States (10 keys)
```json
"common.cancel": "取消" / "Cancel"
"common.ok": "确定" / "OK"
"common.confirm": "确认" / "Confirm"
"common.delete": "删除" / "Delete"
"common.done": "完成" / "Done"
"common.save": "保存" / "Save"
"common.edit": "编辑" / "Edit"
"common.create": "创建" / "Create"
"common.continue": "继续" / "Continue"
"common.close": "关闭" / "Close"
"common.select": "选择" / "Select"
"common.export": "导出" / "Export"
"common.share": "分享" / "Share"
"common.search": "搜索" / "Search"
"common.loading": "加载中..." / "Loading..."
"common.processing": "正在处理..." / "Processing..."
"common.importing.photos": "正在导入图片" / "Importing photos"
"common.error": "错误" / "Error"
"common.error.noPassword": "无法获取密码，请重新登录" / "Cannot get password, please login again"
```

**Verification**: All 150+ keys added to Localizable.xcstrings with both English and Chinese translations

---

## Phase 3: Update View Files (60 mins)

### Step 3.1: Create Batch Replacement Script

**File**: `replace_hardcoded_strings.py`

**Action**: Create Python script to:
1. Read each Swift file
2. Find hardcoded Chinese strings
3. Match to localization key from mapping
4. Replace with `String(localized: "key")`
5. Handle format strings with parameters
6. Preserve code structure and indentation

**Patterns to Handle**:
```swift
// Pattern 1: Simple string
"设置" → String(localized: "settings.title")

// Pattern 2: Dynamic string with interpolation
"已选择 \(count) 项" → String(localized: "gallery.selectedCount", defaultValue: "Selected \(count) items")

// Pattern 3: Multi-line string
"这是\\n多行" → String(localized: "key", defaultValue: "This is\\nMulti-line")

// Pattern 4: In navigationTitle
.navigationTitle("设置") → .navigationTitle(String(localized: "settings.title"))

// Pattern 5: In Button/Text
Button("确定") → Button(String(localized: "common.ok"))
Text("加载中...") → Text(String(localized: "common.loading"))
```

**Verification**: Script generates diff preview for each file

### Step 3.2: Update Files Systematically

**Process Each File**:

1. **BatchExportView.swift** (~17 strings)
   - navigationTitle, button labels, alerts, status text
   - Handle dynamic count strings

2. **BatchFolderSelectionView.swift** (~4 strings)
   - Section headers, button labels

3. **BatchTagSelectionView.swift** (~11 strings)
   - Section headers, alerts, text fields

4. **DisguiseSettingsView.swift** (~57 strings) ⚠️ LARGEST
   - Toggle labels, instructions, examples, alerts
   - Handle multi-line strings carefully

5. **FilePreviewView.swift** (~13 strings)
   - Button labels, status text, error messages

6. **FilesView.swift** (~3 strings)
   - navigationTitle, search prompt

7. **FolderListView.swift** (~19 strings)
   - Section headers, text fields, labels

8. **FolderSelectionView.swift** (~3 strings)
   - navigationTitle, labels

9. **GalleryView.swift** (~20 strings)
   - navigationTitle, alerts, empty state, actions

10. **ImportButtonsView.swift** (~18 strings)
    - navigationTitle, labels, descriptions

11. **LoadingOverlay.swift** (~3 strings)
    - Default loading messages

12. **MediaDetailView.swift** (~50 strings) ⚠️ COMPLEX
    - Video player, PDF viewer, document viewer
    - Handle dynamic page numbers

13. **NetworkVerificationView.swift** (~42 strings)
    - Verification details, permissions, guarantees
    - Long multi-line descriptions

14. **GridItemView.swift** (~0 strings already done)

15. **TagManagementView.swift** (~similar to BatchTagSelectionView)

16. **VideoPlayerView.swift** (check for any)

17. **VideosView.swift** (check for any)

18. **PhotosView.swift** (check for any)

19. **SecretSpaceView.swift** (check for any)

20. **SecondPasswordSettingsView.swift** (check for any)

21. **NoteEditorView.swift** (check for any)

22. **CalculatorView.swift** (check for any)

23. **SetupPasswordView.swift** (check for any)

24. **LaunchScreenView.swift** (check for any)

**Verification for Each File**:
- Compile successfully
- No hardcoded Chinese strings remain
- All String(localized:) calls use valid keys
- UI displays correctly in both English and Chinese

---

## Phase 4: Build & Verification (15 mins)

### Step 4.1: Clean Build
```bash
cd /Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space
xcodebuild clean -project ZeroNet-Space.xcodeproj -scheme ZeroNet-Space
```

**Verification**: Clean completes without errors

### Step 4.2: Full Build
```bash
xcodebuild build -project ZeroNet-Space.xcodeproj -scheme ZeroNet-Space
```

**Verification**: Build succeeds with 0 errors, 0 warnings

### Step 4.3: Language Switching Test

**Manual Test**:
1. Change device language to English
2. Launch app
3. Verify all screens show English text
4. Change device language to Chinese
5. Verify all screens show Chinese text
6. Check for any missing translations (shows key names instead)

**Verification**: All UI elements display correct language

### Step 4.4: Search for Remaining Chinese Strings
```bash
python3 find_chinese.py
```

**Verification**: Output shows 0 hardcoded Chinese strings

---

## Phase 5: Documentation & Cleanup (10 mins)

### Step 5.1: Create Completion Report

**File**: `I18N_COMPLETION_REPORT.md`

**Content**:
- Total keys added
- Files modified
- Before/after statistics
- Testing results
- Known issues (if any)

### Step 5.2: Remove Temporary Scripts

**Action**: Remove or archive:
- `find_chinese.py`
- `generate_localization_keys.py`
- `replace_hardcoded_strings.py`
- `i18n_keys_generated.json`

### Step 5.3: Commit Changes

```bash
git add Resources/Localizable.xcstrings
git add ZeroNet-Space/Views/**/*.swift
git commit -m "Complete iOS app internationalization

- Added 150+ localization keys to Localizable.xcstrings
- Updated 24 view files to use String(localized:)
- Removed all hardcoded Chinese strings
- Full English + Simplified Chinese support

Categories added:
- Export (20 keys)
- Folders (25 keys)
- Tags (15 keys)
- Disguise mode (40 keys)
- File preview (15 keys)
- Gallery (15 keys)
- Import (15 keys)
- Network verification (30 keys)
- Media detail (20 keys)
- Common actions (10 keys)"
```

**Verification**: Commit includes all modified files

---

## Risk Assessment

### Low Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Missing key causes crash | Low | Medium | Use `defaultValue` parameter in all String(localized:) calls |
| Translation quality poor | Low | Low | Review all English translations before commit |
| Build breaks | Very Low | High | Test build after each major file update |
| String interpolation breaks | Low | Medium | Test all dynamic strings with various inputs |

### Rollback Procedure

**If issues found**:
1. Revert to backup: `cp Resources/Localizable.xcstrings.backup Resources/Localizable.xcstrings`
2. Revert Swift files: `git checkout -- ZeroNet-Space/Views/`
3. Clean build: `xcodebuild clean`
4. Rebuild: `xcodebuild build`

**Verification**: App runs with original hardcoded strings

---

## Success Criteria

✅ **Functional**:
- [ ] App builds without errors
- [ ] All screens display in English when language is English
- [ ] All screens display in Chinese when language is Chinese
- [ ] No crashes related to missing keys
- [ ] All dynamic strings format correctly

✅ **Code Quality**:
- [ ] Zero hardcoded Chinese strings remain
- [ ] All localization keys follow naming convention
- [ ] Localizable.xcstrings has ~210 total keys
- [ ] All 24 view files use String(localized:) exclusively

✅ **User Experience**:
- [ ] Text displays correctly in both languages
- [ ] No layout breaking due to text length differences
- [ ] All buttons, labels, alerts properly translated

---

## Time Estimates

| Phase | Duration |
|-------|----------|
| Phase 1: Key Generation | 30 mins |
| Phase 2: Update Localizable.xcstrings | 45 mins |
| Phase 3: Update View Files | 60 mins |
| Phase 4: Build & Verification | 15 mins |
| Phase 5: Documentation & Cleanup | 10 mins |
| **Total** | **~2.5 hours** |

---

## Next Steps

After plan approval:
1. Execute Phase 1 to generate comprehensive key mapping
2. Update Localizable.xcstrings with all new keys
3. Systematically update each view file
4. Build and test language switching
5. Commit and document completion

**Ready to proceed with implementation?**
