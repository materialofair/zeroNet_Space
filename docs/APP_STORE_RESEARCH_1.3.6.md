# App Store 文案与发布记录：1.3.6

调研日期：2026-09-22。App ID：6755504480。

## 定位与落地

保留 ZeroNet Space / 零网络空间品牌，在名称中增加私密相册与文件加密用途；副标题补充离线、笔记与录音。关键词补充名称和副标题之外的相关搜索意图，不堆砌竞品名称。

最终完整文案见 [APP_STORE_METADATA_1.3.6.json](APP_STORE_METADATA_1.3.6.json)。已在 App Store Connect 保存英语（美国）和简体中文的名称、副标题、推广文本、关键词、描述和版本更新说明。

| 字段 | 简体中文 | 英语（美国） | 上限 |
|---|---:|---:|---:|
| 名称 | 17 | 26 | 30 字符 |
| 副标题 | 14 | 28 | 30 字符 |
| 推广文本 | 70 | 156 | 170 字符 |
| 描述 | 647 | 1906 | 4000 字符 |
| 更新说明 | 255 | 744 | 4000 字符 |
| 关键词 | 95 | 95 | 100 UTF-8 字节 |

免费额度、一次性 VIP、录音分享与导出、四款付费替代图标均按当前产品实现表述。明确本地存储与主动分享、StoreKit 联网的区别；移除绝对安全、不可发现、军事级等过度承诺，以及未经实现证实的功能描述。

## 调研依据

- [Apple 产品页指南](https://developer.apple.com/app-store/product-page/)：名称和副标题表达核心用途；推广文本不影响搜索排名，应承载近期更新；描述优先解释用户价值。
- [Apple 应用信息字段](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)：名称与副标题上限 30 字符。
- [Apple 版本信息字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)：描述及更新说明 4000 字符，关键词 100 字节。产品页概述有“100 字符”措辞，本次采用更严格的 UTF-8 字节校验。
- [Apple 准确元数据要求](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)：商店功能表述须真实，付费内容须清楚说明。
- 竞品定位参考：[Keepsafe](https://apps.apple.com/us/app/secret-photo-vault-keepsafe/id510873505)、[Private Photo Vault](https://apps.apple.com/us/app/private-photo-vault-pic-safe/id417571834)、[私图](https://apps.apple.com/cn/app/id1595672907)。这些产品以私密照片用途建立识别度；本应用可进一步突出离线、多种内容和一次性 VIP。

没有取得 Apple 搜索广告词量或自然搜索转化数据，因此本方案是基于相关性与产品定位的初始优化，不承诺排名或下载量提升。发布后可结合 App Store Connect 的搜索来源曝光、产品页浏览和下载转化率继续调整。

## 验证与发布设置

使用 Python 校验 JSON 及各字段长度，所有字段通过。浏览器逐项核对表单值并确认保存成功。

关联构建：1.3.6（17）。发布设置：审核通过后自动发布，立即向所有用户开放更新，保留现有评分。

提交结果：2026-09-22 已正式提交 1 个项目，App Store Connect 显示“1.3.6 正在等待审核”。审核提交记录：44152d7b-1fa6-4089-8950-e8c84862fef8。尚未正式上架，需等待 Apple 审核通过。
