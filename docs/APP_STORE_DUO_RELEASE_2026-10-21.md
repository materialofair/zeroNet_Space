# SealedPocket Duo 发布准备与审核回执

当前状态（2026-10-21 15:27 UTC）：**1.3.10 (23) 已正式提交，刷新确认 Waiting for Review（等待审核）；手动发布保持，功能尚未公开上线。** 用户明确确认出口合规第 4 项后已正常保存，先前未执行的拒绝动作仅重试一次并成功。14 张新截图与十语说明均已保存回读，没有新阻塞。

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

## 最终审核回执

- ASC App ID / version / build：6755504480 / 1.3.10 / 23。
- 上传 / 处理 / 绑定：上传成功、处理完成，build 23 已绑定并保存。
- 审核状态：**Waiting for Review / 等待审核**，2026-10-21 15:23 UTC 正式提交，刷新回执及版本页均确认。
- Submission ID：`f705a0c8-ee69-4a88-9fe5-00a81e689ed0`。
- [ASC 正式审核回执](https://appstoreconnect.apple.com/apps/6755504480/distribution/reviewsubmissions/details/f705a0c8-ee69-4a88-9fe5-00a81e689ed0)；构建 UUID `2ece87ef-7571-497f-975b-119c261cafe0`，回执明确为 1.3.10 (23)。
- 结构化回执：工作树外 `evidence/release-final/asc-submission-receipt.json`。此前 pending 回执保留为历史，不代表当前状态。
- 发布方式：手动发布已保存并回读。

## 本地资源记录

- 截图准备曾因磁盘写满而未启动；只删除本任务旧 baseline/dev/unsigned-device 构建缓存和 IPA 解包检查目录，保留日志、xcresult、Archive、IPA、源码及全部原始图片/录像。没有清理 runtime 或其他任务。清理后约 1.1 GiB 可用。

- 截图恢复后的首次运行在启动测试 runner 前失败：testmanagerd unix-domain socket 不存在。没有执行截图断言，不作为产品回归失败；仅正常重启本任务 iPhone 恢复测试服务。

## 当前交接状态（历史阶段，已被最终状态更新）

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

## ASC 绑定与合规待确认（历史阶段，现已解决）

- 处理后的 build 23 已选中并保存到 1.3.10。Build UUID：2ece87ef-7571-497f-975b-119c261cafe0。
- 后台显示缺少出口合规证明。管理窗口询问算法类别：专有/非标准；除 Apple OS 加密之外另用的标准算法；两者兼用；不属于上述任一种。未选择/保存。
- 技术核对为系统 CryptoKit AES-GCM、CommonCrypto PBKDF2 与 Keychain，本次未改加密实现。倾向仅使用 Apple OS 的第 4 项，但具体法律声明等待主线程取得用户确认。没有给 Info.plist 新增豁免标志绕过提问，也不照搬 PaperSnips。
- 手动发布保持；继续准备图片和十语回读，尚未提交。

## 商店材料进度

- 处理完成后的 build 23 已绑定保存，UUID 2ece87ef-7571-497f-975b-119c261cafe0；仍缺出口合规声明，未提交。
- 英语/简中 iPhone 中等屏与 iPad 13 各 3 张，共 12 张新素材已上传并回读。旧版本引用移除时 Apple 明示仍保留在素材库，未删除库原图。其他八语种既有图不移除。
- 十语更新说明均已逐项回读且含 Duo 内容；无空字段，原语言覆盖保留。
- 额外简中 Duo 源图采集：首次命令因工作目录无项目未启动；随后直接 xctestrun 调用在测试开始前输出 Xcode internal-error 提示，并超过三分钟无日志进展，未得到有效截图。仅停止本任务进程，保留日志/未封装结果，不算通过；根因未确定，不能据此认定为 runtime 签名问题。继续用已验证的英文真实 Duo 原图，未绕过校验、删除或重下载 runtime。

## 最终材料回读与精确阻塞（15:12 UTC 历史阶段）

- 英语/简中 iPhone 中等屏各 3 张（1206×2622）、iPad 各 3 张（2064×2752），加英语默认 Duo 内屏/外屏原图 2 张，共 14 张，均上传回读。Duo 组后台 2/10。
- 英语、简中、繁中、德语、法语、西班牙语（西班牙）、日语、波兰语、葡萄牙语（巴西）、印尼语更新说明全部逐项回读，均非空且包含 Duo 内容。其他八语种既有图不删除。
- ASC 仍显示 1.3.10 准备提交、绑定 23、缺少出口合规证明、手动发布=1。
- 合规管理的问题为算法类型：①专有/非标准；②除 Apple OS 加密之外另用的标准算法；③两者兼用；④不属于上述任一种。系统 CryptoKit AES-GCM、CommonCrypto PBKDF2 与 Keychain 的技术事实支持倾向第 4 项；法律声明待用户明确确认。
- 受阻动作：点击“添加以供审核”，目标 app 6755504480 / 1.3.10 (23)。自动审批明确拒绝，因为缺少出口合规这一法律前置条件；已知未执行，没有间接提交或其他路径重试。待用户确认后继续合规、添加审核和最终提交。
- 浏览器已停止操作，可由主线程协调继续；没有仍在运行的上传或大构建。Git 没有推送。

## 用户确认后的正式提交 — 2026-10-21 15:23 UTC

- 用户针对两款 App 的具体出口合规问题明确回复“确认”。SealedPocket 已选择并保存第 4 项“不属于上述的任意一种算法”；技术实现仍为 Apple 系统 CryptoKit AES-GCM、CommonCrypto PBKDF2、Keychain，不宣称 App 完全不使用加密。缺少合规提示随保存消失。
- 已知此前“添加以供审核”未执行；取得新授权后仅重试一次，成功进入可供审核，再正式点击“提交以供审核”。ASC 返回“已提交 1 个项目”。
- 前往官方审核详情并刷新，状态“等待审核”，项目 iOS App 1.3.10 / 1.3.10 (23)；返回版本页再次看到“正在等待审核”、build 23、手动发布=1。没有点击取消提交或发布。
- ASC 浏览器已明确释放给 PaperSnips；无活动上传或大构建，无后续浏览器操作。没有新审批、连接或网络阻塞。
- 当前仍未上线；Apple 审核结果及后续手动发布不属于已完成事实。原真机/硬件及 runtime 完整性测试缺口保留。

## Duo 专用栏位与标识边界 — 15:28 UTC 补记

- 14 张包含普通 iPhone 6 张、iPad 6 张、**ASC 独立 iPhone Duo 截图栏位 2 张**，专用组上传后曾回读 2/10。不是把普通 iPhone/iPad 截图算作 Duo。
- 英语默认素材：`evidence/store/duo/04-Duo-Expanded.png`（2853×2007，真实展开界面）及 `05-Duo-Compact-Notes.png`（1398×2034，真实合起界面）。简中未另行补拍有效 Duo 图，不能声称十语均有新 Duo 本地化图。
- [Apple 2026-10-05 官方说明](https://developer.apple.com/news/?id=kkphp5qo) 表示提交 Duo 截图后商品页会显示适配标识；这不等同于编辑推荐。本版本尚待审核、未公开发布，公开 badge 尚未核实，没有提交 Featuring Nomination。
- 已提交版本不撤回、不重复提交；浏览器仍释放给 PaperSnips。
