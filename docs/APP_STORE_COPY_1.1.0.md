# App Store 文案（v1.1.0）

> 提审 1.1.0 时直接复制到 App Store Connect 对应字段。
> 推广文本（Promotional Text）上限 170 字符，修改无需重新审核。

---

## 简体中文（zh-Hans）

### 推广文本（Promotional Text）

**推荐版：**

> 你的照片永远不离开手机。零网络、AES-256 加密、计算器伪装，新增离开自动锁定与后台隐私遮罩。100% 开源，代码可审计。

**备选版（更短）：**

> 一个"没有能力偷看你"的私密相册：零网络、零追踪、AES-256 加密。新增自动锁定。100% 开源。

### 此版本的新增内容（What's New）

```
零网络空间 1.1.0 —— 迄今最重要的一次隐私升级。

新增
• 离开后自动锁定：切出 App 后金库自动上锁。可在 设置 → 安全设置 中选择
  立即 / 1 分钟 / 5 分钟 / 从不（默认立即，更安全）。
• 后台隐私遮罩：切换 App 时，多任务界面不再显示你的照片、视频和笔记，
  系统截取的快照看不到任何私密内容。

改进
• 删除照片/视频/文件前增加确认提示，并确保加密数据从设备上彻底清除。
• 私密笔记草稿改为加密存储。
• 照片浏览更流畅：翻页时不再残留上一张的缩放状态。

修复
• 修复"解锁无限导入"提示未找到产品的问题。
• 修复已删除条目偶尔重新出现在相册中的问题。

小提示：本次更新后，切出 App 会默认自动锁定。如果偏好旧的行为，
可在 设置 → 安全设置 → 离开后自动锁定 中改为"从不"。

零网络、零追踪、零账户，100% 开源 —— 你的数据只属于你自己。
```

### 社交平台 / 公众号推广短文

> **零网络空间 1.1.0 上线** 🔒 这个开源 iOS 隐私相册这次更安全了：离开 App 自动上锁；多任务切换器里只显示启动页，再也不怕身后有人瞟一眼。还有更可靠的删除确认、笔记草稿加密，以及一个重要的内购修复。没有网络请求、没有账号、没有追踪——只有真正工作的加密，和你可以亲自审计的代码。

---

## English (en)

### Promotional Text

**Recommended:**

> Your photos never leave your phone. Zero network, AES-256 encryption, calculator disguise — now with Auto-Lock and an app-switcher privacy shield. 100% open source.

**Alternative (shorter):**

> The vault that can't spy on you: zero network, zero tracking, AES-256 encrypted. Now with Auto-Lock. 100% open source.

### What's New

```
ZeroNet Space 1.1.0 — our biggest privacy update yet.

NEW
• Auto-Lock: the vault locks itself when you leave the app. Choose
  Immediately, 1 minute, 5 minutes, or Never in Settings > Security
  (locks immediately by default).
• Privacy Shield: your photos, videos and notes are now hidden in the
  app switcher — system snapshots never reveal your content.

IMPROVED
• Deleting photos, videos and files now asks for confirmation and
  reliably removes the encrypted data from your device.
• Secret note drafts are now stored encrypted.
• Smoother photo viewing: zoom no longer carries over between photos.

FIXED
• Fixed "product not found" when unlocking Unlimited Imports.
• Fixed rare cases where deleted items could reappear in the gallery.

Heads-up: after this update the app locks when you switch away — that's
the new default. Prefer the old behavior? Set Auto-Lock to "Never" in
Settings > Security.

Zero network. Zero tracking. Zero accounts. 100% open source —
your data belongs to you alone.
```

### Social / GitHub Release blurb

> **ZeroNet Space 1.1.0 is out** 🔒 The open-source iOS privacy vault just got safer: your vault now auto-locks when you leave, and the app switcher shows nothing but the launch screen — no more accidental shoulder-surfing. Plus reliable deletion with confirmation, encrypted note drafts, and an important IAP fix. No network. No accounts. No tracking. Just encryption that works — and code you can audit.

---

## 写作说明（为什么这么写）

- "默认立即锁定"的行为变化在中英文 What's New 里都用显眼的提示段主动说明——这是老用户升级后最可能困惑的点，先讲清楚能减少差评。
- "Auto-Lock / Privacy Shield（自动锁定 / 隐私遮罩）"采用产品化命名，比功能性描述更易记忆和传播。
- 结尾"三零"口号与 README 品牌表述保持一致。
- 文案中的功能路径（设置 → 安全设置 → 离开后自动锁定）与 App 内实际菜单文案一致。
