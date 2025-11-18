# Private Album - 零网络空间 iOS 应用开发文档

## 📱 项目概述

**项目名称：** Private Album（零网络空间）  
**平台：** iOS 15.0+  
**开发语言：** Swift 5.0  
**UI框架：** SwiftUI  
**数据存储：** SwiftData + FileManager  
**版本：** 1.0

### 核心功能

1. 🔐 **密码保护** - 应用启动时强制密码认证
2. 📸 **照片/视频导入** - 从相册导入照片和视频
3. 📁 **文件导入** - 从文件应用导入任意文件
4. 🖼️ **图库浏览** - 网格布局展示所有导入的媒体
5. 🔒 **加密存储** - 所有文件使用 AES-256-GCM 加密

---

## 🏗️ 架构设计

### 架构模式

采用 **MVVM (Model-View-ViewModel)** 架构模式：

```
┌─────────────────────────────────────────────────────┐
│                      View Layer                      │
│  (SwiftUI Views - 用户界面)                          │
│  LoginView, GalleryView, MediaDetailView...         │
└─────────────────┬───────────────────────────────────┘
                  │ Binding & ObservedObject
┌─────────────────▼───────────────────────────────────┐
│                   ViewModel Layer                    │
│  (业务逻辑和状态管理)                                 │
│  AuthViewModel, GalleryViewModel, ImportViewModel    │
└─────────────────┬───────────────────────────────────┘
                  │ Service Calls
┌─────────────────▼───────────────────────────────────┐
│                   Service Layer                      │
│  (核心功能服务)                                       │
│  KeychainService, EncryptionService,                │
│  MediaImportService, FileStorageService             │
└─────────────────┬───────────────────────────────────┘
                  │ Data Access
┌─────────────────▼───────────────────────────────────┐
│                    Model Layer                       │
│  (数据模型)                                           │
│  MediaItem, MediaType, AppSettings                  │
│  SwiftData + Encrypted FileManager                  │
└─────────────────────────────────────────────────────┘
```

### 技术栈选型

| 组件 | 技术选择 | 原因 |
|------|---------|------|
| **UI框架** | SwiftUI | 现代化、声明式UI、代码简洁 |
| **数据存储** | SwiftData (元数据) + FileManager (加密文件) | 混合方案：元数据快速查询 + 完全控制加密 |
| **加密** | CryptoKit (AES-256-GCM) | 原生支持、安全性高、无第三方依赖 |
| **密码存储** | Keychain | iOS标准安全存储 |
| **照片选择** | PHPickerViewController | 隐私友好、无需完整相册权限 |
| **文件选择** | UIDocumentPickerViewController | 系统标准文件选择器 |

---

## 📂 项目结构

```
ZeroNet-Space/
├── App/                                    # 应用入口
│   ├── Private_AlbumApp.swift             # 主应用文件（修改）
│   └── AppConstants.swift                 # 全局常量配置
│
├── Models/                                 # 数据模型层
│   ├── MediaItem.swift                    # 媒体项模型（SwiftData）
│   ├── MediaType.swift                    # 媒体类型枚举
│   └── AppSettings.swift                  # 应用设置模型
│
├── Views/                                  # 视图层
│   ├── Authentication/                    # 认证相关视图
│   │   ├── LoginView.swift               # 登录界面
│   │   └── SetupPasswordView.swift       # 首次设置密码界面
│   │
│   ├── Gallery/                          # 图库相关视图
│   │   ├── GalleryView.swift            # 主图库界面
│   │   ├── GridItemView.swift           # 网格项视图
│   │   └── MediaDetailView.swift        # 媒体详情/全屏查看
│   │
│   └── Import/                           # 导入相关视图
│       └── ImportButtonsView.swift      # 导入按钮组
│
├── ViewModels/                            # 视图模型层
│   ├── AuthenticationViewModel.swift     # 认证逻辑
│   ├── GalleryViewModel.swift           # 图库逻辑
│   └── ImportViewModel.swift            # 导入逻辑
│
├── Services/                              # 服务层
│   ├── KeychainService.swift            # Keychain操作
│   ├── EncryptionService.swift          # 文件加密/解密
│   ├── MediaImportService.swift         # 媒体导入
│   └── FileStorageService.swift         # 文件存储管理
│
├── Utilities/                             # 工具类
│   ├── Extensions.swift                 # Swift扩展
│   └── PhotoPickerRepresentable.swift   # UIKit桥接
│
└── Assets.xcassets/                       # 资源文件
    ├── AppIcon.appiconset/
    └── Colors/
```

---

## 🔐 安全架构详解

### 1. 密码管理流程

```
首次启动
    ↓
SetupPasswordView
    ├── 用户输入密码（两次确认）
    ├── 密码强度验证（至少6位）
    ↓
KeychainService.savePassword()
    ├── 生成随机盐值（Salt）
    ├── SHA-256哈希 + 盐值
    ├── 存入iOS Keychain
    └── 标记已设置密码

后续启动
    ↓
LoginView
    ├── 用户输入密码
    ↓
KeychainService.verifyPassword()
    ├── 读取Keychain中的哈希和盐值
    ├── 输入密码 + 盐值 → SHA-256
    ├── 对比哈希值
    └── 验证成功 → 进入应用
```

### 2. 文件加密流程

**加密算法：** AES-256-GCM

**特点：**
- 对称加密（加解密使用同一密钥）
- GCM模式提供认证（防篡改）
- 256位密钥（最高安全级别）

**加密流程：**

```
用户导入文件
    ↓
EncryptionService.encrypt(fileData, password)
    ├── 使用PBKDF2从密码派生256位密钥
    │   └── 参数：10万次迭代、随机盐值
    ├── 生成随机IV（初始化向量）
    ├── AES-256-GCM加密文件数据
    │   └── 生成认证标签（防篡改）
    ├── 组合：盐值 + IV + 认证标签 + 加密数据
    └── 返回加密后的Data

FileStorageService.save(encryptedData)
    ├── 生成唯一文件名（UUID）
    ├── 保存到Documents/EncryptedMedia/
    └── 返回文件路径

SwiftData保存元数据
    ├── MediaItem模型
    │   ├── id: UUID
    │   ├── fileName: 原始文件名
    │   ├── type: 照片/视频/文档
    │   ├── encryptedPath: 加密文件路径
    │   ├── thumbnailData: 缩略图（加密）
    │   └── createdAt: 导入日期
    └── 存入SwiftData数据库
```

**解密流程：**

```
用户点击查看媒体
    ↓
从SwiftData读取MediaItem元数据
    ↓
FileStorageService.load(encryptedPath)
    ├── 读取加密文件
    └── 返回加密Data

EncryptionService.decrypt(encryptedData, password)
    ├── 解析：盐值 + IV + 认证标签 + 密文
    ├── 使用PBKDF2重新派生密钥（相同盐值）
    ├── AES-256-GCM解密
    │   └── 验证认证标签（确保未被篡改）
    └── 返回原始文件Data

显示媒体内容
    ├── 照片/视频 → Image/VideoPlayer
    └── 文件 → QuickLook预览
```

### 3. 安全存储位置

```
应用沙盒
├── Documents/                          # 用户可见目录
│   └── EncryptedMedia/                # 加密文件存储
│       ├── UUID-1.encrypted          # 加密的照片
│       ├── UUID-2.encrypted          # 加密的视频
│       └── UUID-3.encrypted          # 加密的文件
│
├── Library/                           # 系统库目录
│   ├── Application Support/          # SwiftData数据库
│   │   └── default.store            # 元数据（文件路径、名称等）
│   └── Preferences/                  # 用户偏好设置
│
└── 系统Keychain                       # iOS安全存储
    ├── 密码哈希值
    ├── 盐值
    └── 是否已设置密码标志
```

---

## 🎨 用户界面设计

### 界面流程图

```
应用启动
    │
    ├─── 首次使用？
    │    YES → SetupPasswordView (设置密码)
    │           ├── 输入密码（6位以上）
    │           ├── 再次确认密码
    │           └── 保存 → 进入GalleryView
    │
    └─── NO → LoginView (登录)
               ├── 输入密码
               ├── 验证密码
               │   ├── 正确 → GalleryView
               │   └── 错误 → 显示错误提示
               └── 忘记密码？（提示：需要卸载重装）

GalleryView (主图库)
    ├── NavigationBar
    │   ├── 标题："零网络空间"
    │   └── "+" 按钮 → ImportButtonsView
    │
    ├── 网格布局 (3列)
    │   ├── GridItemView (照片缩略图)
    │   ├── GridItemView (视频缩略图 + 播放图标)
    │   └── GridItemView (文件图标 + 文件名)
    │
    └── 点击Item → MediaDetailView

ImportButtonsView (导入选项)
    ├── 📸 从相册导入
    │   └── PHPickerViewController
    │       └── 多选照片/视频 → 加密 → 保存
    │
    ├── 📁 从文件导入
    │   └── UIDocumentPickerViewController
    │       └── 选择文件 → 加密 → 保存
    │
    └── ❌ 取消

MediaDetailView (媒体详情)
    ├── 全屏显示
    │   ├── 照片 → 支持缩放、双击放大
    │   ├── 视频 → VideoPlayer播放
    │   └── 文件 → QuickLook预览
    │
    ├── NavigationBar
    │   ├── "< 返回"
    │   └── 🗑️ 删除按钮
    │
    └── 底部工具栏
        ├── 文件名
        ├── 导入日期
        └── 文件大小
```

### 视图层级结构

```
Private_AlbumApp
    │
    ├── @State isAuthenticated: Bool
    │
    └── WindowGroup
        └── if isAuthenticated
            ├── GalleryView (已认证)
            │   ├── @StateObject galleryVM
            │   ├── NavigationStack
            │   │   ├── LazyVGrid (网格布局)
            │   │   │   └── ForEach(mediaItems)
            │   │   │       └── GridItemView
            │   │   │           ├── AsyncImage (缩略图)
            │   │   │           └── onTap → navigationDestination
            │   │   │               └── MediaDetailView
            │   │   └── toolbar
            │   │       └── "+" Button → ImportButtonsView
            │   │
            │   └── ImportButtonsView (Sheet)
            │       ├── PhotoPickerRepresentable
            │       └── DocumentPicker
            │
            └── else
                └── if firstTimeSetup
                    ├── SetupPasswordView (首次设置)
                    │   ├── @StateObject authVM
                    │   ├── SecureField (密码)
                    │   ├── SecureField (确认密码)
                    │   └── Button → authVM.setupPassword()
                    │
                    └── else
                        └── LoginView (登录)
                            ├── @StateObject authVM
                            ├── SecureField (密码)
                            ├── Button → authVM.login()
                            └── Alert (错误提示)
```

---

## 📊 数据模型设计

### 1. MediaItem (SwiftData Model)

```swift
@Model
final class MediaItem {
    // 唯一标识
    var id: UUID
    
    // 原始文件信息
    var fileName: String          // 原始文件名（如："IMG_1234.jpg"）
    var fileExtension: String     // 文件扩展名（如：".jpg"）
    var fileSize: Int64          // 文件大小（字节）
    
    // 媒体类型
    var type: MediaType          // .photo / .video / .document
    
    // 加密文件路径
    var encryptedPath: String    // 加密文件的完整路径
    
    // 缩略图（加密后的Data）
    var thumbnailData: Data?     // 用于快速展示的缩略图
    
    // 时间戳
    var createdAt: Date          // 导入时间
    var modifiedAt: Date         // 最后修改时间
    
    // 可选元数据
    var width: Int?              // 图片/视频宽度（像素）
    var height: Int?             // 图片/视频高度（像素）
    var duration: Double?        // 视频时长（秒）
}
```

### 2. MediaType (Enum)

```swift
enum MediaType: String, Codable {
    case photo      // 照片（jpg, png, heic等）
    case video      // 视频（mp4, mov等）
    case document   // 文档（pdf, doc, txt等）
    
    var icon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        case .document: return "doc.fill"
        }
    }
}
```

### 3. AppSettings (UserDefaults Wrapper)

```swift
class AppSettings: ObservableObject {
    @Published var isPasswordSet: Bool      // 是否已设置密码
    @Published var sortOrder: SortOrder     // 排序方式
    @Published var gridColumns: Int         // 网格列数（2-4列）
    
    enum SortOrder: String {
        case dateNewest     // 最新优先
        case dateOldest     // 最旧优先
        case nameAZ         // 名称A-Z
        case nameZA         // 名称Z-A
        case sizeSmallest   // 文件大小（小到大）
        case sizeLargest    // 文件大小（大到小）
    }
}
```

---

## 🔧 核心服务实现

### 1. KeychainService（密码管理）

**功能：**
- ✅ 保存密码哈希到Keychain
- ✅ 验证用户输入的密码
- ✅ 删除密码（卸载重装场景）
- ✅ 检查是否已设置密码

**关键方法：**
```swift
class KeychainService {
    static let shared = KeychainService()
    
    // 保存密码（首次设置）
    func savePassword(_ password: String) throws
    
    // 验证密码（登录）
    func verifyPassword(_ password: String) -> Bool
    
    // 检查是否已设置密码
    func isPasswordSet() -> Bool
    
    // 删除密码（重置应用）
    func deletePassword() throws
}
```

**安全措施：**
- 使用 SHA-256 哈希（不存储明文）
- 每个密码使用唯一随机盐值
- Keychain标记为 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`（仅解锁时访问，不同步iCloud）

### 2. EncryptionService（加密服务）

**功能：**
- ✅ 文件加密（AES-256-GCM）
- ✅ 文件解密
- ✅ 密钥派生（PBKDF2）
- ✅ 安全删除临时数据

**关键方法：**
```swift
class EncryptionService {
    static let shared = EncryptionService()
    
    // 加密文件数据
    func encrypt(data: Data, password: String) throws -> Data
    
    // 解密文件数据
    func decrypt(encryptedData: Data, password: String) throws -> Data
    
    // 从密码派生加密密钥
    private func deriveKey(password: String, salt: Data) throws -> SymmetricKey
}
```

**加密格式：**
```
[盐值: 16字节] + [IV: 12字节] + [认证标签: 16字节] + [密文: N字节]
```

### 3. FileStorageService（文件管理）

**功能：**
- ✅ 保存加密文件到沙盒
- ✅ 读取加密文件
- ✅ 删除文件
- ✅ 获取文件大小
- ✅ 管理存储路径

**关键方法：**
```swift
class FileStorageService {
    static let shared = FileStorageService()
    
    // 保存加密数据
    func saveEncrypted(data: Data, fileName: String) throws -> String
    
    // 读取加密数据
    func loadEncrypted(path: String) throws -> Data
    
    // 删除文件
    func deleteFile(path: String) throws
    
    // 获取存储目录路径
    func getStorageDirectory() -> URL
    
    // 计算总存储大小
    func getTotalStorageSize() -> Int64
}
```

### 4. MediaImportService（导入服务）

**功能：**
- ✅ 处理照片/视频导入
- ✅ 处理文件导入
- ✅ 生成缩略图
- ✅ 提取媒体元数据
- ✅ 导入进度回调

**关键方法：**
```swift
class MediaImportService {
    static let shared = MediaImportService()
    
    // 导入照片/视频
    func importMedia(
        results: [PHPickerResult],
        password: String,
        progress: @escaping (Double) -> Void
    ) async throws -> [MediaItem]
    
    // 导入文件
    func importFiles(
        urls: [URL],
        password: String,
        progress: @escaping (Double) -> Void
    ) async throws -> [MediaItem]
    
    // 生成缩略图
    private func generateThumbnail(for data: Data, type: MediaType) -> Data?
    
    // 提取元数据
    private func extractMetadata(from data: Data, type: MediaType) -> (width: Int?, height: Int?, duration: Double?)
}
```

---

## 🚀 开发阶段实施计划

### Phase 1: 认证系统（2-3小时）

**目标：** 实现密码保护功能

**任务清单：**
- [x] 创建 `KeychainService.swift`
  - 实现密码保存/验证/删除
  - 添加单元测试
- [x] 创建 `AuthenticationViewModel.swift`
  - 管理认证状态
  - 密码验证逻辑
- [x] 创建 `SetupPasswordView.swift`
  - 首次设置密码UI
  - 密码强度验证
  - 确认密码匹配检查
- [x] 创建 `LoginView.swift`
  - 登录界面UI
  - 错误提示
  - 忘记密码提示
- [x] 修改 `Private_AlbumApp.swift`
  - 添加认证状态检查
  - 根据状态显示不同界面

**验收标准：**
- ✅ 首次启动显示密码设置界面
- ✅ 密码成功保存到Keychain
- ✅ 后续启动显示登录界面
- ✅ 密码验证正确后进入应用
- ✅ 密码错误显示错误提示

---

### Phase 2: 数据模型（1小时）

**目标：** 建立数据结构基础

**任务清单：**
- [x] 创建 `MediaType.swift`
  - 定义媒体类型枚举
  - 添加图标映射
- [x] 创建 `MediaItem.swift`
  - SwiftData模型定义
  - 添加计算属性
- [x] 创建 `AppSettings.swift`
  - UserDefaults包装类
  - 排序选项
- [x] 创建 `AppConstants.swift`
  - 全局常量配置
- [x] 删除 `Item.swift`（旧模板文件）

**验收标准：**
- ✅ MediaItem模型编译通过
- ✅ SwiftData集成无错误
- ✅ 类型定义清晰完整

---

### Phase 3: 加密存储（2-3小时）

**目标：** 实现文件加密和安全存储

**任务清单：**
- [x] 创建 `EncryptionService.swift`
  - AES-256-GCM加密实现
  - PBKDF2密钥派生
  - 添加单元测试
- [x] 创建 `FileStorageService.swift`
  - 文件保存/读取
  - 目录管理
  - 文件删除
- [x] 实现缩略图加密存储
- [x] 添加加密性能测试

**验收标准：**
- ✅ 文件可以成功加密
- ✅ 加密文件可以正确解密
- ✅ 认证标签验证防篡改
- ✅ 大文件加密性能可接受（<2秒/10MB）

---

### Phase 4: 媒体导入（2-3小时）

**目标：** 实现照片、视频、文件导入

**任务清单：**
- [x] 创建 `PhotoPickerRepresentable.swift`
  - PHPickerViewController SwiftUI桥接
  - 多选支持
- [x] 创建 `MediaImportService.swift`
  - 处理照片/视频导入
  - 处理文件导入
  - 生成缩略图
  - 提取元数据
- [x] 创建 `ImportViewModel.swift`
  - 导入流程管理
  - 进度追踪
- [x] 创建 `ImportButtonsView.swift`
  - 导入按钮UI
  - Sheet展示
- [x] 更新 `Info.plist`
  - 添加相册访问权限描述

**验收标准：**
- ✅ 可以从相册选择照片/视频
- ✅ 可以从文件选择任意文件
- ✅ 导入后文件正确加密
- ✅ 元数据正确保存到SwiftData
- ✅ 缩略图正常生成

---

### Phase 5: 图库界面（2-3小时）

**目标：** 构建美观的媒体浏览界面

**任务清单：**
- [x] 创建 `GalleryViewModel.swift`
  - 媒体列表管理
  - 排序和过滤
  - 删除操作
- [x] 创建 `GalleryView.swift`
  - 网格布局（LazyVGrid）
  - 下拉刷新
  - 空状态视图
- [x] 创建 `GridItemView.swift`
  - 缩略图显示
  - 类型图标
  - 选中状态
- [x] 创建 `MediaDetailView.swift`
  - 全屏照片查看（支持缩放）
  - 视频播放器
  - 文件预览（QuickLook）
  - 删除确认
- [x] 创建 `Extensions.swift`
  - View扩展
  - Date格式化
  - 文件大小格式化

**验收标准：**
- ✅ 图库网格布局美观
- ✅ 缩略图加载流畅
- ✅ 点击查看大图/播放视频
- ✅ 删除功能正常
- ✅ 空状态提示友好

---

### Phase 6: 完善测试（1-2小时）

**目标：** 确保应用稳定可靠

**任务清单：**
- [x] 添加加载状态
  - 导入时显示进度
  - 解密时显示Loading
- [x] 错误处理
  - 加密失败提示
  - 存储空间不足提示
  - 权限拒绝处理
- [x] 性能优化
  - 缩略图缓存
  - 懒加载优化
  - 内存管理
- [x] 单元测试
  - KeychainService测试
  - EncryptionService测试
  - FileStorageService测试
- [x] UI测试
  - 登录流程测试
  - 导入流程测试
- [x] 调整部署目标到 iOS 15.0

**验收标准：**
- ✅ 无崩溃
- ✅ 无内存泄漏
- ✅ 核心功能单元测试覆盖 >80%
- ✅ 用户体验流畅

---

## 🧪 测试策略

### 单元测试

**KeychainServiceTests:**
```swift
- testSavePassword()          // 测试保存密码
- testVerifyCorrectPassword()  // 测试正确密码验证
- testVerifyWrongPassword()    // 测试错误密码验证
- testDeletePassword()         // 测试删除密码
- testIsPasswordSet()          // 测试密码设置状态
```

**EncryptionServiceTests:**
```swift
- testEncryptDecrypt()         // 测试加密解密往返
- testTamperedDataFails()      // 测试篡改数据失败
- testDifferentPasswords()     // 测试不同密码解密失败
- testLargeFile()              // 测试大文件加密性能
- testKeyDerivation()          // 测试密钥派生一致性
```

**FileStorageServiceTests:**
```swift
- testSaveAndLoad()            // 测试保存和读取
- testDeleteFile()             // 测试删除文件
- testStorageSize()            // 测试存储大小计算
- testFileNotFound()           // 测试文件不存在错误
```

### UI测试

**AuthenticationFlowTests:**
```swift
- testFirstTimeSetup()         // 测试首次设置密码流程
- testLoginSuccess()           // 测试登录成功
- testLoginFailure()           // 测试登录失败
- testPasswordMismatch()       // 测试密码不匹配
```

**ImportFlowTests:**
```swift
- testImportPhoto()            // 测试导入照片
- testImportVideo()            // 测试导入视频
- testImportFile()             // 测试导入文件
- testImportProgress()         // 测试导入进度显示
```

**GalleryFlowTests:**
```swift
- testDisplayMedia()           // 测试显示媒体
- testDeleteMedia()            // 测试删除媒体
- testSortMedia()              // 测试排序
- testSearchMedia()            // 测试搜索（如果实现）
```

---

## 📱 权限配置

### Info.plist 必需配置

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问您的照片库以导入照片和视频到零网络空间</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存照片到您的照片库</string>

<key>UISupportsDocumentBrowser</key>
<true/>
```

### 最低部署目标

```xml
<key>MinimumOSVersion</key>
<string>15.0</string>
```

---

## 🎯 性能优化建议

### 1. 缩略图策略

- **生成时机：** 导入时生成，加密后存储
- **尺寸：** 300x300 像素（@3x = 900x900）
- **压缩：** JPEG 质量 0.7
- **缓存：** 内存缓存解密后的缩略图

### 2. 懒加载

- 使用 `LazyVGrid` 而非 `Grid`（仅渲染可见项）
- 缩略图使用 `AsyncImage`
- 大文件解密使用后台线程

### 3. 内存管理

- 及时释放解密后的大文件Data
- 使用 `autoreleasepool` 处理批量操作
- 监控内存警告，清理缓存

### 4. 加密性能

**预期性能：**
- 1MB文件：~50ms
- 10MB文件：~500ms
- 100MB视频：~5秒

**优化措施：**
- PBKDF2迭代次数：10万（安全与性能平衡）
- 使用后台队列加密
- 显示进度指示器

---

## 🐛 已知问题和局限

### 1. 忘记密码

**问题：** 用户忘记密码后无法恢复数据

**解决方案：**
- ⚠️ 在设置密码时明确提示用户记住密码
- ⚠️ 提供"忘记密码"说明：需要卸载应用，所有数据将丢失
- 💡 未来考虑：添加生物识别认证（Face ID/Touch ID）

### 2. 大文件性能

**问题：** 超大视频（>500MB）加密时间较长

**解决方案：**
- ✅ 显示详细进度
- ✅ 允许后台加密
- 💡 未来考虑：流式加密

### 3. iCloud同步

**问题：** 当前不支持iCloud同步

**解决方案：**
- ✅ 数据仅存储在设备本地
- 💡 未来考虑：添加iCloud加密同步

### 4. 分享功能

**问题：** 无法直接分享加密媒体

**解决方案：**
- 💡 未来考虑：临时解密并分享（用完删除）
- 💡 或者：导出到相册（用户手动操作）

---

## 🚀 未来功能规划

### v1.1
- [ ] Face ID / Touch ID 支持
- [ ] 导出媒体到相册
- [ ] 分享解密后的文件

### v1.2
- [ ] 相册分类/标签
- [ ] 搜索功能
- [ ] 批量导入

### v1.3
- [ ] iCloud加密同步
- [ ] iPad适配
- [ ] macOS版本

### v2.0
- [ ] 伪装模式（计算器外壳）
- [ ] 入侵检测（多次密码错误拍照）
- [ ] 自动锁定（后台N秒后重新要求密码）

---

## 📞 技术支持

### 开发环境要求

- **Xcode：** 14.0+
- **macOS：** Ventura 13.0+
- **iOS部署目标：** 15.0+
- **Swift：** 5.0+

### 依赖库

**无第三方依赖！** 全部使用Apple原生框架：
- SwiftUI
- SwiftData
- CryptoKit
- PhotosUI
- UniformTypeIdentifiers
- QuickLook

### 常见问题

**Q: 如何重置密码？**  
A: 目前唯一方式是卸载应用重新安装（所有数据将丢失）

**Q: 数据会同步到iCloud吗？**  
A: 不会，所有数据仅存储在设备本地

**Q: 支持的文件类型？**  
A: 所有类型！照片、视频、PDF、Word、Excel等

**Q: 加密安全吗？**  
A: 使用军用级AES-256-GCM加密，与银行应用同级别

---

## 📄 许可证

此项目为私人开发项目，版权归开发者所有。

---

## ✅ 开发完成检查清单

### Phase 1: 认证系统
- [ ] KeychainService 实现并测试通过
- [ ] LoginView UI完成
- [ ] SetupPasswordView UI完成
- [ ] 密码验证逻辑正确
- [ ] 应用启动流程正确

### Phase 2: 数据模型
- [ ] MediaItem 模型定义完成
- [ ] MediaType 枚举完成
- [ ] AppSettings 完成
- [ ] SwiftData 集成无错误

### Phase 3: 加密存储
- [ ] EncryptionService 实现并测试通过
- [ ] FileStorageService 实现并测试通过
- [ ] 加密解密往返测试通过
- [ ] 防篡改测试通过

### Phase 4: 媒体导入
- [ ] PHPickerViewController 集成完成
- [ ] UIDocumentPickerViewController 集成完成
- [ ] 导入流程完整无错误
- [ ] 缩略图生成正常
- [ ] 权限请求正常

### Phase 5: 图库界面
- [ ] GalleryView UI美观且流畅
- [ ] 网格布局正确
- [ ] MediaDetailView 功能完整
- [ ] 删除功能正常
- [ ] 视频播放正常

### Phase 6: 完善测试
- [ ] 单元测试覆盖率 >80%
- [ ] UI测试主流程通过
- [ ] 错误处理完善
- [ ] 性能测试通过
- [ ] 无内存泄漏
- [ ] 部署目标调整为 iOS 15.0

---

**文档版本：** 1.0  
**创建日期：** 2025-11-05  
**最后更新：** 2025-11-05  
**作者：** Claude AI Assistant

---

**准备好开始开发了吗？** 🚀

按照上述6个Phase依次实现，每个Phase完成后进行测试验证，确保质量后再进入下一个Phase。

祝开发顺利！💪
