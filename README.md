# 零网络空间 / ZeroNet Space

<div align="center">

**真正的离线隐私空间 | 100%开源 | 零网络 | 零追踪**

[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+-lightgrey.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![Security](https://img.shields.io/badge/Security-AES--256--GCM-green.svg)](https://en.wikipedia.org/wiki/Galois/Counter_Mode)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

[English](#english) | [中文](#中文)

</div>

---
## English

### 📖 About

ZeroNet Space is a **fully open-source** iOS privacy protection app.

**Our Promises**:
- ✅ **Zero Network**: Code-level network blocking
- ✅ **Zero Tracking**: No SDK, ads, analytics, or cloud backup
- ✅ **Zero Account**: No registration, login, or data collection
- ✅ **Local Encryption**: AES-256-GCM with PBKDF2 key derivation
- ✅ **100% Open Source**: All code is public and auditable

**Core Philosophy**: Your data belongs to you alone, not to be uploaded, analyzed, or tracked.

---

### 💡 Why Open Source?

**Simple and honest answer**:

> **To build trust.**

Many apps claim "zero network" and "zero tracking", but users can't verify.  
I chose open source so anyone can inspect the code and confirm we actually deliver on our promises.

**Open source is not about being free, it's about being transparent.**

You can:
- 📖 Review all source code to verify "truly no network code"
- 🔍 Inspect encryption implementation to ensure data security
- 🛡️ Audit privacy protection mechanisms
- 🧪 Compile and run yourself, have complete control

If you find any suspicious code, please open an issue on GitHub.

---

### 🔓 Fork Policy

We **welcome and allow** anyone to fork this project for modification, learning, and research.

#### ✅ What You Can Do

- Fork and compile the code for personal use
- Modify code to meet your needs
- Learn iOS development and privacy protection techniques
- Submit Pull Requests to improve the project
- Create derivative projects (must comply with GPL-3.0)

#### ⚠️ Only One Requirement

**Please do not use the "ZeroNet Space" brand name and logo in fork versions.**

**Why?**
- Prevent user confusion between official and fork versions
- Ensure users know which version they're using
- Protect brand from misuse

**How to comply?**
- ✅ "XXX based on ZeroNet Space"
- ✅ "Inspired by ZeroNet Space"
- ❌ "ZeroNet Space Enhanced"
- ❌ "ZeroNet Space Pro"

For detailed trademark usage guidelines, see [TRADEMARK.md](TRADEMARK.md).

---

### 🏪 App Store Official Version

#### Why App Store version if open source?

**Two reasons**:

**1. Convenience**
- Self-compilation requires:
  - Download Xcode (8GB+)
  - Learn iOS development
  - Apple Developer account ($99/year)
  - Re-sign every 7 days (free certificate)

- App Store version:
  - One-tap download
  - Auto updates
  - Official technical support

**2. Sustainable Development**
- Open source projects need ongoing maintenance
- Paid version supports long-term development
- Avoid adding ads or collecting data

#### Pricing Model

**Free Version**:
- ✅ Full encryption features (AES-256-GCM)
- ✅ Hidden space
- ✅ Disguise interface
- ✅ Dark mode
- ✅ All core security features
- ⚠️ **File limit: Up to 75 files**

**Pro Version ($2.99 one-time)**:
- 🔓 **Unlimited file storage**
- 🔓 **Guest Mode** (dual password system)
- 💰 **Lifetime access, no subscription**

> 💡 **Choice is yours**: Pay to support development, or compile for free yourself.

---

### 🌟 Core Features

#### Basic Features
- 🔐 **Password Protection** - 6-8 digit strong password with biometric support
- 📸 **Encrypted Media Storage** - Photos, videos, documents with AES-256-GCM
- 📁 **Folder Management** - Custom folders and tag system
- 🎬 **Media Preview** - Fullscreen photo viewer, video player, document preview

#### Advanced Privacy (V1.2)
- 👥 **Guest Mode** - Dual password system for temporary access
- 🔒 **Hidden Space** - Secret notes and sensitive files area
- 🧮 **Disguise Interface** - Calculator disguise mode
- 🌓 **Dark Mode** - Complete light/dark theme support
- 🌍 **Internationalization** - Full English and Simplified Chinese support

#### Security Features
- 🛡️ **App Restart Authentication** - Prevent unauthorized access
- 🔐 **PBKDF2 Key Derivation** - 100,000 iterations against brute force
- 🔒 **Thread Safety Protection** - @MainActor ensures safe state management
- 🧵 **Concurrent Access Control** - NSLock protects critical operations
- 🗑️ **Secure Deletion** - Thoroughly wipes encrypted data

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

#### Network Isolation Verification
```
Network Permission: ❌ Not requested
Network Code: ❌ Does not exist (verify in source)
Third-party SDK: ❌ Zero dependencies
Cloud Service: ❌ Completely local
Analytics Tracking: ❌ Zero collection
Privacy Manifest: ✅ Provided (PrivacyInfo.xcprivacy)
```

**Verification Methods**:
- 🔍 View source code - Search for `URLSession`, `Alamofire`, `network requests`
- 📄 Check `PrivacyInfo.xcprivacy` - Privacy manifest file
- 🛠️ Runtime monitoring - Use Charles/Wireshark to verify zero traffic

---

### 🛠️ Tech Stack

#### Core Technologies
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI 3.0+
- **Data Storage**: SwiftData + FileManager
- **Encryption**: CryptoKit (AES-256-GCM)
- **Password Management**: iOS Keychain + PBKDF2
- **Minimum Support**: iOS 17.0+

#### Compatible Devices
- ✅ iPhone XS and newer (iPhone XS, XS Max, XR, 11, 12, 13, 14, 15, 16)
- ✅ iPad (6th generation) and newer
- ✅ iPad Air 2 and newer
- ✅ iPad mini 4 and newer

#### Architecture Features
- ✅ MVVM architecture pattern
- ✅ @MainActor thread safety
- ✅ Environment object dependency injection
- ✅ Modern Swift concurrency (async/await)
- ✅ Atomic operations ensure consistency

---

### 🤝 Contributing

We welcome community contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

#### Welcome Contribution Types

✅ **Immediately Welcome**:
- Bug fixes
- Performance optimization
- Security hardening
- Internationalization/translation
- Documentation improvements

⚠️ **Need Discussion**:
- New feature development
- Major UI/UX changes
- Architecture adjustments

❌ **Clearly Rejected**:
- Any network-related features
- Removing payment limits (can modify in your fork)
- Features violating "zero network" philosophy

#### How to Contribute

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

### 🏆 Acknowledgments

Thanks to everyone who contributes to this project!

**Contributors**:
<!-- Contributors will be automatically added here -->
- Waiting for the first contributor...

**Special Thanks**:
- Apple CryptoKit team - Secure encryption framework
- SwiftUI community - Modern UI development
- All users who provided feedback and suggestions

---

### 🔒 Security Feedback

If you find security vulnerabilities:

1. **Please do not disclose publicly** - Report privately first
2. **Contact via**:
   - GitHub Issues (use "Security" label)
   - Project maintainer (see GitHub Profile)
3. **Responsible Disclosure Rewards**:
   - Public acknowledgment in README
   - Display in app acknowledgments page

---

### 📄 License

This project is licensed under **GPL-3.0** - see [LICENSE](LICENSE) file.

#### GPL-3.0 Simple Explanation

- ✅ Free to use, modify, and distribute
- ✅ Can be used commercially
- ⚠️ **Modified code must be open source**
- ⚠️ **Derivative works must use GPL-3.0**

For detailed license terms, see LICENSE file.

---

### ⚠️ Important Disclaimer

#### Data Security Notice

- **Password Cannot Be Recovered** - Cannot reset password, forgetting requires app uninstallation
- **No Cloud Backup** - All data stored locally only, uninstalling loses data
- **Offline Use** - Complete offline means no remote data recovery
- **Please Remember Password** - Recommend using password manager

#### Privacy Promise

- ✅ We will **NEVER** add network features
- ✅ We will **NEVER** collect user data
- ✅ We will **NEVER** add tracking or analytics
- ✅ We will **NEVER** add ads
- ✅ **Code will always be open source, monitored by community**

---

### 🚀 Quick Start

#### Use App Store Official Version (Recommended)

[![Download on App Store](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://apps.apple.com/us/app/zeronet-space/id6755504480)

#### Compile Yourself (Advanced Users)

```bash
# 1. Clone repository
git clone https://github.com/YourUsername/ZeroNetSpace.git
cd ZeroNetSpace

# 2. Open with Xcode
open ZeroNetSpace.xcodeproj

# 3. Select your development team (requires Apple ID)
# 4. Select device or simulator
# 5. Click run (⌘R)
```

**Note**:
- Requires Xcode 15.0+
- Requires macOS 13.0+ (Ventura)
- Real device requires Apple Developer account (free or paid)

---

### 📊 Project Status

- **Current Version**: V1.2
- **Development Status**: ✅ Stable maintenance
- **Last Update**: 2025-01-17
- **Open Source Date**: 2025-01-18
- **Next Version**: V2.0 (planned)

---

### 🗺️ Roadmap

#### V1.2 ✅ Completed (2025-01-17)
- ✅ Guest Mode (dual password system)
- ✅ Hidden Space
- ✅ Disguise Interface
- ✅ PBKDF2 key derivation
- ✅ Major security enhancements

#### V2.0 🚧 Planned
- [ ] Folder secondary password
- [ ] Self-destruct lock (multiple wrong passwords)
- [ ] Private notes (Markdown support)
- [ ] Encrypted file search
- [ ] Performance optimization

#### V3.0 💡 Long-term
- [ ] iPad support
- [ ] macOS version
- [ ] More language support
- [ ] Offline password manager
- [ ] Offline document wallet

---

### 💬 Community & Support

- **GitHub Issues**: Report bugs or feature requests
- **GitHub Discussions**: Discuss and communicate
- **App Store Rating**: Support project development

---

### 📈 Project Stats

- **Lines of Code**: ~5,000 lines Swift
- **Files**: ~40 Swift files
- **Dependencies**: Zero third-party
- **Test Coverage**: Planned

---

<div align="center">

**Made with ❤️ for Privacy**

**Open Source · Transparent · Trustworthy**

</div>

---

## 中文

### 📖 关于项目

零网络空间是一款**完全开源**的iOS隐私保护应用。

**我们承诺**：
- ✅ **零网络**：代码级阻断所有网络请求
- ✅ **零追踪**：不含任何SDK、广告、统计、云备份
- ✅ **零账号**：不注册、不登录、不收集隐私数据
- ✅ **本地加密**：AES-256-GCM军用级加密，密钥仅存本地Keychain
- ✅ **100%开源**：所有代码公开透明，接受社区审查

**核心理念**：你的数据应该只属于你自己，不应该被上传、分析或追踪。

---

### 💡 为什么开源？

**简单真诚的答案**：

> **建立信任。**

很多应用都声称"零网络"、"零追踪"，但用户无法验证。  
我选择开源，是为了让任何人都可以检查代码，确认我们真的做到了承诺。

**开源不是为了免费，而是为了透明。**

你可以：
- 📖 查看所有源代码，验证"真的没有网络代码"
- 🔍 检查加密实现，确认数据安全
- 🛡️ 审查隐私保护机制
- 🧪 自己编译运行，完全掌控

如果你发现任何可疑代码，欢迎在GitHub提Issue。

---

### 🔓 Fork 政策

我们**欢迎并允许**任何人Fork这个项目进行修改、学习、研究。

#### ✅ 你可以做什么

- Fork代码并自己编译使用
- 修改代码满足个人需求
- 学习iOS开发和隐私保护技术
- 提交Pull Request改进项目
- 基于此代码创建衍生项目（需遵守GPL-3.0）

#### ⚠️ 唯一的要求

**请不要在Fork版本中使用"零网络空间"品牌名称和Logo。**

**为什么？**
- 防止用户混淆官方版本和Fork版本
- 确保用户知道他们使用的是哪个版本
- 保护品牌不被滥用

**如何做？**
- ✅ "基于零网络空间开发的XXX"
- ✅ "灵感来自零网络空间"
- ❌ "零网络空间增强版"
- ❌ "零网络空间Pro"

详细的商标使用指南请查看 [TRADEMARK.md](TRADEMARK.md)。

---

### 🏪 App Store 官方版本

#### 为什么开源还有App Store版本？

**两个原因**：

**1. 便利性**
- 自己编译需要：
  - 下载Xcode（8GB+）
  - 学习iOS开发
  - Apple开发者账号（$99/年）
  - 每7天重新签名（免费证书）

- App Store版本：
  - 一键下载
  - 自动更新
  - 官方技术支持

**2. 可持续开发**
- 开源项目需要持续维护
- 付费版本支持项目长期发展
- 避免添加广告或收集数据

#### 定价模式

**免费版**：
- ✅ 完整的加密功能（AES-256-GCM）
- ✅ 隐藏空间
- ✅ 伪装界面
- ✅ 深色模式
- ✅ 所有核心安全功能
- ⚠️ **文件数量限制：最多75个文件**

**Pro版（$2.99一次性买断）**：
- 🔓 **无限文件存储**
- 🔓 **访客模式**（双密码体系）
- 💰 **永久使用，无订阅**

> 💡 **选择权在你手里**：可以付费支持开发，也可以自己编译免费使用。

---

### 🌟 核心功能

#### 基础功能
- 🔐 **密码保护** - 6-8位强密码，支持生物识别（Face ID/Touch ID）
- 📸 **媒体加密存储** - 照片、视频、文档全部AES-256-GCM加密
- 📁 **文件夹管理** - 自定义文件夹和标签系统
- 🎬 **媒体预览** - 全屏查看照片、播放视频、预览文档

#### 高级隐私功能（V1.2）
- 👥 **访客模式** - 双密码体系，临时访问不暴露核心隐私
- 🔒 **隐藏空间** - 私密笔记和敏感文件的隐藏区域
- 🧮 **伪装界面** - 计算器伪装模式，保护隐私
- 🌓 **深色模式** - 完整的深浅色主题支持
- 🌍 **国际化** - 完整支持简体中文和英文

#### 安全特性
- 🛡️ **应用重启强制认证** - 防止未授权访问
- 🔐 **PBKDF2密钥派生** - 100,000次迭代，防止暴力破解
- 🔒 **线程安全保护** - @MainActor确保状态管理安全
- 🧵 **并发访问控制** - NSLock保护关键操作
- 🗑️ **安全删除** - 文件删除后彻底清除加密数据

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

#### 网络隔离验证
```
网络权限: ❌ 未请求
网络代码: ❌ 不存在（可查看源码验证）
第三方SDK: ❌ 零依赖
云服务: ❌ 完全本地
统计追踪: ❌ 零收集
隐私清单: ✅ 已提供（PrivacyInfo.xcprivacy）
```

**验证方式**：
- 🔍 查看源代码 - 搜索 `URLSession`、`Alamofire`、`网络请求`
- 📄 检查 `PrivacyInfo.xcprivacy` - 隐私清单文件
- 🛠️ 运行时监控 - 使用Charles/Wireshark验证零网络流量

---

### 🛠️ 技术栈

#### 核心技术
- **语言**: Swift 5.9
- **UI框架**: SwiftUI 3.0+
- **数据存储**: SwiftData + FileManager
- **加密算法**: CryptoKit (AES-256-GCM)
- **密码管理**: iOS Keychain + PBKDF2
- **最低支持**: iOS 17.0+

#### 兼容设备
- ✅ iPhone XS 及以上（iPhone XS, XS Max, XR, 11, 12, 13, 14, 15, 16）
- ✅ iPad（第6代）及以上
- ✅ iPad Air 2 及以上
- ✅ iPad mini 4 及以上

#### 架构特点
- ✅ MVVM架构模式
- ✅ @MainActor线程安全
- ✅ 环境对象依赖注入
- ✅ 现代Swift并发（async/await）
- ✅ 原子操作保证数据一致性

---

### 🤝 贡献指南

我们欢迎社区贡献！详细的贡献指南请查看 [CONTRIBUTING.md](CONTRIBUTING.md)。

#### 欢迎的贡献类型

✅ **立即欢迎**：
- Bug修复
- 性能优化
- 安全加固
- 国际化翻译
- 文档改进

⚠️ **需要讨论**：
- 新功能开发
- UI/UX重大改动
- 架构调整

❌ **明确拒绝**：
- 任何涉及网络的功能
- 移除付费限制（Fork后可自行修改）
- 违背"零网络"理念的功能

#### 如何贡献

1. Fork 这个仓库
2. 创建你的功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

---

### 🏆 致谢

感谢所有为这个项目做出贡献的人！

**贡献者列表**：
<!-- 贡献者将自动添加到这里 -->
- 等待第一位贡献者...

**特别感谢**：
- Apple CryptoKit 团队 - 提供安全的加密框架
- SwiftUI 社区 - 现代化的UI开发
- 所有提供反馈和建议的用户

---

### 🔒 安全反馈

如果你发现安全漏洞：

1. **请不要公开披露** - 先私密报告
2. **通过以下方式联系**：
   - GitHub Issues（使用"Security"标签）
   - 项目维护者（详见GitHub Profile）
3. **负责任披露奖励**：
   - 在README中公开致谢
   - App内致谢页展示

---

### 📄 许可证

本项目采用 **GPL-3.0** 许可证 - 详见 [LICENSE](LICENSE) 文件。

#### GPL-3.0 简单解释

- ✅ 可以自由使用、修改、分发
- ✅ 可以用于商业目的
- ⚠️ **修改后的代码必须开源**
- ⚠️ **衍生作品必须使用GPL-3.0**

详细许可证条款请查看 LICENSE 文件。

---

### ⚠️ 重要声明

#### 数据安全提示

- **忘记密码无法恢复** - 无法重置密码，忘记密码需要卸载应用
- **无云备份** - 所有数据仅存储本地，卸载应用会丢失数据
- **离线使用** - 完全不联网意味着无法远程恢复数据
- **请务必记住密码** - 建议使用密码管理器记录

#### 隐私承诺

- ✅ 我们**永远不会**添加网络功能
- ✅ 我们**永远不会**收集用户数据
- ✅ 我们**永远不会**添加追踪或统计
- ✅ 我们**永远不会**添加广告
- ✅ **代码永远开源，接受社区监督**

---

### 🚀 快速开始

#### 使用 App Store 官方版本（推荐）

[![Download on App Store](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://apps.apple.com/us/app/zeronet-space/id6755504480)

#### 自己编译（高级用户）

```bash
# 1. 克隆仓库
git clone https://github.com/你的用户名/ZeroNetSpace.git
cd ZeroNetSpace

# 2. 使用Xcode打开
open ZeroNetSpace.xcodeproj

# 3. 选择你的开发团队（需要Apple ID）
# 4. 选择真机或模拟器
# 5. 点击运行（⌘R）
```

**注意**：
- 需要 Xcode 15.0+
- 需要 macOS 13.0+ (Ventura)
- 真机运行需要 Apple 开发者账号（免费或付费均可）

---

### 📊 项目状态

- **当前版本**: V1.2
- **开发状态**: ✅ 稳定维护中
- **最后更新**: 2025-01-17
- **开源日期**: 2025-01-18
- **下个版本**: V2.0（计划中）

---

### 🗺️ 路线图

#### V1.2 ✅ 已完成（2025-01-17）
- ✅ 访客模式（双密码体系）
- ✅ 隐藏空间
- ✅ 伪装界面
- ✅ PBKDF2密钥派生
- ✅ 重大安全增强

#### V2.0 🚧 计划中
- [ ] 文件夹二级密码
- [ ] 自毁锁定（多次密码错误）
- [ ] 私密笔记（Markdown支持）
- [ ] 文件加密搜索
- [ ] 性能优化

#### V3.0 💡 长期规划
- [ ] iPad 适配
- [ ] macOS 版本
- [ ] 更多语言支持
- [ ] 离线密码本
- [ ] 离线证件钱包

---

### 💬 社区与支持

- **GitHub Issues**: 报告Bug或功能请求
- **GitHub Discussions**: 讨论和交流
- **App Store评分**: 支持项目发展

---

### 📈 项目数据

- **代码行数**: ~5,000行 Swift
- **文件数**: ~40个Swift文件
- **依赖**: 零第三方依赖
- **测试覆盖**: 计划中

---

