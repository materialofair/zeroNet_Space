# 应用图标

入口：设置 → 显示设置 → 应用图标，仅主用户可见。

## 图标与权益

| 名称 | 资源 | 权限 |
| --- | --- | --- |
| 青环 | AppIcon | 默认，免费恢复 |
| 纸页 | AppIcon-Paper | 现有 VIP |
| 计算器 | AppIcon-Calculator | 现有 VIP |
| 山石 | AppIcon-Pebble | 现有 VIP |
| 尺规 | AppIcon-Ruler | 现有 VIP |

图标为本次重新生成的原创素材，统一为不含透明通道的 1024 × 1024 PNG。
默认图标在关于、登录与启动页面统一使用 AppIconDisplay。专属图标各有独立的预览 imageset。
未单独覆盖深色和着色外观，以同一套新素材交由系统处理，避免切换外观后显示旧图标。

权限复用 AppSettings.isVIP 与 PurchaseManager 的现有非消耗型内购、交易校验和恢复购买流程，不新增商品。购买成功后用户再次点击想使用的图标；不会自动切换。应用图标不会自动跟随登录模式或会员状态变化，恢复默认始终免费。

## 页面视觉

图标选择采用五行紧凑列表：44pt 预览、名称与一句说明、右侧青绿选中标记或 VIP 标识。取消大标题、大卡片与厚边框；二级页面隐藏底栏，购买与恢复入口合并为紧凑区块。字体随系统动态字号适配。

启动页直接复用默认青环图标，以暖白/浅青绿与深青绿两套背景适配外观，文字由 SwiftUI 渲染。登录页也使用同一图标。原来的光门图片不再用于这两个入口。

- [图标选择页](app-icon-gallery.png)
- [浅色启动页](launch-light.png)
- [深色启动页](launch-dark.png)

## 实现

- AppIconOption 定义固定的图标名称、预览和中英文文案。
- AppIconService 使用系统返回的 alternateIconName 作为真实状态，串行处理切换；失败时保留系统当前状态。
- AppIconSettingsView 提供预览、VIP 拦截、恢复购买、错误反馈，并在回到前台时刷新图标状态。
- Debug 与 Release 都通过 ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES 编译四个备用图标。由 Xcode 生成 iPhone 和 iPad 的 CFBundleAlternateIcons。

参照 xLocker 的付费预览选择方式，使用 Apple 官方 API，未复制其图标素材。

更换图标仅影响视觉外观，不会改名、隐藏应用或改变加密与登录保护。系统更换提示保留。图标页面已说明这些边界。

官方参考：[Configuring your app to use alternate app icons](https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons)。

## 验证

自动化覆盖：非 VIP 拦截、VIP 切换、免费恢复默认、重复选择、并发选择、失败后重试、不支持设备，以及当前设备的图标声明与预览资源。UI 测试覆盖设置入口、五款预览、VIP 提示和取消后保持默认。

2026-09-22 验证通过：

- `xcodebuild test -scheme ZeroNet-Space -destination 'platform=iOS Simulator,id=72367FCE-DFD3-4F3C-AE6D-2A64BD24976F' -only-testing:ZeroNet-SpaceTests/AppIconServiceTests -only-testing:ZeroNet-SpaceUITests/AppIconUITests -parallel-testing-enabled NO`：7 项服务/资源测试、1 项 UI 测试通过。
- `xcodebuild -scheme ZeroNet-Space -configuration Release -destination 'generic/platform=iOS Simulator' build`：成功；完整产物的 iPhone/iPad 备用图标声明均包含四个图标。
- 22 个图标文案键均具备英文与简体中文翻译，图标为 1024 × 1024 无透明通道 PNG。
- [模拟器界面截图](app-icon-gallery.png) 已人工检查；`git diff --check` 通过。

发布前需在真机检查四个备用图标及恢复默认在桌面、Spotlight、深色与着色外观下的显示，并通过 StoreKit 沙盒验证真实购买与恢复。自动化服务测试使用系统接口替身，不替代真机 SpringBoard 切换验证。
