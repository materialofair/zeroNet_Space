# ZeroNet Space 产品页优化记录 — 2026-10-07

## 本轮范围与状态

- App：ZeroNet Space: Photo Vault，6755504480。
- Comet / App Store Connect 实时核实：1.3.6 可分发；1.3.7 正在等待审核。本次复制已上线 1.3.6 的素材创建独立自定产品页。
- 自定页：`Private Photos - Offline Vault - EN ZH - 20261007`。
- [后台自定页](https://appstoreconnect.apple.com/apps/6755504480/distribution/productpages/0d0be5f0-fe9d-49b5-93ed-345ebcdacd87)。
- 产品页面 ID：`1cd285f5-048b-494e-96e6-2eb221947a24`。
- 中英文文案、关键词关联、截图顺序已保存。用户于本轮回复“同意”后正式提交审核；后台显示“已提交 1 个项目”，自定页状态为“等待审核”。尚未验证公开可用。
- 默认产品页 1.3.6 的中英文推广文本已按批准文案更新保存。没有启动广告或产品页 A/B 测试。

## 定位与文案

场景：用户希望把私密照片、视频、文件和笔记保存在本机加密空间。文案依据已上线描述及 `docs/APP_STORE_METADATA_1.3.6.json`，突出无需账号、无自动云端上传以及免费额度。

### 英文 — 156 字符

Keep private photos, videos, files and notes encrypted on your device. No account or automatic cloud uploads. Start free with up to 75 media and file items.

关联现有已上线关键词：`private`、`picture`、`encrypt`。

### 简体中文 — 71 字符

给私密照片、视频、文件和笔记留一处本地加密空间。无需注册账号，无自动云端上传。免费体验 75 个媒体及文件项目额度，VIP 一次购买解锁更多。

关联现有已上线关键词：`本地存储`、`相册管理`、`隐私保护`。

“无自动云端上传”描述存储行为；Apple 内购需要网络，不使用“完全无网络”宣传。免费 75 项为媒体和文件合计，不能误写为所有功能或笔记数量限制。

## 截图

英文 iPhone 6.5 英寸来源截图调整为：

1. `photos.png`。
2. `setpassword.png`。
3. `Simulator Screenshot - iPhone 14 Plus - 2026-09-06 at 22.11.11.png`。
4. `files.png`。
5. `settings.png`。

主界面 iPhone 6.3 英寸继承来源素材。英文 iPad 13 英寸调整为：`photos.png`、`password.png`、`videos.png`。

照片页面已移至首屏；现有 `photos.png` 是空相册界面，不能充分展示导入后效果。简体中文 iPhone 和 iPad 仍继承英文素材，尚未制作中文截图。本轮没有新增标题或搜索结果专用素材，也没有配置未经核实的深层链接。

## 默认页推广文本 — 已确认并保存

已将主要介绍外观、图标和音频更新的推广文案，替换为以上英文和简体中文场景文案。此处与自定页使用相同文本，字符数分别为 156 和 71。

## 基线与效果验证

App Store Connect 90 天范围：2026-07-09 至 2026-10-06，UTC。调整前记录：2,160 次展示、192 次产品页查看、18 次首次下载，后台显示日平均转化率 1.64%。日平均转化率不是用上述总数自行相除所得。

审核通过并确认链接可访问后，再用专用链接推广私密照片场景；按相同时间范围和流量来源观察自定页查看、首次下载及转化。当前数据不是本次调整带来的增长。样本较少，本轮暂不启动 A/B 测试。

## 验证与限制

- Comet 重新打开草稿，检查两种语言文案、关键词选中值、保存按钮禁用状态和媒体管理截图排序。
- Python 标准库验证中英文推广文案均不超过 170 字符。
- 新增此记录；没有改动应用代码、原始图片、版本或在审提交。
- 后续优先用虚构示例照片、文件及笔记补充真实使用状态，并制作中文素材，改善现有空列表截图。独立网页落地页不在当前默认范围内。

## 审核提交凭据

- [App 审核提交记录](https://appstoreconnect.apple.com/apps/6755504480/distribution/reviewsubmissions/details/7a1cddcf-097e-4405-b75c-cc00b6928f1e)。
- 后台明确显示已提交 1 个项目；不能把“等待审核”作为公开可用或实际增长的证明。
- 默认产品页保存后重新加载或重新打开，并切换英语与简体中文，复查文案持久保存；尚未单独核实 App Store 客户端缓存刷新。
- 本轮本地验证：两仓库 `git diff --check` 均通过，Python 检查提交记录与文件空白格式通过。
