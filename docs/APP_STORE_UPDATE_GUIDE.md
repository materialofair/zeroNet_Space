# App Store 上线更新指南（v1.1.0）

> 适用于本次 1.1.0 更新，后续版本可复用整体流程，替换"本次版本"相关内容即可。
> 前置状态：代码已推送到 `main`（`96594dd`），版本号已设为 **1.1.0 (build 6)**。

---

## 0. 本次版本内容（写更新说明和自测时用）

**新功能**
- 离开后自动锁定：设置 → 安全设置，可选 立即 / 1 分钟 / 5 分钟 / 从不（**默认立即**）
- 后台隐私遮罩：切换 App 时，多任务切换器中不再显示已解密的照片/视频/笔记

**修复**
- 修复"解锁无限导入"提示未找到产品的问题（产品 ID 回归修复，见 `3160e61`）
- 修复列表页（照片/视频/文件）删除不彻底、误触无确认的问题
- 修复照片查看器翻页时缩放状态串页的问题
- 私密笔记草稿改为 Keychain 加密存储
- 旧版本升级用户的密码凭据自动迁移（Keychain service 迁移）

**对老用户的行为变化（更新说明里必须提）**
- 升级后切出 App 再回来默认需要重新输入密码（可在 设置 → 安全设置 → 离开后自动锁定 中调整）

---

## 1. 发布前必测（❗三项都过了才允许打包）

### 1.1 升级路径实测（最重要，验证 Keychain 连续性）
1. 在真机上安装 **当前 App Store 正式版**（从 App Store 下载）
2. 设置主密码 → 导入 2-3 张照片 → 写一条私密笔记
3. **不删除 App**，用 Xcode 直接 Run（或装 TestFlight 新包）覆盖安装 1.1.0
4. 验收标准：
   - [ ] 旧密码能正常登录（没有被要求重新设置密码）
   - [ ] 之前导入的照片能正常解密查看
   - [ ] 私密笔记还在
   - ⚠️ 如果被要求"设置新密码"，**立即停止发布**，说明 Keychain 迁移未覆盖到位，回来找问题

### 1.2 IAP 沙盒实测
1. 真机登录沙盒测试账号（设置 → App Store → 沙盒账户；没有就在 App Store Connect → 用户和访问 → 沙盒测试员 里建一个）
2. 用 Xcode Run 到真机（⚠️ 确保 scheme 里 **StoreKit Configuration 选 None**，否则走的是本地 Products.storekit 而不是真实沙盒）
3. 设置页 → 点"解锁无限导入"
4. 验收标准：
   - [ ] 能弹出购买确认（显示 ASC 配置的价格，不再提示"未找到产品"）
   - [ ] 沙盒购买成功后，导入限制解除
   - [ ] 卸载重装后"恢复购买"能恢复权益

### 1.3 新功能自测
- [ ] 解锁后切到桌面再打开切换器：预览图是启动页，不是相册内容
- [ ] 默认"立即"锁定：切出再切回，要求重新登录
- [ ] 改成"从不"：切出切回保持登录
- [ ] 计算器伪装模式下（未解锁状态）切后台：切换器显示的是计算器，**不是**启动页（伪装不被遮罩暴露）
- [ ] 三个列表页长按/左滑删除：有确认弹窗，删除后重启 App 不出现"幽灵条目"

---

## 2. Xcode 打包上传

1. Xcode 打开项目，顶部设备选择 **Any iOS Device (arm64)**
2. 确认版本号：Target `ZeroNet-Space` → General → Version `1.1.0`，Build `6`（已设好，核对即可）
3. 菜单 **Product → Archive**，等待归档完成
4. Organizer 自动弹出 → 选中刚生成的 Archive → **Distribute App**
5. 选 **App Store Connect → Upload**，一路默认（自动签名、包含 symbols），点 Upload
6. 等 10-30 分钟，收到"构建版本处理完成"的邮件后进入下一步

---

## 3. App Store Connect 配置

登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 我的 App → 零网络空间：

1. 左侧点 **"+ 添加平台版本"**（或"+"新版本）→ 输入 `1.1.0`
2. **"此版本的新增内容"**（更新说明），可直接用下面的草稿：

   **中文（zh-Hans）：**
   ```
   本次更新：
   • 新增"离开后自动锁定"：切出 App 后自动锁定，可在 设置 → 安全设置 中选择立即/1分钟/5分钟/从不（默认立即，更安全）
   • 新增后台隐私保护：切换 App 时，多任务界面不再显示您的照片和笔记
   • 修复"解锁无限导入"提示未找到产品的问题
   • 删除照片/视频/文件前增加确认提示，修复删除不彻底的问题
   • 私密笔记草稿改为加密存储
   • 多项稳定性改进

   注意：升级后切出 App 会默认要求重新输入密码，可在设置中调整锁定时长。
   ```

   **English (en)：**
   ```
   What's new:
   • Auto-Lock: the app now locks when you leave it (Immediately / 1 min / 5 min / Never — configurable in Settings > Security)
   • Privacy shield: your photos and notes are no longer visible in the app switcher
   • Fixed "product not found" when unlocking Unlimited Imports
   • Delete confirmation added; fixed incomplete deletions
   • Secret note drafts are now stored encrypted
   • Stability improvements

   Note: after updating, the app locks by default when you switch away. Adjust the timeout in Settings.
   ```

3. **构建版本**：点"+"选择刚上传的 build 6
4. **App 审核信息 → 备注**，写清楚审核员如何测试（重要，见第 4 节）：
   ```
   This app is an offline privacy vault (no account system, no network).
   To review all features without a purchase:
   1. On first launch, set the DEMO password: 0.00000 (zero, dot, five
      zeros) and confirm it. Logging in with this password automatically
      unlocks all premium features (demo mode for review).
   2. Alternatively, set any password and test the "Unlimited Imports"
      non-consumable IAP (com.zeronetspace.unlimited_imports) via sandbox
      from Settings — purchases in the review environment are not charged.
   3. Calculator disguise mode: optional feature in Settings > Security.
      When enabled, the login screen looks like a calculator; entering the
      password digits followed by "=" unlocks the app.
   4. The app makes no network requests by design (offline privacy app).
   ```
5. **内购产品检查**：功能 → App 内购买项目 → 确认 `com.zeronetspace.unlimited_imports` 状态是"已批准"或随版本提交。如果 IAP 从未通过审核，需要在版本页面底部"本版本的 App 内购买项目"里**把它附加到这次提交**
6. 出口合规（加密声明）：与上一版保持一致的选择即可（App 只使用 iOS 系统自带的 CryptoKit/CommonCrypto，属于豁免范围的标准加密）

---

## 4. 关于演示模式

审核员没有你的"会员账号"可用，所以保留了演示口令：**用 `0.00000` 作为密码登录即自动解锁全部高级功能**。审核备注（3.4 节）已写明该口令，审核员可直接用它验证付费功能，也可以走沙盒购买（不扣款）双路径验证。

已知取舍：项目是开源的，这个口令对所有人可见，等于放弃对"无限导入" IAP 的防绕过保护——愿意付费支持的用户仍会付费，这是有意接受的权衡（AppConstants.swift 中有注释记录）。

---

## 5. 提交审核与发布

1. 版本页面右上角 **"添加以供审核"** → **"提交至 App 审核"**
2. 发布方式建议选 **"手动发布此版本"**（审核通过后你自己点发布，方便控制时间点）
3. 审核一般 24-48 小时。通过后点 **"发布此版本"**

---

## 6. 发布后收尾

```bash
# 给发布版本打 tag 并推送
git tag -a v1.1.0 -m "Release 1.1.0 (build 6)"
git push origin v1.1.0
```

- [ ] App Store 页面确认新版本已可下载
- [ ] 用正式包再跑一遍 1.1 节的升级路径测试（从旧版真实升级）
- [ ] 关注 ASC → App 分析 / 评分与评论，重点看有没有"升级后要重新输密码/数据丢失"类反馈（前者是预期行为，后者需要立即排查）
- [ ] 如 README 或 App Store 描述文档中提到版本号/功能列表，同步更新

---

## 常见问题

| 问题 | 处理 |
|---|---|
| 审核被拒：无法测试付费功能 | 回复审核，指引其在 Settings 中直接沙盒购买（免费）；必要时附上操作录屏 |
| 上传后 ASC 看不到构建版本 | 等处理邮件（最长 1 小时）；检查是否有合规问题邮件（如缺少出口合规声明） |
| 沙盒购买报"未找到产品" | 确认 ASC 中 IAP 状态、Bundle ID 匹配、协议税务银行信息完整；产品新建后同步需 2-24 小时 |
| 升级用户反馈"要求重设密码" | 严重问题：Keychain 迁移未命中，立即收集用户旧版本号并排查 `KeychainService` 迁移逻辑 |
