# 贡献指南 / Contributing Guide

感谢你对零网络空间项目的关注！  
Thank you for your interest in ZeroNet Space!

[中文](#中文) | [English](#english)

---

## 中文

### 👋 欢迎

零网络空间是一个个人维护的开源项目。我每周大约投入5-10小时处理社区事务，所以响应时间可能需要1-3天，请理解。

**开源的目的是建立信任，而不是追求快速迭代。**

---

### 🎯 贡献类型

我们欢迎不同类型的贡献，但有明确的优先级：

#### ✅ 立即欢迎（快速审查）

**Bug修复**
- 崩溃问题
- 功能异常
- UI显示错误
- 性能问题

**安全加固**
- 加密算法改进
- 密码管理优化
- 内存安全增强
- 并发安全修复

**性能优化**
- 启动速度
- 加密/解密性能
- 内存占用
- 电池消耗

**国际化/本地化**
- 翻译改进
- 新语言支持
- 文化适配

**文档改进**
- README优化
- 代码注释
- 技术文档
- 使用指南

#### ⚠️ 需要讨论（请先开Issue）

**新功能开发**
- 必须符合"零网络"理念
- 不能违背隐私承诺
- 需要详细的设计文档
- 需要用户需求验证

**UI/UX重大改动**
- 保持简洁原则
- 不破坏现有用户习惯
- 需要设计稿和原型

**架构调整**
- 必须有充分理由
- 需要性能和安全评估
- 需要详细的迁移计划

#### ❌ 明确拒绝

**违背核心理念的功能**
- ❌ 任何涉及网络的功能
- ❌ 云同步/云备份
- ❌ 用户账号系统
- ❌ 数据统计/分析
- ❌ 第三方SDK集成

**移除付费限制**
- ❌ 移除75文件限制
- ❌ 移除IAP检查
- 💡 注意：你可以在自己的Fork中修改，但不会被合并到主分支

**过度复杂化**
- ❌ 不必要的抽象
- ❌ 引入重型依赖
- ❌ 过度设计的架构

---

### 🚀 贡献流程

#### 1. 开始之前

**对于Bug修复和小改进**：
- 直接Fork并修复
- 提交Pull Request

**对于新功能或大改动**：
- 先开一个Issue讨论
- 等待维护者确认方向
- 再开始开发

#### 2. Fork仓库

```bash
# 1. Fork仓库到你的GitHub账号
# 2. 克隆到本地
git clone https://github.com/你的用户名/ZeroNetSpace.git
cd ZeroNetSpace

# 3. 添加上游仓库
git remote add upstream https://github.com/原作者/ZeroNetSpace.git

# 4. 创建功能分支
git checkout -b feature/your-feature-name
```

#### 3. 开发

**代码规范**：
- 遵循Swift API Design Guidelines
- 使用SwiftLint（如果配置了）
- 保持代码风格一致

**测试**：
- 确保修改不破坏现有功能
- 在真机和模拟器上测试
- 测试iOS 15.0+兼容性

**提交信息**：
```
类型: 简短描述

详细描述（可选）

- 改动点1
- 改动点2
```

类型：`fix:`, `feat:`, `perf:`, `docs:`, `style:`, `refactor:`, `test:`

#### 4. 提交Pull Request

**PR标题**：
```
[类型] 简短描述

例如：
[Fix] 修复深色模式下按钮颜色错误
[Feat] 添加法语翻译支持
[Perf] 优化文件加密性能
```

**PR描述模板**：
```markdown
## 改动说明
简要描述你的修改

## 改动类型
- [ ] Bug修复
- [ ] 新功能
- [ ] 性能优化
- [ ] 文档改进
- [ ] 其他（请说明）

## 测试情况
- [ ] 在真机上测试
- [ ] 在模拟器上测试
- [ ] 测试了iOS 15.0+兼容性
- [ ] 确认不破坏现有功能

## 截图（如果适用）
<!-- 添加截图 -->

## 相关Issue
<!-- 如果修复了某个Issue，请链接 -->
Closes #123
```

#### 5. 代码审查

- 维护者会在1-3天内审查
- 可能会要求修改
- 请耐心配合修改

#### 6. 合并

- 审查通过后会合并到主分支
- 你的名字会添加到贡献者列表
- App内致谢页也会展示（如果是重要贡献）

---

### 🏆 致谢机制

**所有贡献者都会获得**：
- ✅ README贡献者列表展示
- ✅ GitHub Release Notes提及

**重要贡献者还会获得**：
- ✅ App内"关于"页面致谢
- ✅ 特别感谢标注

**什么算重要贡献？**
- 修复关键安全漏洞
- 实现重要新功能
- 显著性能优化
- 持续活跃的贡献者

---

### 💬 社区行为准则

我们期望所有贡献者：

- ✅ 尊重他人，友善交流
- ✅ 接受建设性批评
- ✅ 专注于对项目最有利的事情
- ✅ 对其他社区成员表示同理心

不可接受的行为：
- ❌ 使用性化的语言或图像
- ❌ 人身攻击或侮辱性评论
- ❌ 骚扰行为
- ❌ 发布他人隐私信息

---

### 🔒 安全漏洞报告

如果你发现安全漏洞：

1. **不要公开Issue** - 安全问题需要私密处理
2. **通过以下方式报告**：
   - GitHub Security Advisories
   - 直接联系维护者
3. **提供详细信息**：
   - 漏洞描述
   - 复现步骤
   - 影响范围
   - 建议修复方案（如果有）

**奖励**：
- README中的安全贡献者致谢
- App内特别感谢
- 负责任披露承诺

---

### ❓ 常见问题

**Q: 我的PR什么时候会被审查？**  
A: 通常1-3天内。如果超过1周没有响应，请在PR中评论提醒。

**Q: 为什么我的新功能PR被拒绝了？**  
A: 可能的原因：
- 违背"零网络"核心理念
- 功能过于复杂
- 没有事先讨论
- 用户需求不明确

**Q: 可以添加XXX框架吗？**  
A: 原则上不引入第三方依赖。除非：
- 是系统框架（Apple官方）
- 有不可替代的功能
- 不违背隐私承诺

**Q: 我可以实现付费功能吗？**  
A: 可以提交实现，但：
- 不会移除付费检查
- Fork版本可以自行修改
- 核心功能会保持免费

**Q: 如何成为长期贡献者？**  
A: 
- 持续贡献高质量代码
- 积极参与Issue讨论
- 帮助其他贡献者
- 维护者会主动联系

---

### 📞 联系方式

- **GitHub Issues**: 最推荐的方式
- **GitHub Discussions**: 讨论和交流
- **项目维护者**: 查看GitHub Profile

---

### 🙏 感谢

感谢你愿意为零网络空间贡献力量！  
每一个贡献，无论大小，都让这个项目变得更好。

**记住我们的使命**：让每个人都能拥有一个真正安全、私密、可信的数字空间。

---

## English

### 👋 Welcome

ZeroNet Space is a personally maintained open-source project. I spend about 5-10 hours per week on community matters, so response time may take 1-3 days. Thank you for your understanding.

**The purpose of open source is to build trust, not to pursue rapid iteration.**

---

### 🎯 Contribution Types

We welcome different types of contributions with clear priorities:

#### ✅ Immediately Welcome (Fast Review)

**Bug Fixes**
- Crash issues
- Functional errors
- UI display bugs
- Performance issues

**Security Hardening**
- Encryption algorithm improvements
- Password management optimization
- Memory safety enhancements
- Concurrency safety fixes

**Performance Optimization**
- Startup speed
- Encryption/decryption performance
- Memory usage
- Battery consumption

**Internationalization/Localization**
- Translation improvements
- New language support
- Cultural adaptation

**Documentation Improvements**
- README optimization
- Code comments
- Technical documentation
- User guides

#### ⚠️ Needs Discussion (Please open Issue first)

**New Feature Development**
- Must align with "zero network" philosophy
- Cannot violate privacy promises
- Requires detailed design documentation
- Needs user requirement validation

**Major UI/UX Changes**
- Maintain simplicity principle
- Don't break existing user habits
- Requires design drafts and prototypes

**Architecture Adjustments**
- Must have sufficient justification
- Needs performance and security assessment
- Requires detailed migration plan

#### ❌ Clearly Rejected

**Features Violating Core Philosophy**
- ❌ Any network-related features
- ❌ Cloud sync/backup
- ❌ User account system
- ❌ Data analytics/tracking
- ❌ Third-party SDK integration

**Removing Payment Limits**
- ❌ Remove 75 file limit
- ❌ Remove IAP checks
- 💡 Note: You can modify in your fork, but won't be merged to main branch

**Over-complication**
- ❌ Unnecessary abstractions
- ❌ Heavy dependencies
- ❌ Over-engineered architecture

---

### 🚀 Contribution Process

#### 1. Before Starting

**For bug fixes and small improvements**:
- Fork and fix directly
- Submit Pull Request

**For new features or major changes**:
- Open an Issue for discussion first
- Wait for maintainer confirmation
- Then start development

#### 2. Fork Repository

```bash
# 1. Fork repository to your GitHub account
# 2. Clone to local
git clone https://github.com/YourUsername/ZeroNetSpace.git
cd ZeroNetSpace

# 3. Add upstream repository
git remote add upstream https://github.com/OriginalAuthor/ZeroNetSpace.git

# 4. Create feature branch
git checkout -b feature/your-feature-name
```

#### 3. Development

**Code Standards**:
- Follow Swift API Design Guidelines
- Use SwiftLint (if configured)
- Maintain consistent code style

**Testing**:
- Ensure changes don't break existing functionality
- Test on real devices and simulators
- Test iOS 15.0+ compatibility

**Commit Messages**:
```
type: Brief description

Detailed description (optional)

- Change point 1
- Change point 2
```

Types: `fix:`, `feat:`, `perf:`, `docs:`, `style:`, `refactor:`, `test:`

#### 4. Submit Pull Request

**PR Title**:
```
[Type] Brief description

Examples:
[Fix] Fix button color error in dark mode
[Feat] Add French translation support
[Perf] Optimize file encryption performance
```

**PR Description Template**:
```markdown
## Description
Brief description of your changes

## Change Type
- [ ] Bug fix
- [ ] New feature
- [ ] Performance optimization
- [ ] Documentation improvement
- [ ] Other (please specify)

## Testing
- [ ] Tested on real device
- [ ] Tested on simulator
- [ ] Tested iOS 15.0+ compatibility
- [ ] Confirmed no breaking changes

## Screenshots (if applicable)
<!-- Add screenshots -->

## Related Issues
<!-- If fixing an issue, please link -->
Closes #123
```

#### 5. Code Review

- Maintainer will review within 1-3 days
- May request changes
- Please cooperate patiently

#### 6. Merge

- Will merge to main branch after approval
- Your name added to contributors list
- App acknowledgments page (for significant contributions)

---

### 🏆 Acknowledgment Mechanism

**All contributors receive**:
- ✅ README contributors list display
- ✅ GitHub Release Notes mention

**Significant contributors also receive**:
- ✅ In-app "About" page acknowledgment
- ✅ Special thanks notation

**What counts as significant contribution?**
- Fixing critical security vulnerabilities
- Implementing important new features
- Significant performance optimization
- Sustained active contribution

---

### 💬 Community Code of Conduct

We expect all contributors to:

- ✅ Respect others, communicate kindly
- ✅ Accept constructive criticism
- ✅ Focus on what's best for the project
- ✅ Show empathy to other community members

Unacceptable behavior:
- ❌ Sexualized language or imagery
- ❌ Personal attacks or insulting comments
- ❌ Harassment
- ❌ Publishing others' private information

---

### 🔒 Security Vulnerability Reporting

If you find security vulnerabilities:

1. **Don't open public Issues** - Security issues need private handling
2. **Report via**:
   - GitHub Security Advisories
   - Direct contact with maintainer
3. **Provide details**:
   - Vulnerability description
   - Reproduction steps
   - Impact scope
   - Suggested fix (if any)

**Rewards**:
- Security contributor acknowledgment in README
- Special thanks in app
- Responsible disclosure commitment

---

### ❓ FAQ

**Q: When will my PR be reviewed?**  
A: Usually within 1-3 days. If no response after 1 week, please comment on PR as reminder.

**Q: Why was my new feature PR rejected?**  
A: Possible reasons:
- Violates "zero network" core philosophy
- Feature too complex
- No prior discussion
- User requirement unclear

**Q: Can I add XXX framework?**  
A: Generally no third-party dependencies. Unless:
- System framework (Apple official)
- Irreplaceable functionality
- Doesn't violate privacy promises

**Q: Can I implement paid features?**  
A: Yes, but:
- Won't remove payment checks
- Fork versions can self-modify
- Core features remain free

**Q: How to become long-term contributor?**  
A: 
- Consistently contribute quality code
- Actively participate in Issue discussions
- Help other contributors
- Maintainer will contact proactively

---

### 📞 Contact

- **GitHub Issues**: Most recommended
- **GitHub Discussions**: Discussion and communication
- **Project Maintainer**: See GitHub Profile

---

### 🙏 Thank You

Thank you for your willingness to contribute to ZeroNet Space!  
Every contribution, large or small, makes this project better.

**Remember our mission**: Let everyone have a truly secure, private, and trustworthy digital space.

---

<div align="center">

**简单 · 真诚 · 开源 · 透明**

**Simple · Honest · Open Source · Transparent**

</div>
