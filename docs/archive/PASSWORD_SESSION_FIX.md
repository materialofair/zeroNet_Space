# 密码会话管理修复指南

## 问题描述

当前导入和查看媒体时使用的是占位符密码，需要使用真实的用户密码来加密/解密文件。

## 已完成的修复

### ✅ AuthenticationViewModel.swift

已添加 `sessionPassword` 属性来存储用户密码在内存中：

```swift
/// 会话密码（仅存储在内存中，用于文件加密/解密）
@Published private(set) var sessionPassword: String?
```

登录和设置密码时自动保存：
- `setupPassword()` - 设置密码成功后保存
- `login()` - 登录成功后保存
- `logout()` - 登出时清除

## 需要手动修复的文件

### 1. ImportViewModel.swift

**位置**: 第97行 `getCurrentPassword()` 方法

**当前代码**:
```swift
private func getCurrentPassword() async -> String? {
    return "user_password_from_session"  // 占位符
}
```

**修复方法**:
```swift
// 添加属性
var authViewModel: AuthenticationViewModel?

// 修改方法
private func getCurrentPassword() async -> String? {
    return authViewModel?.sessionPassword
}
```

### 2. MediaDetailView.swift

**位置**: 第286行 `getSessionPassword()` 方法

**当前代码**:
```swift
private func getSessionPassword() -> String? {
    return "user_password_from_session"  // 占位符
}
```

**修复方法**:
```swift
// 添加环境对象
@EnvironmentObject var authViewModel: AuthenticationViewModel

// 修改方法
private func getSessionPassword() -> String? {
    return authViewModel.sessionPassword
}
```

### 3. GalleryView.swift

**需要传递 authViewModel 给子视图**:

```swift
@EnvironmentObject var authViewModel: AuthenticationViewModel

// 在 sheet 中传递
.sheet(isPresented: $viewModel.showImportView) {
    ImportButtonsView { items in
        print("✅ 导入完成: \(items.count) 个文件")
    }
    .environment(\.modelContext, modelContext)
    .environmentObject(authViewModel)  // 添加这行
}
```

### 4. ImportButtonsView.swift

**传递给 ImportViewModel**:

```swift
@EnvironmentObject var authViewModel: AuthenticationViewModel

.onAppear {
    viewModel.authViewModel = authViewModel  // 添加这行
    viewModel.onImportComplete = { items in
        onImportComplete(items)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dismiss()
        }
    }
}
```

### 5. GridItemView.swift → MediaDetailView.swift

**NavigationLink 传递**:

在 GalleryView.swift 的 NavigationLink 中：

```swift
NavigationLink(destination: MediaDetailView(mediaItem: item)
    .environmentObject(authViewModel)  // 添加这行
) {
    GridItemView(mediaItem: item)
}
```

## 完整修复步骤

1. ✅ **AuthenticationViewModel.swift** - 已完成
2. **ImportViewModel.swift** - 添加 `authViewModel` 属性并修改 `getCurrentPassword()`
3. **MediaDetailView.swift** - 添加 `@EnvironmentObject` 并修改 `getSessionPassword()`
4. **GalleryView.swift** - 传递 `authViewModel` 给 ImportButtonsView
5. **ImportButtonsView.swift** - 接收并传递 `authViewModel`
6. **GalleryView.swift** - NavigationLink 传递 `authViewModel` 给 MediaDetailView

## 安全考虑

✅ **优点**:
- 密码仅存储在内存中
- 应用退出后自动清除
- 不写入磁盘或UserDefaults

⚠️ **改进建议**:
- 添加后台自动锁定（应用进入后台超过N秒后清除密码）
- 添加内存警告处理（内存警告时清除密码）
- 考虑使用 Face ID / Touch ID 减少密码输入

## 测试清单

完成修复后测试：

- [ ] 设置密码后能成功导入照片
- [ ] 导入的照片能正确解密显示
- [ ] 登录后能导入和查看媒体
- [ ] 重启应用后重新登录能查看之前导入的媒体
- [ ] 应用退出后密码从内存清除

## 代码示例

### 完整的 getCurrentPassword() 实现

```swift
// ImportViewModel.swift
var authViewModel: AuthenticationViewModel?

private func getCurrentPassword() async -> String? {
    guard let password = authViewModel?.sessionPassword else {
        await MainActor.run {
            errorMessage = "无法获取密码，请重新登录"
        }
        return nil
    }
    return password
}
```

### 完整的 getSessionPassword() 实现

```swift
// MediaDetailView.swift
@EnvironmentObject var authViewModel: AuthenticationViewModel

private func getSessionPassword() -> String? {
    guard let password = authViewModel.sessionPassword else {
        errorMessage = "无法获取密码，请重新登录"
        return nil
    }
    return password
}
```

---

**修复优先级**: 🔴 高 - 必须修复才能正常使用应用

**预计修复时间**: 10-15分钟

**修复难度**: ⭐⭐ 中等（需要修改多个文件传递 EnvironmentObject）
