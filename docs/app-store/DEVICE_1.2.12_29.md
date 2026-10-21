# 收下 1.2.12（29）原生材质受控对照

2026-10-20。用户复测28在系统浅色下仍为黑底，未满足当前通知材质协调目标。手机已独立读回1.2.12（28），设备系统iOS27.0.1/24A446。

## 本次只改变什么

- 保持营销版本1.2.12，六项Debug/Release构建号由28改为29。
- 锁屏移除`activityBackgroundTint(nil)`和`activitySystemActionForegroundColor(nil)`两项调用。内容仍使用语义主次文字色，不加自绘背景、不指定透明度或强制明暗，不恢复主题同步；灵动岛/Mac内容不变。
- 与28的62项应用/工程/测试/脚本逐项比较，只有实时活动视图和工程构建号不同，取件识别、存储、状态、生命周期和测试源码保持。

## 假设和边界

Apple文档定义nil为使用默认背景材质，但API调用是否与完全省略modifier在当前系统上等价，尚未实测。Apple论坛有旧系统beta中nil呈黑底，以及SmartStack使用modifier会影响玻璃的开发者报告；它们分别属于旧系统与其他呈现位置，不是本机iOS27问题的已证实原因。此构建是验证差异的最小对照，不宣称已经找到根因或修复玻璃。

公开参考：[背景接口](https://developer.apple.com/documentation/swiftui/view/activitybackgroundtint(_:))、[ActivityKit历史讨论列表](https://developer.apple.com/forums/tags/activitykit/?page=4&sortBy=oldest&sortOrder=DESC)、[SmartStack相关讨论列表](https://developer.apple.com/forums/tags/activitykit?page=2)。

## 验证和交付

Xcode27.1（27A9275）generic iOS Debug构建通过，三个bundle均1.2.12（29）、最低16.0；严格签名、AppGroup、主App深度签名检查通过，62项源码测试脚本与构建前快照SHA-256一致。已通过devicectl覆盖安装到iPhone14Pro，独立设备清单读回1.2.12（29）。回执同目录`device-build-validation.json`、`device-install.json`、`device-installed-app.json`，构建日志`device-build.log`。未启动App或代操作界面，材质效果仍待用户对照。28的159项host测试适用的数据逻辑与测试脚本/测试源码完全一致，本次不重复无变化的行为测试；视觉效果不能由这些测试证明。源快照和哈希位于`.private/releases/1.2.12-29/source-snapshot/`和`source-manifest.json`，环境摘要同目录`runtime-environment.json`。

未上传TestFlight、未提交审核/正式发布，未Git提交推送；已有其他改动保留。

## 手动对照

用户保持现有壁纸和系统浅色，打开收下，在“设置 → 锁屏与灵动岛”先关闭展示，等旧卡片消失，再开启创建新活动；与28的黑色卡片对照。只有新活动出现协调材质且文字清楚，才把该对照记为改善；若仍黑，则该实验失败，不能继续按默认材质已恢复解释。Agent不代操作界面。

## 用户实测与目标纠正

用户反馈“还是黑的”，说明29省略modifier与28显式nil的对照没有改善观察到的外观；不把这项假设写成根因成立。

用户随后澄清：“我不是非要要求半透明效果，我意思是使用系统直接提供的组件会更符合系统统一的ui”。据此纠正Agent此前按“消除黑底/实现通知玻璃”设定的目标：本项目此处优先ActivityKit/WidgetKit系统实时活动容器，内容以SwiftUI系统视图组织；不将指定颜色、透明度或复制普通通知外观作为未经用户要求的硬指标。普通通知与实时活动属于不同的系统呈现类型；这不证明用户看到的颜色一定是该iOS版本的正常设计，也不等于视觉已获接受。

已再次核对29视图及子视图：无自绘背景、背景颜色modifier、强制主题或自定义橙色边框；布局只保留系统文本/图标/堆栈、字体和间距。62项应用/工程/测试/脚本与已安装29的源码快照一致。停止半透明定制及默认背景/强制浅色的反复实验，本轮只更正文档，未改应用源码、未再构建安装或操作UI。

## 后续：用户明确恢复27版方案

用户认可1.2.11（27）作为基线并明确授权回滚，后续交付为[1.2.12（30）](DEVICE_1.2.12_30.md)，实现恢复而build继续向前。此前“保留29”的描述是当时位置，不代表恢复决定后的当前状态。
