# 零网络空间 / ZeroNet Space

<div align="center">

**真正的离线隐私空间 | 零网络 | 零追踪**

[![Platform](https://img.shields.io/badge/Platform-iOS%2015.0+-lightgrey.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![Security](https://img.shields.io/badge/Security-AES--256--GCM-green.svg)](https://en.wikipedia.org/wiki/Galois/Counter_Mode)

[English](#english) | [中文](#中文)

</div>

---

## 中文

### 📖 关于项目

零网络空间是一款iOS隐私保护应用，承诺：

- ✅ **零网络**：代码级阻断所有网络请求
- ✅ **零追踪**：不含任何SDK、广告、统计、云备份
- ✅ **零账号**：不注册、不登录、不收集隐私数据
- ✅ **本地加密**：AES-256-GCM军用级加密，密钥仅存本地Keychain
- ✅ **隐私优先**：通过App Store隐私审查，符合最新隐私标准

**核心理念**：你的数据应该只属于你自己，不应该被上传、分析或追踪。

---

### 🌟 核心功能

#### 基础功能
- 🔐 **密码保护** - 6-8位强密码，支持生物识别（Face ID/Touch ID）
- 📸 **媒体加密存储** - 照片、视频、文档全部AES-256-GCM加密
- 📁 **文件夹管理** - 自定义文件夹和标签系统
- 🎬 **媒体预览** - 全屏查看照片、播放视频、预览文档

#### 高级隐私功能（V1.2）
- 👥 **访客模式** - 双密码体系，临时访问不暴露核心隐私
  - 主密码（6-8位）：完全访问权限
  - 访客密码（6-8位纯数字）：受限访问，自动隐藏敏感内容
  - 服务端密码验证：访客密码不能与主密码相同
- 🔒 **隐藏空间** - 私密笔记和敏感文件的隐藏区域
- 🧮 **伪装界面** - 计算器伪装模式，保护隐私
- 🌓 **深色模式** - 完整的深浅色主题支持
- 🌍 **国际化** - 完整支持简体中文和英文

#### 安全特性
- 🛡️ **应用重启强制认证** - 防止未授权访问
- 🔐 **密码安全增强** - PBKDF2密钥派生，100,000次迭代
- 🔒 **线程安全保护** - @MainActor确保状态管理安全
- 🧵 **并发访问控制** - NSLock保护关键操作
- 🗑️ **安全删除** - 文件删除后彻底清除加密数据
- 💾 **原子操作** - 确保数据一致性，防止数据损坏
- 🔑 **密钥安全管理** - 内存安全擦除，防止密钥泄露

---

### 🔒 最新安全增强（V1.2 Security Update）

#### 加密服务升级
- ✅ **PBKDF2密钥派生**：100,000次迭代，防止暴力破解
- ✅ **安全随机生成**：使用CryptoKit的安全随机数生成器
- ✅ **盐值管理**：每次加密使用唯一的16字节随机盐
- ✅ **IV管理**：每次加密使用唯一的12字节随机IV
- ✅ **内存安全**：密钥使用后立即安全擦除

#### 钥匙串服务增强
- ✅ **原子操作**：确保密码设置和验证的原子性
- ✅ **并发保护**：NSLock防止并发访问冲突
- ✅ **错误处理**：完善的错误传播和恢复机制
- ✅ **数据一致性**：防止部分写入导致的数据损坏

#### 认证系统优化
- ✅ **状态管理**：修复访客模式状态管理漏洞
- ✅ **密码验证**：服务端验证防止弱密码策略绕过
- ✅ **错误传播**：完整的错误处理链路
- ✅ **线程安全**：@MainActor保证UI更新安全

---

### 💰 定价模式与内购说明

#### App Store 版本定价模式

**基础版（免费）**：
- ✅ 完整的加密功能（AES-256-GCM）
- ✅ 隐藏空间
- ✅ 伪装界面
- ✅ 深色模式
- ✅ 所有核心安全功能
- ⚠️ **文件数量限制：最多75个文件**

**Pro版功能（应用内购买）**：
- 🔓 **无限文件存储** - 解除75个文件限制
- 🔓 **访客模式** - 双密码体系，保护隐私
- 💰 **一次性买断** - 永久使用，无订阅

#### 为什么这样设计？

**1. 可持续的开源模式**
- 免费版满足基础需求（75个文件对大多数用户足够）
- 高级用户付费支持持续开发
- 避免广告和数据收集

**2. 参考成熟开源项目**
- **Bitwarden**：基础版免费，高级功能付费
- **1Password**：开源组件免费，完整版付费
- **Obsidian**：个人使用免费，商业使用付费

**3. App Store 便利性**
- 无需安装Xcode（8GB+下载）
- 无需学习iOS开发和编译流程
- 无需Apple开发者账号（$99/年）
- 自动更新和官方技术支持

**核心原则**：**代码永远免费，便利性和高级功能合理收费**。

#### 功能对比

| 特性 | App Store 免费版 | App Store Pro版 |
|------|----------------|----------------|
| 完整加密功能 | ✅ | ✅ |
| 隐藏空间 | ✅ | ✅ |
| 伪装界面 | ✅ | ✅ |
| 深色模式 | ✅ | ✅ |
| 最新安全增强 | ✅ | ✅ |
| **文件数量** | **最多75个** | **无限** |
| **访客模式** | ❌ 需要Pro | ✅ |
| 获取方式 | ✅ 一键下载 | ✅ 一键下载 |
| 自动更新 | ✅ 自动推送 | ✅ 自动推送 |
| 技术支持 | ✅ 官方支持 | ✅ 优先支持 |
| **价格** | **免费** | **一次性内购** |

> 💡 **普通用户**：免费版足够日常使用（75个文件）  
> 💡 **高级用户**：Pro版解锁所有功能，一次性买断永久使用

#### 内购透明承诺

- ✅ **无订阅制**：所有内购都是一次性买断，永久使用
- ✅ **无隐藏费用**：明码标价，不会有额外收费
- ✅ **功能完整**：免费版和Pro版都包含核心加密功能
- ✅ **零网络承诺不变**：内购验证完全本地，不联网

---

### 🚀 快速开始

[![Download on App Store](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://apps.apple.com/app/零网络空间)

> 即将上架，敬请期待！

---

### 🛠️ 技术栈

#### 核心技术
- **语言**: Swift 5.9
- **UI框架**: SwiftUI 3.0+
- **数据存储**: SwiftData + FileManager
- **加密算法**: CryptoKit (AES-256-GCM)
- **密码管理**: iOS Keychain + PBKDF2
- **最低支持**: iOS 15.0+

#### 架构特点
- ✅ MVVM架构模式
- ✅ @MainActor线程安全
- ✅ 环境对象依赖注入
- ✅ 现代Swift并发（async/await）
- ✅ 原子操作保证数据一致性
- ✅ 并发控制防止竞态条件

---

### 🔐 安全设计

#### 密码管理
```
存储方式: iOS Keychain
哈希算法: SHA-256
盐值: 32字节随机生成（CryptoKit）
验证延迟: 0.5秒（防暴力破解）
密钥派生: PBKDF2 (100,000次迭代)
```

#### 文件加密
```
加密算法: AES-256-GCM
密钥派生: PBKDF2 (100,000次迭代)
盐值: 16字节随机（每次加密唯一）
IV: 12字节随机（每次加密唯一）
认证标签: 16字节（防数据篡改）
加密格式: 盐值(16) + IV(12) + 标签(16) + 密文
内存安全: 密钥使用后立即擦除
```

#### 并发安全
```
主线程: @MainActor保护UI状态
原子操作: NSLock保护关键数据
状态管理: Published属性线程安全
错误处理: 完整的错误传播链
```

#### 网络隔离
```
网络权限: ❌ 未请求
网络代码: ❌ 不存在
第三方SDK: ❌ 零依赖
云服务: ❌ 完全本地
统计追踪: ❌ 零收集
隐私清单: ✅ 已提供（PrivacyInfo.xcprivacy）
```

**验证方式**：
- 检查`PrivacyInfo.xcprivacy` - 了解应用隐私实践
- 运行时监控 - 可使用Charles/Wireshark验证零网络流量

---

### 🧪 安全反馈

如果发现安全问题：
- 📧 请通过 GitHub Issues 私密方式报告
- 💬 或直接联系项目维护者
- 🏆 负责任披露将在 README 中致谢

#### 安全更新记录
- **V1.2 (2025-01-17)**: 重大安全增强
  - 修复EncryptionService密钥派生漏洞
  - 修复KeychainService并发安全问题
  - 修复AuthenticationViewModel状态管理漏洞
  - 增强CalculatorViewModel内存安全
  - 完善错误处理和传播机制

---

### ⚠️ 重要声明

#### 数据安全提示

- **忘记密码无法恢复**：我们无法重置密码，忘记密码需要卸载应用（数据将丢失）
- **无云备份**：所有数据仅存储本地，卸载应用或更换设备会丢失数据
- **离线使用**：完全不联网意味着无法远程恢复数据
- **请务必记住密码**：建议使用密码管理器记录

#### 隐私承诺

- ✅ 我们**永远不会**添加网络功能（内购验证完全本地）
- ✅ 我们**永远不会**收集用户数据
- ✅ 我们**永远不会**添加追踪或统计

- ✅ 我们**永远不会**添加广告
- ✅ 内购**永远**是一次性买断，绝不改为订阅制



---

### 📊 项目状态

- **当前版本**: V1.2
- **开发状态**: ✅ 稳定维护中
- **最后更新**: 2025-01-17
- **下个版本**: V2.0（计划中）
- **App Store状态**: 📋 准备提交审核中

---

### 🗺️ 路线图

#### V2.0（计划中）
- [ ] 云端加密备份（可选，需用户主动启用）
- [ ] 密码找回机制（基于本地安全问题）
- [ ] 更多文件格式支持
- [ ] 批量操作优化
- [ ] 性能优化和内存管理改进

#### 长期规划
- [ ] iPad适配
- [ ] macOS版本
- [ ] 更多语言支持
- [ ] 插件系统

---

## English

### 📖 About

ZeroNet Space is an iOS privacy protection app with promises:

- ✅ **Zero Network**: Code-level network blocking
- ✅ **Zero Tracking**: No SDK, ads, analytics, or cloud backup
- ✅ **Zero Account**: No registration, login, or data collection
- ✅ **Local Encryption**: AES-256-GCM military-grade encryption with PBKDF2
- ✅ **Privacy First**: Passed App Store privacy review with privacy manifest

**Core Philosophy**: Your data belongs to you alone, not to be uploaded, analyzed, or tracked.

---

### 🌟 Features

#### Basic Features
- 🔐 **Password Protection** - 6-8 digit strong password with biometric support (Face ID/Touch ID)
- 📸 **Encrypted Media Storage** - Photos, videos, documents with AES-256-GCM encryption
- 📁 **Folder Management** - Custom folders and tag system
- 🎬 **Media Preview** - Fullscreen photo viewer, video player, document preview

#### Advanced Privacy (V1.2)
- 👥 **Guest Mode** - Dual password system for temporary access
  - Master Password (6-8 digits): Full access
  - Guest Password (6-8 digits, numbers only): Limited access with hidden sensitive content
  - Server-side validation: Guest password cannot match master password
- 🔒 **Hidden Space** - Secret notes and sensitive files area
- 🧮 **Disguise Interface** - Calculator disguise mode for privacy protection
- 🌓 **Dark Mode** - Complete light/dark theme support
- 🌍 **Internationalization** - Full support for English and Simplified Chinese

#### Security Features
- 🛡️ **App Restart Authentication** - Prevent unauthorized access
- 🔐 **Enhanced Password Security** - PBKDF2 key derivation with 100,000 iterations
- 🔒 **Thread Safety Protection** - @MainActor ensures safe state management
- 🧵 **Concurrent Access Control** - NSLock protects critical operations
- 🗑️ **Secure Deletion** - Thoroughly wipes encrypted data after file deletion
- 💾 **Atomic Operations** - Ensures data consistency and prevents corruption
- 🔑 **Secure Key Management** - Memory-safe key erasure to prevent leaks

---

### 🔒 Latest Security Enhancements (V1.2)

#### Encryption Service Upgrades
- ✅ **PBKDF2 Key Derivation**: 100,000 iterations to prevent brute force attacks
- ✅ **Secure Random Generation**: Using CryptoKit's secure random number generator
- ✅ **Salt Management**: Unique 16-byte random salt for each encryption
- ✅ **IV Management**: Unique 12-byte random IV for each encryption
- ✅ **Memory Safety**: Immediate secure erasure of keys after use

#### Keychain Service Enhancements
- ✅ **Atomic Operations**: Ensures atomicity of password setting and verification
- ✅ **Concurrency Protection**: NSLock prevents concurrent access conflicts
- ✅ **Error Handling**: Comprehensive error propagation and recovery mechanisms
- ✅ **Data Consistency**: Prevents data corruption from partial writes

#### Authentication System Optimization
- ✅ **State Management**: Fixed guest mode state management vulnerabilities
- ✅ **Password Validation**: Server-side validation prevents weak password policy bypass
- ✅ **Error Propagation**: Complete error handling chain
- ✅ **Thread Safety**: @MainActor ensures safe UI updates

---

### 💰 Pricing Model & In-App Purchase

#### App Store Version Pricing

**Free Version**:
- ✅ Full encryption features (AES-256-GCM)
- ✅ Hidden space
- ✅ Disguise interface
- ✅ Dark mode
- ✅ All core security features
- ⚠️ **File limit: Up to 75 files**

**Pro Version (In-App Purchase)**:
- 🔓 **Unlimited file storage** - Remove 75 file limit
- 🔓 **Guest Mode** - Dual password system for privacy
- 💰 **One-time purchase** - Lifetime access, no subscription

#### Why This Model?

**1. Sustainable Development**
- Free version meets basic needs (75 files sufficient for most users)
- Advanced users pay to support ongoing development
- Avoid ads and data collection

**2. Fair Pricing**
- One-time purchase, no subscription
- Clear value proposition
- Pro features for power users

**3. App Store Convenience**
- One-tap download
- Auto updates
- Official support

#### Feature Comparison

| Feature | App Store Free | App Store Pro |
|---------|---------------|--------------|
| Full Encryption | ✅ | ✅ |
| Hidden Space | ✅ | ✅ |
| Disguise Interface | ✅ | ✅ |
| Dark Mode | ✅ | ✅ |
| Latest Security | ✅ | ✅ |
| **File Count** | **Up to 75** | **Unlimited** |
| **Guest Mode** | ❌ Requires Pro | ✅ |
| Access Method | ✅ One-tap Download | ✅ One-tap Download |
| Auto Updates | ✅ Auto Push | ✅ Auto Push |
| Tech Support | ✅ Official | ✅ Priority |
| **Price** | **Free** | **One-time IAP** |

> 💡 **Regular Users**: Free version sufficient for daily use (75 files)  
> 💡 **Advanced Users**: Pro version unlocks all features, one-time purchase for lifetime

#### In-App Purchase Transparency

- ✅ **No Subscription**: All IAPs are one-time purchases, lifetime access
- ✅ **No Hidden Fees**: Clear pricing, no additional charges
- ✅ **Complete Features**: Both free and Pro include core encryption
- ✅ **Zero Network Promise**: IAP validation is completely local, offline

---

### 🚀 Quick Start

[![Download on App Store](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://apps.apple.com/app/zeronet-space)

> Coming soon, stay tuned!

---

### 🛠️ Tech Stack

#### Core Technologies
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI 3.0+
- **Data Storage**: SwiftData + FileManager
- **Encryption**: CryptoKit (AES-256-GCM)
- **Password Management**: iOS Keychain + PBKDF2
- **Minimum Support**: iOS 15.0+

#### Architecture Features
- ✅ MVVM architecture pattern
- ✅ @MainActor thread safety
- ✅ Environment object dependency injection
- ✅ Modern Swift concurrency (async/await)
- ✅ Atomic operations ensure data consistency
- ✅ Concurrency control prevents race conditions

---

### 🔐 Security Design

#### Password Management
```
Storage: iOS Keychain
Hash Algorithm: SHA-256
Salt: 32-byte random (CryptoKit)
Verification Delay: 0.5s (prevent brute force)
Key Derivation: PBKDF2 (100,000 iterations)
```

#### File Encryption
```
Algorithm: AES-256-GCM
Key Derivation: PBKDF2 (100,000 iterations)
Salt: 16-byte random (unique per encryption)
IV: 12-byte random (unique per encryption)
Authentication Tag: 16-byte (prevent tampering)
Format: Salt(16) + IV(12) + Tag(16) + Ciphertext
Memory Safety: Immediate key erasure after use
```

#### Concurrency Safety
```
Main Thread: @MainActor protects UI state
Atomic Operations: NSLock protects critical data
State Management: Published properties thread-safe
Error Handling: Complete error propagation chain
```

#### Network Isolation
```
Network Permission: ❌ Not requested
Network Code: ❌ Does not exist
Third-party SDK: ❌ Zero dependencies
Cloud Service: ❌ Completely local
Analytics Tracking: ❌ Zero collection
Privacy Manifest: ✅ Provided (PrivacyInfo.xcprivacy)
```

**Verification Methods**:
- Check `PrivacyInfo.xcprivacy` - Privacy manifest provided
- Runtime monitoring - Use Charles/Wireshark to verify zero network traffic

---

### 🧪 Security Feedback
If you find security vulnerabilities:
- 📧 Please report via GitHub Issues privately (recommended)
- 💬 Or contact project maintainer directly
- 🏆 Responsible disclosure will be acknowledged in README

#### Security Update History
- **V1.2 (2025-01-17)**: Major security enhancements
  - Fixed EncryptionService key derivation vulnerability
  - Fixed KeychainService concurrency safety issues
  - Fixed AuthenticationViewModel state management vulnerability
  - Enhanced CalculatorViewModel memory safety
  - Improved error handling and propagation mechanisms



---

### ⚠️ Important Disclaimer

#### Data Security Notice

- **Password Cannot Be Recovered**: We cannot reset passwords. Forgetting password requires app uninstallation (data will be lost)
- **No Cloud Backup**: All data stored locally only. Uninstalling app or changing devices will lose data
- **Offline Use**: Complete offline means no remote data recovery
- **Please Remember Password**: Recommend using password manager to record

#### Privacy Promise

- ✅ We will **NEVER** add network features (IAP validation is completely local)
- ✅ We will **NEVER** collect user data
- ✅ We will **NEVER** add tracking or analytics
- ✅ We will **NEVER** add ads
- ✅ IAPs will **ALWAYS** be one-time purchases, never subscription-based



---

### 📊 Project Status

- **Current Version**: V1.2
- **Development Status**: ✅ Stable maintenance
- **Last Update**: 2025-01-17
- **Next Version**: V2.0 (planned)
- **App Store Status**: 📋 Preparing for submission

---

### 🗺️ Roadmap

#### V2.0 (Planned)
- [ ] Optional encrypted cloud backup (user opt-in required)
- [ ] Password recovery mechanism (based on local security questions)
- [ ] More file format support
- [ ] Batch operation optimization
- [ ] Performance optimization and memory management improvements

#### Long-term Planning
- [ ] iPad adaptation
- [ ] macOS version
- [ ] More language support
- [ ] Plugin system

---

<div align="center">

**Made with ❤️ for Privacy**

</div>
