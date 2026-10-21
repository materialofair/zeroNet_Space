# SealedPocket Duo 适配与隐私验收 — 2026-10-21

状态：**本地未发布开发版**。没有推送、上传、App Store Connect 修改、提审或公开发布。商店工作随下一次正常版本处理。

## 工作区与范围

- 原项目：`/Users/WangQiao/Desktop/github/ios-dev/ZeroNet-Space/openSource/zeroNet_Space`，起点 `bc76ab0`。
- 隔离工作树：`/Users/WangQiao/Documents/Codex/2026-10-21/task-4/SealedPocket-Duo`。
- 本地分支：`codex/duo-adaptive-20261021`。
- 原目录已有未提交的产品页文档，保持原样；其完整当前内容复制到本分支后追加本次状态，不覆盖新增 ASO 清单。
- 共享 75 项额度、保存录音计入额度、一次性 VIP、购买入口、名称、价格、隐私声明、安全设置值、加密格式及备份功能均未改动。

## 实现

- 根据实际窗口宽度决定分类导航：普通文字在 640 pt 及以上出现 200 pt 侧栏；辅助功能大字体在 1050 pt 及以上出现侧栏。收窄时恢复原生单栏导航。无设备名分支。
- 同一个 TabView 与各分类 NavigationStack 一直保留在相同视图结构中；尺寸变动只改变布局环境，不创建新窗口、不重建编辑器或导入模型。
- 照片按内容宽度生成 1–8 列，保留小屏常用三列；大字体增大缩略图目标尺寸。视频使用自适应卡片网格；文件、笔记及设置保留原生列表与手势并限制阅读宽度；录音面板限制宽度。
- 照片/视频改为真正按钮，补足主要操作和分类的 VoiceOver 标签、选中状态；空页可滚动，笔记字体支持 Dynamic Type。
- 笔记防抖任务正确响应取消，显式保存后不会复活旧草稿；离开或锁定时仅刷新尚未保存的修改，避免重复写入。

## 隐私审计与修复

代码审计确认基线存在以下异步边界风险；这不等同于已证明公开发行版发生实际泄漏。

- 保留认证分支之外的 PrivacySceneObserver、所有可见窗口的同步遮罩、遮罩下关闭 UIKit 呈现以及延迟揭开遮罩的代次检查。补充遮罩的 VoiceOver 模态边界。
- 锁定使照片、文件、视频和批量导出的会话及请求代次失效；旧回调不能再次展示分享界面，旧 PDF/文本/图片/视频加载结果不能写回已撤销视图。锁定也取消当前导出与登录任务。
- 缩略图和图片缓存用同一个锁将清空与最后一次插入串行化；锁定之前开始的解码结果不能重新填充缓存。
- 每次导出使用独立 UUID 临时目录；取消、失败、分享取消、视图拆除及锁定仅清理该请求自己创建的临时文件，避免删除其他仍在使用的分享。
- 访客空笔记页不再提供 New Note；读取草稿还检查实际主人模式与当前认证状态。未改变密码、安全设置或主人/访客数据格式。

## 环境与证据约束

- Xcode 27.1 (27A9275)。已安装官方 iOS 26.5 (23F73) 与 27.1 (24A94232)，未重复下载运行时。
- 新建三个 `SealedPocket-Demo-*20261021` 设备，仅使用程序生成的六张色块照片、虚构文本与测试密码，不读真实保险箱资料。
- Duo：`8B06A71F-8AD4-49AA-BF63-BCA710DE2399`；iPhone 17：`ABA536C2-EFB6-4AC2-A37A-31BDFA8C409D`；iPad Pro 13 M4：`D6D992C5-DE99-4E66-89F5-2627BBCDCABD`。
- 27.1 已知 runtime verify 的 `-67054 sealed resource missing or invalid` / SignatureStateUnknown 限制仍存在。本次正常使用已安装 runtime，不绕过、重签名、关校验或删除它；Ready 只表示可用，不是完整性或真机验收。
- 新 Duo 首次 bootstatus 还出现 Data Migration Failed；随后官方安装、启动、UI 自动化和 Device Hub 形态切换可用。Xcode 日志有 invalidDigitCount(94232) 与重复 AX bundle 警告，未改系统组件。
- Duo 的 XCTest 截图可能为黑帧；视觉交付使用 `simctl io --display=3 screenshot`（内屏）及 `--display=1`（外屏），不用黑帧当视觉通过证明。
- 折叠由 Device Hub 官方 Closed / Open 控制完成，测试日志观察到窗口 669×951 与 466×678 的切换。展开时的显示器 framebuffer 可为横向，AX app.frame 与实际显示器方向存在系统差异，原图均保留。

## 验收矩阵

| 场景 | 实际结果与证据 |
| --- | --- |
| 构建与核心测试 | Debug 模拟器及未签名 arm64 iOS Release 构建成功；36 项 XCTest + 21 项 Swift Testing 通过。含正常文本导出往返、完成回调与取消竞争、延迟解码失效、会话撤销、12 项生命周期状态测试。最终结果为 `verified-core.xcresult`，57 项全部通过，无跳过；包含独立 Keychain 的访客草稿隔离。 |
| 普通 iPhone | 分类、录音入口、笔记键盘和横竖屏内容保持通过；虚构文本经系统 Files 导入、正文预览及后台返回锁定通过。`phone-regression.xcresult`。 |
| iPad | 分类、侧栏、录音入口、笔记键盘、横竖屏及 Save 可达性通过。`ipad-ui.xcresult`。 |
| Duo 草稿折叠 | 实际展开→合起→再展开，持续检查标题、正文、Save。`duo-fold-draft-2.xcresult` 通过；窗口尺寸两种均出现。第一次即时 Save 断言碰到动画暂时不可点击，保留失败日志；改为最多 5 秒稳定等待后持续检查通过。 |
| 正常照片导入 | 原始基线使用系统照片选择器成功导入 6 张虚构照片，`baseline-import-6.xcresult`。前 5 次失败为标签栏类型、当前年份省略、Done 按钮及一次输入残留的测试定位问题，保留日志。 |
| 分享、应用切换卡片、手动/快速锁定 | `share-voiceover.xcresult` 的分享后台返回锁定及错误密码通过；`phone-privacy-final.xcresult` 中既有手动/快速锁定与应用切换卡片用例通过，分享/审计的早期失败另留日志。敏感样例可见时 546456 像素，卡片为 0；返回登录为 391（界面装饰背景值）。 |
| 正常导出完成 | 正常文本解密导出字节往返单元测试通过；真实系统分享菜单 Copy 在专用 iPhone 上人工辅助完成，`normal-copy-ui-2.xcresult` 断言分享结束并返回详情。第一次人工辅助测试因固定 40 秒窗口结束与点击竞争失败，未计为通过；改为等待实际完成信号后验证。 |
| 搜索与选择折叠 | `duo-selection-search.xcresult` 证明六项选择在 669/466 pt 之间保持；其搜索段没有观察到宽窄切换，因此不作为搜索折叠证据。专门追加 `duo-search-actual-fold.xcresult`，要求实际观察宽窄两种尺寸并持续比较文字，已通过。 |
| Dynamic Type / VoiceOver | `share-voiceover.xcresult` 的四个分类 sufficientElementDescription 审计通过。`dynamic-type-largest-4.xcresult` 在 accessibility-extra-extra-extra-large 字号下，登录、分类、笔记键盘和旋转通过，编辑区高度至少 44 pt。发现并修复原固定登录 VStack 的键盘遮挡、横屏大标题挤掉正文；紧凑高度隐藏次要计数并只限制单行标题到 xxxLarge，正文保持用户字号。 |

## 截图与录像

全部本地证据根目录：`/Users/WangQiao/Documents/Codex/2026-10-21/task-4/evidence/`。

- `screenshots/UNRELEASED-before-Duo-open.png`：原始基线真实内屏，固定三列。
- `screenshots/UNRELEASED-after-Duo-open.png`：开发版真实内屏，分类侧栏及按宽度生成的六列；在同一次运行的 PHOTO_EVIDENCE_READY 标记后自动采集，已人工复核。
- `screenshots/UNRELEASED-draft-open-before-fold.png`、`UNRELEASED-draft-folded.png`、`UNRELEASED-draft-reopened.png`：实际同一草稿与键盘的形态切换。
- `UNRELEASED-duo-draft-inner.mov`：60.75 秒原始内屏录像。合起时内屏由系统关闭为黑色，外屏另附原始截图；不能把内屏黑帧等同于完整隐私遮罩验收。
- `UNRELEASED-Duo-adaptive-30s.mp4`：同一录像的两个真实片段（源 0–15 秒与 45–60 秒），合计 30 秒；有一次明确剪接，未生成或重绘 UI。不是完整无剪辑的内外屏联录，系统返回 Host recording is already in progress，不允许同时开两个显示器录制。
- 未制作商店营销图；这些是开发验收素材，不是已上线功能或可直接上传的商店套图。

## 发布前仍须补齐

真机 Duo、iOS 17.6、完整 VoiceOver 手势遍历、外部接收方/云服务导出、PDF/视频的实际 UI 播放与锁定链路、访客凭据的完整 UI 往返、备份恢复与系统生物识别交互不能由本次模拟器结果证明。当前代码未实现 LocalAuthentication 生物识别解锁，故不伪造 Face ID 失败/取消通过记录。录音硬件、来电、锁屏策略仍沿用既有记录中的硬件验收缺口。

功能尚未上线。ASO 文案、本地化、商店规格与截图继承检查，以及后续版本说明均随下一次正常版本处理，不为本次文档或素材单独提审。


## 最终检查与边界

- `verified-core.xcresult`：36 项 XCTest、21 项 Swift Testing，全通过、无跳过。
- `final-release-device.log`：最终源码 arm64 iOS Release 构建成功，未签名、未安装真机；Debug 模拟器构建和上述 UI 测试已通过。
- 普通 iPhone/iPad、Duo 的可证明 UI 场景按表逐项记录，不将一次整个 suite 中部分通过说成全套通过。
- 整体测试中修正过的定位/人工时序问题保留原始失败日志；最大字号暴露的两个实际布局问题已修复。测试设备字号已恢复 large。
- 30 秒视频为原始录像的两个明确片段，保留原文件；本次没有 Library 上传，直接交付本地路径。
- 没有修改运行时签名或关闭检查；没有 App Store Connect、推送、上传或提交审核。剩余缺口属于发布前验收门槛，本地开发完成不等同于上线许可。
