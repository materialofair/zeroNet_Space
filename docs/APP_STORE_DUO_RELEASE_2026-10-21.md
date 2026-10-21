# SealedPocket Duo 发布准备与审核回执

当前状态：2026-10-21 用户已授权提审；最终 **1.3.10 (23) 已上传成功**，草稿手动发布已保存，尚未绑定或提交审核。浏览器已按协调安排暂时交回 PaperSnips，待交还后完成十语回读、截图与绑定提交。功能尚未公开上线。

## 源码与范围

- 隔离工作树：`/Users/WangQiao/Documents/Codex/2026-10-21/task-4/SealedPocket-Duo`
- 分支：`codex/duo-adaptive-20261021`；适配实现起点提交：`7e835f000512f58a247bbbbdc676e6073d59f2a5`。
- 原 main 的未提交 ASO 文档保持不变。没有 Git 远端推送。
- 名称保持 Photo Vault: SealedPocket，不修改价格、IAP、区域、账号或隐私配置。
- 更新授权替代先前“仅本地开发、不提审”的阶段限制；历史记录保留，不把准备完成写成已上线。

## 设备签名预检

- 本地起始版本 1.3.9 (22)，已有最近归档为 1.3.9 (21)。建议新版本 1.3.10；最终版本和 build 必须先核实 ASC，不能把建议当后台唯一值。
- `evidence/release-preflight/SealedPocket-1.3.9-22.xcarchive`：Release / arm64 / iOS device SDK Archive 成功，Apple Development 身份、Team MB2PNFT9L9；`codesign --verify --deep --strict` 成功。
- 既有 Archive Post Action 将源码下一次 build 自动递增到 23；归档本身仍为 22。
- `evidence/release-preflight/export/零网络空间.ipa`：本地 App Store Connect 分发导出成功，既有 Cloud Managed Apple Distribution，有效期至 2027-08-22，`get-task-allow=false`。原生 ditto 解包后的严格签名验证通过。
- 未使用 `-allowProvisioningUpdates`，未申请新证书或 API key。一个无关 Xcode 账户日志提示缺少 Xcode-Token，但没有阻止现有签名导出。
- 这是预检包，尚非最终上传版本。未进行 Apple 服务端上传验证，不应称已通过商店验证。
- 已知 27.1 simulator runtime `-67054` / SignatureStateUnknown 仍保留，未绕过或改签；设备 SDK 的 Archive 与分发签名结果独立记录。

## 本轮关键隐私回归

- 专用 iPhone：`ABA536C2-EFB6-4AC2-A37A-31BDFA8C409D`，稳定 26.5 runtime。没有操作 PaperSnips 设备。
- 使用本地生成的纯色三秒视频和带 FICTIONAL PDF 标记的 PDF，通过系统 Files 正常导入。
- 第二轮 `release-pdf-video-2.xcresult` 的视频播放、分享呈现及后台返回锁定通过；PDF 分享测试误选预加载页面操作，失败保留，不能计为通过。
- 补充实际文件翻页器 `MediaDetailView` 的解密结果会话检查：锁定后旧 PDF/图片/视频结果不再写入视图；清理已解密内容、播放器与本请求临时文件。QuickLook 临时文档写回也检查会话。
- `release-final-core.xcresult`：36 XCTest + 21 Swift Testing 全通过。`release-final-ui.xcresult`：PDF 即时锁定、PDF 分享后锁定、视频播放/分享后锁定、正常演示内容准备，4 项全通过。`store-ipad-final.xcresult`：iPad PDF 分享后锁定与真实内容截图采集，2 项通过。
- 修复 PDF 内部控件与预览标题栏重叠，以及初始页数为零时的状态写入问题。
- 合跑 `release-privacy-4` 在输出全部断言结果后卡住超过五分钟，xcresult 未封装；核查进程后仅终止该进程，保留原始日志，不把该包当完整通过结果。独立最终核心及 UI 结果包均正常封装。
- 真机、硬件、商店版覆盖升级和真实 IAP 沙盒结果仍不能由模拟器证明。

## 商店素材与说明

- 高清真实界面前三张：Private photos. On your device. / Files and notes, kept together. / No account. Start with 75 items.
- 第一张副文案 Encrypted locally. No account required.
- 第三张说明 Photos, videos, files and saved recordings share the 75-item allowance.
- 使用实际模拟器原图，保留原始来源；221×480 缩略图不能上传，不使用概念 UI，不暗示笔记配额或累计终身额度。
- What's New 仅写窗口宽度适配、旋转/键盘/大字号改善，以及本轮实际验证的锁定呈现修复；不宣称独立安全审计。
- 保持 ASC 当前语言覆盖，待交接后核实，不拿旧 metadata 名称覆盖现名。

## 最终回执（待实际操作填写）

- ASC App ID / version / build：6755504480 / 1.3.10 / 23。
- 上传 / 处理 / 绑定：上传成功，Apple processing；处理完成与绑定待回读。
- 审核状态 / submission ID / 时间：未提交。
- 发布方式：计划手动发布，待后台核实保存。

## 本地资源记录

- 截图准备曾因磁盘写满而未启动；只删除本任务旧 baseline/dev/unsigned-device 构建缓存和 IPA 解包检查目录，保留日志、xcresult、Archive、IPA、源码及全部原始图片/录像。没有清理 runtime 或其他任务。清理后约 1.1 GiB 可用。

- 截图恢复后的首次运行在启动测试 runner 前失败：testmanagerd unix-domain socket 不存在。没有执行截图断言，不作为产品回归失败；仅正常重启本任务 iPhone 恢复测试服务。

## 当前交接状态

- ASC 核实当前线上 1.3.9 (21)，没有 1.3.10 草稿或构建；已创建 1.3.10 草稿。
- 最终 Archive：evidence/release-final/SealedPocket-1.3.10-23.xcarchive，严格签名检查通过。Archive 后脚本把源码下一次 build 加至 24，归档仍是 23。
- 首次上传在本地 Packaging/Zip 阶段失败，未进入包上传；释放本任务缓存后第二次上传成功。release-final-upload-2.log 明确 Upload succeeded / EXPORT SUCCEEDED，Apple 包进入 processing。没有重复上传成功构建。
- 手动发布设置已保存，英文审核备注已保存，英语和简体中文更新说明已回读。其余八种语言已执行保存，仍需刷新逐项验证持久化。
- 中英 iPhone / iPad 原图和商店套图在 evidence/store；尚未上传截图。其他八语种的既有图片不删除，待后台核实继承。
- 浏览器已按主线程要求释放给 PaperSnips；最终绑定 build 23、截图及提交状态待交还后继续。
- 磁盘空间反复回落到约 111 MiB，CUA failedToCreateImageDestination 阻止最后一次页面回读。不是权限拒绝。没有修改其他任务、runtime 或用户文件。

## 磁盘恢复（用户明确授权）

- 清理前全局可用约 0.27 GiB；先清三个全局 Xcode 模块/SDK/符号缓存，再逐一以 lsof 和编译进程检查确认 PrivateLedger 五个编译缓存及中间/索引目录停用后精确清理，恢复到 2.33 GiB。
- PaperSnips 随后明确释放 /tmp/PaperSnips-Store18，核实普通目录且无打开文件和 xcresult，仅清 Build、CompilationCache.noindex、SDKExplicitPrecompiledModules，保留 Logs/info；之后约 2.23 GiB 可用。
- 保留所有源码、Products、依赖源码、Archive/IPA、日志与测试结果、截图录像、签名材料、运行时、Downloads 和 Trash。明细 evidence/disk-cleanup-2026-10-21.json。

## 追加快照与最终包验收

- `release-switcher-pdf-video-3.xcresult` 的 PDF 用例通过：解密 PDF 可见时样例像素 1,805,725，嵌套分享后的 vault 切换卡片为 0；真实后台 state=3 后返回锁定。
- `release-video-switcher-final.xcresult` 单项通过：视频可见时样例像素 1,010,138，嵌套分享切换卡片为 0；等待真实后台 state=3 后返回锁定，旧分享与预览均不存在。
- 早期新增用例在切换器发送 Home 后 app.state 仍是前台 4，因此前置条件不成立；不作为产品泄露结论。改用正常打开该专用模拟器的系统设置（不修改配置），等待 vault 真正后台，再作锁定断言。所有失败日志与结果保留。
- 最终同源 1.3.10(23) 分发 IPA 已导出到 evidence/release-final/export；签名验证和哈希见 release-binary-manifest.json / ipa-signature-verification.txt。没有重复上传。
