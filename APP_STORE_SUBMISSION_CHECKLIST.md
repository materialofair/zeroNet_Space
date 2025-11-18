# 📱 ZeroNet-Space App Store 提交检查清单

## ✅ 第一部分：安全修复验证（上架前必须完成）

### 1. 伪装模式密码加密存储 ✅
- [ ] 打开设置 → 伪装模式
- [ ] 设置伪装密码（如：3.14159）
- [ ] 完全退出应用
- [ ] 重启应用，启用伪装模式
- [ ] 在计算器中输入设置的密码序列并按"="
- [ ] **预期结果**：成功解锁进入应用
- [ ] **验证**：查看 Xcode 控制台日志，应显示"从 Keychain 加载密码"而非"从 UserDefaults"

### 2. 密码尝试限制 ✅
- [ ] 登出应用
- [ ] 故意输入错误密码 1 次
- [ ] **预期结果**：显示"密码错误，还可尝试 4 次"
- [ ] 继续输入错误密码 4 次
- [ ] **预期结果**：显示"密码错误次数过多，已锁定 5 分钟"
- [ ] 等待5分钟或重启应用（锁定应该持久化）
- [ ] **预期结果**：输入正确密码后，失败次数重置

### 3. 会话密码内存清理 ✅
- [ ] 成功登录应用
- [ ] 登出应用
- [ ] **验证**：查看 Xcode 控制台日志，应显示"密码内存已安全清理"

---

## ✅ 第二部分：核心功能测试（真机测试）

### 基础流程测试
- [ ] **首次启动** → 设置主密码（纯数字如：123456 或包含字母如：Abc123）
- [ ] **导入照片** → 从相册导入 5 张照片
- [ ] **导入视频** → 从相册导入 1 个视频
- [ ] **查看媒体** → 点击照片/视频查看详情
- [ ] **导出媒体** → 导出 1 张照片到相册
- [ ] **删除媒体** → 删除 1 张照片
- [ ] **退出登录** → 登出后重新登录
- [ ] **修改密码** → 在设置中修改主密码（测试文件是否可解密）

### 伪装模式测试
- [ ] 设置纯数字主密码（如：123456）
- [ ] 启用伪装模式 → 密码自动设置为主密码
- [ ] 重启应用 → 看到计算器界面
- [ ] 输入密码序列 → 成功解锁
- [ ] 测试主密码包含字母的情况（应提示需要修改密码）

### 访客模式测试（需要内购）
- [ ] 购买无限导入功能
- [ ] 设置访客密码（6-8位纯数字，如：666666）
- [ ] 登出，使用访客密码登录
- [ ] **预期结果**：只能浏览，无法导入/导出/删除

### 边界情况测试
- [ ] **大文件测试** → 导入 100MB+ 的视频（应该成功）
- [ ] **超大文件测试** → 尝试导入 500MB+ 的视频（应提示文件过大）
- [ ] **快速操作** → 快速连续导入 5 个文件（测试并发）
- [ ] **后台切换** → 切换到后台 → 强制杀死进程 → 重启（测试数据持久化）
- [ ] **磁盘空间** → 在存储空间不足时尝试导入（应提示空间不足）

---

## ✅ 第三部分：崩溃和性能测试

### 崩溃测试
- [ ] 连续快速点击各个功能按钮
- [ ] 旋转设备屏幕（横屏/竖屏切换）
- [ ] 在导入进行中强制退出应用
- [ ] 在加密进行中强制退出应用
- [ ] **目标**：无崩溃，所有操作流畅

### 性能测试
- [ ] 导入 100 个媒体文件 → 查看加密速度
- [ ] 浏览包含 100 个媒体的图库 → 查看滑动流畅度
- [ ] 打开大尺寸图片（4K+） → 查看加载速度
- [ ] 播放高清视频 → 查看播放流畅度
- [ ] **目标**：所有操作在 3 秒内完成，无卡顿

---

## ✅ 第四部分：App Store 提交准备

### 必需文件
- [x] **PrivacyInfo.xcprivacy** → 已创建，位于项目根目录
- [ ] **隐私政策页面** → 创建并托管（见下方模板）
- [ ] **应用截图** → 至少 3 张（见截图要求）
- [ ] **应用描述** → 中英文各一份（见文案模板）
- [ ] **关键词** → 中英文（见关键词建议）

### 截图要求
需要以下尺寸的截图（在真机或模拟器上截取）：
- [ ] iPhone 6.7" (iPhone 15 Pro Max / 14 Pro Max) - 至少 3 张
- [ ] iPhone 6.5" (iPhone 14 Plus / 11 Pro Max) - 至少 3 张

建议截图内容：
1. 登录界面 - 展示密码设置
2. 图库界面 - 展示媒体预览
3. 设置界面 - 展示安全特性（伪装模式、访客模式）

### 应用信息填写
- [ ] **应用名称**：ZeroNet Space
- [ ] **副标题**：完全离线的私密相册
- [ ] **分级**：4+ （无限制内容）
- [ ] **类别**：工具（主类别）、摄影与录像（次类别）
- [ ] **支持 URL**：你的支持网站或 GitHub 链接
- [ ] **隐私政策 URL**：必需！（见下方生成方法）

---

## 📝 附件：文案模板

### 中文应用描述
```
ZeroNet Space - 真正零网络的私密相册

【核心特性】
✅ 完全离线 - 无需网络，无需账号，数据永不上传
✅ 军用级加密 - AES-256-GCM 加密，PBKDF2 密钥派生
✅ 伪装模式 - 应用外观显示为计算器，秘密保护隐私
✅ 访客模式 - 设置访客密码，限制访客权限

【安全保障】
• 所有照片和视频都经过加密存储在本地
• 无需联网，完全杜绝数据泄露风险
• 密码仅存储在设备 Keychain，绝不上传
• 支持 Face ID / Touch ID 快速解锁

【适用场景】
• 保护私人照片和视频
• 存储敏感文档和文件
• 防止他人偷看相册
• 离线安全存储

【免费功能】
• 导入 30 个媒体文件
• 所有加密和安全功能
• 伪装模式和访客模式

【内购说明】
• 一次性购买，永久解锁无限导入
• 无订阅，无广告，无隐藏费用
```

### English App Description
```
ZeroNet Space - Truly Offline Private Album

【Core Features】
✅ Completely Offline - No network required, no account needed, data never uploaded
✅ Military-Grade Encryption - AES-256-GCM encryption, PBKDF2 key derivation
✅ Disguise Mode - App appears as calculator, secretly protecting your privacy
✅ Guest Mode - Set guest password with limited permissions

【Security Guarantee】
• All photos and videos encrypted and stored locally
• No network connection required, zero data leak risk
• Passwords stored only in device Keychain, never uploaded
• Support Face ID / Touch ID for quick unlock

【Use Cases】
• Protect private photos and videos
• Store sensitive documents and files
• Prevent others from peeking at your album
• Offline secure storage

【Free Features】
• Import 30 media files
• All encryption and security features
• Disguise mode and guest mode

【In-App Purchase】
• One-time purchase for unlimited import
• No subscription, no ads, no hidden fees
```

### 关键词建议
- **中文**：私密相册,加密相册,安全存储,照片加密,离线相册,隐私保护,伪装应用,密码相册
- **英文**：private album,encrypted photos,secure storage,photo vault,offline album,privacy protection,disguise app,password photos

---

## 🌐 附件：隐私政策生成

### 快速方案：使用 GitHub Pages

1. 在项目中创建 `docs/privacy-policy.html` 文件：

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZeroNet Space 隐私政策</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; line-height: 1.6; }
        h1 { color: #333; }
        h2 { color: #555; margin-top: 30px; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>ZeroNet Space 隐私政策</h1>
    <p><strong>最后更新日期：2024年11月</strong></p>

    <h2>1. 数据收集</h2>
    <p>ZeroNet Space <strong>不收集任何用户数据</strong>。我们的应用：</p>
    <ul>
        <li>不需要网络连接</li>
        <li>不需要账号注册</li>
        <li>不上传任何用户文件</li>
        <li>不使用任何分析工具</li>
        <li>不包含第三方 SDK</li>
    </ul>

    <h2>2. 数据存储</h2>
    <p>所有数据都存储在您的设备上：</p>
    <ul>
        <li>照片和视频：加密存储在应用沙盒中</li>
        <li>密码：使用系统 Keychain 安全存储</li>
        <li>设置：使用 UserDefaults 本地存储</li>
    </ul>

    <h2>3. 数据安全</h2>
    <p>我们使用行业标准的加密技术：</p>
    <ul>
        <li>AES-256-GCM 加密算法</li>
        <li>PBKDF2 密钥派生（10万次迭代）</li>
        <li>iOS Keychain 安全存储</li>
    </ul>

    <h2>4. 第三方服务</h2>
    <p>本应用<strong>不使用任何第三方服务</strong>，包括但不限于：</p>
    <ul>
        <li>云存储服务</li>
        <li>分析服务</li>
        <li>广告服务</li>
        <li>社交媒体集成</li>
    </ul>

    <h2>5. 联系我们</h2>
    <p>如有隐私问题，请联系：your-email@example.com</p>

    <hr>

    <h1>ZeroNet Space Privacy Policy</h1>
    <p><strong>Last Updated: November 2024</strong></p>

    <h2>1. Data Collection</h2>
    <p>ZeroNet Space <strong>does not collect any user data</strong>. Our app:</p>
    <ul>
        <li>Does not require network connection</li>
        <li>Does not require account registration</li>
        <li>Does not upload any user files</li>
        <li>Does not use any analytics tools</li>
        <li>Does not include third-party SDKs</li>
    </ul>

    <h2>2. Data Storage</h2>
    <p>All data is stored on your device:</p>
    <ul>
        <li>Photos and videos: Encrypted in app sandbox</li>
        <li>Passwords: Securely stored in system Keychain</li>
        <li>Settings: Locally stored in UserDefaults</li>
    </ul>

    <h2>3. Data Security</h2>
    <p>We use industry-standard encryption:</p>
    <ul>
        <li>AES-256-GCM encryption</li>
        <li>PBKDF2 key derivation (100,000 iterations)</li>
        <li>iOS Keychain secure storage</li>
    </ul>

    <h2>4. Third-Party Services</h2>
    <p>This app <strong>does not use any third-party services</strong>, including:</p>
    <ul>
        <li>Cloud storage</li>
        <li>Analytics</li>
        <li>Advertising</li>
        <li>Social media integration</li>
    </ul>

    <h2>5. Contact Us</h2>
    <p>For privacy inquiries, contact: your-email@example.com</p>
</body>
</html>
```

2. 启用 GitHub Pages：
   - 在 GitHub 仓库设置中启用 Pages
   - 选择 `docs` 目录作为源
   - 隐私政策 URL：`https://yourusername.github.io/ZeroNet-Space/privacy-policy.html`

---

## ✅ 最终提交前检查

### 代码检查
- [ ] 移除所有 `print()` 调试语句（或改为生产模式下不输出）
- [ ] 移除所有 `// TODO` 和 `// FIXME` 注释
- [ ] 检查是否有硬编码的测试数据
- [ ] 确认没有暴露的 API Key 或敏感信息

### 版本信息
- [ ] **版本号**：1.0.0
- [ ] **Build 号**：1
- [ ] **最低 iOS 版本**：iOS 15.0

### 提交步骤
1. [ ] Xcode → Product → Archive
2. [ ] Validate App（验证无错误）
3. [ ] Distribute App → App Store Connect
4. [ ] 等待处理完成（通常5-15分钟）
5. [ ] 在 App Store Connect 填写应用信息
6. [ ] 添加截图和描述
7. [ ] 提交审核

### 审核预计
- **处理时间**：24-48 小时
- **审核时间**：1-3 天
- **总计**：2-5 天

---

## 🎉 上架后工作

### 监控指标
- [ ] 崩溃率 < 1%
- [ ] 用户评分 > 4.0
- [ ] 性能指标正常

### 用户反馈
- [ ] 及时回复用户评论
- [ ] 收集功能改进建议
- [ ] 修复报告的 bug

### 版本更新
- [ ] 规划 v1.1 功能（生物识别、云备份等）
- [ ] 持续优化性能
- [ ] 添加更多语言支持

---

**祝您上架成功！🚀**
