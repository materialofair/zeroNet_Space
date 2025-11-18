# 本地化修复指南

## 问题诊断

### 当前状态
- ✅ Localizable.xcstrings 文件已创建 (278个双语键)
- ✅ InfoPlist.strings 文件已创建 (en.lproj 和 zh-Hans.lproj)
- ✅ 所有代码已使用 String(localized:) API
- ✅ zh-Hans 已添加到项目的 knownRegions
- ❌ **Localizable.xcstrings 未添加到 Xcode 项目中** ← 根本原因

### 问题表现
- 运行时显示 "photos.title" 而不是 "Photos" 或 "相片"
- String(localized:) 无法找到本地化字符串
- 因为 Xcode 没有将 .xcstrings 文件编译到 app bundle 中

---

## 修复步骤（必须在 Xcode 中操作）

### Step 1: 添加 Localizable.xcstrings 到项目

1. **打开 Xcode**
   ```
   在 Finder 中双击打开：
   ZeroNet-Space.xcodeproj
   ```

2. **添加文件到项目**
   - 在 Xcode 左侧项目导航器中，右键点击 "ZeroNet-Space" 根目录
   - 选择 "Add Files to 'ZeroNet-Space'..."
   - 导航到 `Resources/Localizable.xcstrings`
   - **重要**: 勾选以下选项：
     - ✅ "Copy items if needed" (不要勾选，文件已在正确位置)
     - ✅ "Create groups" (选择这个，不是 "Create folder references")
     - ✅ "Add to targets: ZeroNet-Space" (确保勾选主 target)
   - 点击 "Add"

3. **验证文件已添加**
   - 在项目导航器中应该能看到 Localizable.xcstrings
   - 点击该文件，右侧检查器面板应显示：
     - Target Membership: ✅ ZeroNet-Space
     - Localization: English, Chinese (Simplified)

### Step 2: 配置项目本地化

1. **打开项目设置**
   - 在项目导航器中点击最上面的 "ZeroNet-Space" 项目（蓝色图标）
   - 选择 "ZeroNet-Space" project（不是 target）
   - 切换到 "Info" 标签

2. **添加 Simplified Chinese**
   - 在 "Localizations" 部分
   - 当前应该只有 "English - Development Language"
   - 点击 "+" 按钮
   - 选择 "Chinese, Simplified (zh-Hans)"
   - 在弹出的对话框中，确保勾选：
     - ✅ Localizable.xcstrings
     - ✅ InfoPlist.strings
   - 点击 "Finish"

3. **验证本地化设置**
   - "Localizations" 列表应该显示：
     - English - Development Language (1 file localized)
     - Chinese, Simplified (1 file localized)

### Step 3: 验证 Build Phases

1. **选择 ZeroNet-Space target**
   - 在项目设置中，切换到 "ZeroNet-Space" target
   - 切换到 "Build Phases" 标签

2. **检查 Copy Bundle Resources**
   - 展开 "Copy Bundle Resources" 部分
   - 确认列表中包含：
     - ✅ Localizable.xcstrings
     - ✅ InfoPlist.strings (可能显示为 en.lproj 和 zh-Hans.lproj)

3. **如果缺失，手动添加**
   - 点击 "+" 按钮
   - 搜索并添加 Localizable.xcstrings

### Step 4: 清理并重新构建

1. **清理构建缓存**
   ```
   菜单栏: Product > Clean Build Folder
   或快捷键: Shift + Cmd + K
   ```

2. **重新构建项目**
   ```
   菜单栏: Product > Build
   或快捷键: Cmd + B
   ```

3. **运行应用**
   ```
   菜单栏: Product > Run
   或快捷键: Cmd + R
   ```

### Step 5: 测试本地化

1. **测试英文**
   - 在模拟器中打开 Settings > General > Language & Region
   - 确保 "iPhone Language" 是 "English"
   - 重新打开 ZeroNet Space app
   - 应该显示 "Photos", "Videos", "Files" 等英文文本

2. **测试简体中文**
   - 在模拟器中打开 Settings > General > Language & Region
   - 点击 "iPhone Language"
   - 选择 "简体中文"
   - 点击 "Continue" 确认更改
   - 重新打开 ZeroNet Space app
   - 应该显示 "相片", "视频", "文件" 等中文文本

---

## 验证清单

完成上述步骤后，验证以下内容：

### Xcode 项目结构
- [ ] Localizable.xcstrings 在项目导航器中可见
- [ ] 文件的 Target Membership 包含 ZeroNet-Space
- [ ] 项目 Info 中的 Localizations 包含 English 和 Chinese, Simplified
- [ ] Build Phases > Copy Bundle Resources 包含 Localizable.xcstrings

### 运行时验证
- [ ] 英文环境下，所有界面显示英文（不是 key 名称）
- [ ] 中文环境下，所有界面显示中文（不是 key 名称）
- [ ] 导航标题正确本地化
- [ ] 按钮文本正确本地化
- [ ] Alert 和错误消息正确本地化

### 应用元数据
- [ ] 英文环境下，主屏幕显示 "ZeroNet Space"
- [ ] 中文环境下，主屏幕显示 "零网空间"
- [ ] 权限请求对话框显示正确的本地化文本

---

## 常见问题排查

### Q1: 仍然显示 key 名称（如 "photos.title"）

**可能原因**:
1. Localizable.xcstrings 未添加到项目
2. 文件未包含在 Copy Bundle Resources
3. Build 缓存未清理

**解决方案**:
1. 确认 Step 1-3 全部正确执行
2. Clean Build Folder (Shift + Cmd + K)
3. 删除 app 并重新安装

### Q2: 部分文本本地化，部分显示 key

**可能原因**:
1. Localizable.xcstrings 中缺少某些 key
2. 代码中使用的 key 名称与 .xcstrings 中不匹配

**解决方案**:
1. 打开 Localizable.xcstrings，搜索缺失的 key
2. 检查代码中的 String(localized: "...") 是否与文件中的 key 一致

### Q3: 语言切换后没有变化

**可能原因**:
1. App 需要完全重启
2. 缓存问题

**解决方案**:
1. 完全关闭 app（从多任务界面滑掉）
2. 重新打开 app
3. 如果仍然不行，删除 app 并重新安装

### Q4: Xcode 中看不到本地化选项

**可能原因**:
1. 文件添加时没有勾选正确的选项
2. 文件类型未被识别为可本地化资源

**解决方案**:
1. 删除文件从项目（仅删除引用，不删除文件）
2. 重新按照 Step 1 添加，确保勾选正确选项
3. 确保文件扩展名是 .xcstrings（不是 .json）

---

## 自动化验证脚本

创建了一个验证脚本，但**无法替代在 Xcode 中的手动操作**：

```bash
# 验证文件是否在项目中
cd /Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space
if grep -q "Localizable.xcstrings" ZeroNet-Space.xcodeproj/project.pbxproj; then
    echo "✅ Localizable.xcstrings 已在项目中"
else
    echo "❌ Localizable.xcstrings 未在项目中 - 需要在 Xcode 中添加"
fi

# 验证 zh-Hans 在 knownRegions 中
if grep -q "zh-Hans" ZeroNet-Space.xcodeproj/project.pbxproj; then
    echo "✅ zh-Hans 已在 knownRegions 中"
else
    echo "❌ zh-Hans 未在 knownRegions 中"
fi
```

---

## 完成后的最终验证

完成所有步骤后，运行以下命令验证 app bundle：

```bash
# 构建项目
cd /Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/ZeroNet_Space
xcodebuild -project ZeroNet-Space.xcodeproj -scheme ZeroNet-Space -sdk iphonesimulator build

# 查找构建产物
find ~/Library/Developer/Xcode/DerivedData -name "ZeroNet-Space.app" -type d -maxdepth 5

# 检查 app bundle 中的本地化资源
# 替换下面的路径为实际的 .app 路径
ls -la "路径/ZeroNet-Space.app/en.lproj/"
ls -la "路径/ZeroNet-Space.app/zh-Hans.lproj/"
```

应该看到：
- `en.lproj/Localizable.strings` 或 `Localizable.stringsdict`
- `zh-Hans.lproj/Localizable.strings` 或 `Localizable.stringsdict`
- `en.lproj/InfoPlist.strings`
- `zh-Hans.lproj/InfoPlist.strings`

---

## 总结

**核心问题**: Localizable.xcstrings 文件虽然创建了，但没有添加到 Xcode 项目中，导致编译时不会被包含在 app bundle 中。

**必须操作**: 在 Xcode 中手动添加文件到项目，并配置本地化设置。

**无法自动化**: Xcode 项目文件 (.pbxproj) 是二进制格式的 plist，手动编辑容易损坏，必须通过 Xcode UI 操作。

完成这些步骤后，本地化应该能够正常工作！

---

**创建日期**: 2025年1月16日  
**状态**: 等待用户在 Xcode 中完成配置
