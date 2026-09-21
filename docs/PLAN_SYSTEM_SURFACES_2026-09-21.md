# 系统文件图标、小组件与取件实时活动

2026-09-21：用户确认依次推进；手机为支持灵动岛的 Pro。第 1 项已从原 checkout 按基线差异导入隔离开发工作区，第 2、3 项已完成本地实现与下述非交互验证。系统显示、刷新和交互仍待真机验收。

## 顺序与验收

| 顺序 | 内容 | 完成条件 | 当前状态 |
| --- | --- | --- | --- |
| 1 | `.shouxia` 系统文档图标 | 声明与资源进入构建产物；真机“文件”显示、打开预览及重复导入回归 | 配置与构建完成，待安装后的真机验收 |
| 2 | 桌面小／中组件、锁屏件数 | 展示与 App 待取状态一致；点击定位正确；真机刷新及布局验收 | 实现、核心测试、签名和安装完成；真机交互待验收 |
| 3 | 自动待取实时活动，覆盖锁屏和灵动岛 | 设置开关、数据同步与恢复正确；Pro 真机完成完整取件流程 | 实现、状态测试与构建通过；真机待验收 |
| 4 | 评估锁屏直接完成 | 在前两项实际使用后评估误触、撤销和多进程写入，再决定是否实现 | 已做工程评估，暂不实现；等待使用反馈 |

最初开发授权不含安装；用户随后补充授权手机覆盖安装和 App Group 签名配置，现已完成。仍不包含 TestFlight 上传或发布。手机与模拟器的交互验收由用户操作；非交互构建与静态核验分别记录。

## 1. 系统文档图标

基线为 `main@ac5cc4e`：已声明 `com.zhouwei.shouxia.handoff`、扩展名 `shouxia`、MIME `application/vnd.shouxia.handoff+json`，类型继承 `public.json`，但没有显式文档图标。不能把这一缺项认定为所有“未知文件”现象的唯一原因，也不能仅凭声明认定安装设备上的关联已生效。

实施方案：

- 复用现有 `AppIcon-1024.png`，通过单独的 Copy Bundle Resources 条目打包到 App 根目录；与资产目录共用同一源文件，避免两份品牌图漂移。
- `CFBundleTypeIconFiles` 和 `UTTypeIconFiles` 引用这个真实 PNG 文件。
- `UTTypeIcons` 提供短标签“收下”；不指定 badge，采用 Apple 文档约定的 App 图标。折角外形、遮罩与缩放由系统处理。
- 保持文件扩展名、UTI、MIME、JSON 编码、预览确认与去重规则不变。不声明支持任意 JSON 文件。

Apple 文档依据：[UTTypeIcons](https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons)、[UTTypeIconFiles](https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeiconfiles)、[CFBundleDocumentTypes](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)。微信自行决定附件展示，系统声明不能保证微信采用图标；本阶段以系统“文件”结果为验收对象。

待安装修正版后，由用户检查：

1. 保存一份新导出的 `.shouxia` 到“文件”，查看列表和网格中的图标；旧文件也检查一次，记录系统缓存差异。
2. 退出收下后，从“文件”打开交接包，确认进入预览，未确认前不导入。
3. 确认导入后再次打开同一包，确认不重复添加。
4. 将微信附件保存到“文件”，分开记录微信问号、系统图标和打开结果。仅微信显示问号不等于系统修复失败。

不以卸载 App 刷新图标缓存，避免丢失本地取件记录。

## 2. 小组件

- 小号：总待取件数、一个地点、一个完整取件码和其余件数；点击打开对应取件台。
- 中号：按地点展示最多 3 条码，余量用“还有 N 件”表达；每条定位到对应记录。
- 锁屏：默认只展示待取件数，不显示取件码；点击打开待取列表。
- 默认展示全部待取，可选择固定地点。排序沿用 App；地点缺失、常用地点来源、空列表、长码分别设计，不能把长码截成看似完整的另一串码。
- 桌面提供隐藏取件码选项，适配浅色、深色、着色模式及无障碍。实时活动不再提供隐藏码开关，设置页说明锁屏可见取件码。

数据方案先采用 App Group 中的最小只读快照，保留原始记录的单一写入入口，不为展示迁移或复制完整短信。导入、完成、撤销、交接、更正、恢复等成功写入后刷新快照并请求 WidgetKit 更新。失败或不可读不能冒充“都收下了”；点击组件时重新确认目标仍然待取。系统调度不保证即时刷新，不通过高频轮询维持外观。

实施前检查 App Group entitlement 与签名支持；展示映射和异常处理分别应用 `HCT-2026-09-08-02`、`HCT-2026-09-08-01`。验收覆盖短信后台导入、完成后撤销、交给别人后移除、恢复后重现、失效链接、快照不可读和已删除的筛选地点。

## 3. 取件实时活动

按用户真机反馈，改为“设置 → 锁屏与灵动岛”一个持久开关，与取件台无关。打开后，有待取时自动显示全部待取数量和最新一件的地点／码；新增、完成、交出、删除、更正、撤销均重新读取当前待取数据。全部取完自动结束，前台恢复待取时自动恢复。关闭展示不完成任何记录。移除取件台开始／结束入口和实时活动隐藏码选项。

锁屏使用暖白杏桃卡片；灵动岛紧凑形态左侧显示件数，右侧优先显示完整短码，放不下明确提示“长按看码”，展开显示地点与码。系统灵动岛背景仍为黑色，最小形态保留图标。完成和撤销仍在 App 中操作。

偏好持续开启不等于单次活动永久驻留：Apple 限制单次活动最长 8 小时，本地创建需要 App 前台。系统移除或到期后，下次打开收下自动恢复；后台短信只能更新已有活动，不能保证启动新活动。取空或关闭开关请求立即移除。新版本需在设置中开启一次；旧版一次取件会话不视为此项长期授权。

已有 `codex/apple-watch@ca5a1e7` 实时活动原型，本轮已只读确认提交存在。第 3 项先审查其中控制器、ActivityAttributes、扩展 target 和测试的可复用部分；旧原型不是当前需求验收证据，不直接合并整条分支，不重启独立 Watch App／跨设备同步方向。

验证分层：纯状态测试与构建；预览／模拟器布局；用户 Pro 真机的开始、锁屏、切换 App、与音乐并存、长按展开、完成及结束。用户截图已证明旧版锁屏卡片和紧凑灵动岛实际显示；本轮自动展示逻辑和新外观仍待用户验收，Agent 未操作设备 UI。

## 验证记录

- 第 1 项：`plutil -lint` 检查 Info.plist 与工程文件通过，`git diff --check` 通过。
- Release 通用模拟器目标构建通过，退出码 0，日志含 `BUILD SUCCEEDED`。命令：`xcodebuild -project Shouxia.xcodeproj -scheme Shouxia -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/shouxia-system-document-icons-20260921 CODE_SIGNING_ALLOWED=NO build`。
- 构建产物 `Info.plist` 已读回文档图标、UTI 图标和短标签；引用的 PNG 已进入 App 根目录。Xcode `CopyPNGFile` 会优化 PNG，文件 SHA 不相同；通过 ImageIO 解码到统一 sRGB RGBA 后，1024×1024 全部像素与原品牌图一致。
- 交接包编码、导入、去重和品牌源图相对基线没有 diff。本轮未运行行为测试：修改只涉及声明、资源引用和文档，构建验证不替代真机打开回归。
- 环境限制：Xcode 报告 CoreDevice 插件加载问题，以及 CoreSimulator 服务 `1051.55.0` 比构建所需 `1171.7.0` 旧。通用目标构建仍成功；不能据此声称模拟器运行、安装或系统图标展示通过。后续设备操作前需核实开发工具服务状态。
- 构建日志：`/tmp/shouxia-system-document-icons-20260921.log`；产物：`/tmp/shouxia-system-document-icons-20260921/Build/Products/Release-iphonesimulator/收下.app`。这是模拟器产物，不能直接安装到 iPhone。
- `HCT-2026-09-18-01`：保留品牌源图，核对打包像素与未改动的交接逻辑；未发现本次声明修改引起的静态回归，系统视觉验收仍待用户。
- `HCT-2026-08-31-01`：本次真实用户回合调用一次 Gateway，返回 `abstain`，未交付 Memory；未把候选选择视为使用，不证明 goal continuation 路径。

## 第 2、3 项实现记录（隔离开发任务）

- 工作区：`/Users/zhouwei/.codex/worktrees/6c0d/shouxia`，起点 `ac5cc4e`，detached HEAD。原项目的 README、工程、Info.plist 与计划文档经基线对比后由补丁导入；未修改原 checkout，未带入截图脚本或截图目录改动。最初未提交或推送；后续用户授权通过 `codex/shouxia-1.2.4-14` 提交交付，并统一升为 1.2.4 (14)，见 [版本记录](app-store/TESTFLIGHT_1.2.4_14.md)。
- 新 target `ShouxiaWidgets`（`com.zhouwei.shouxia.widgets`）同时承载组件和实时活动，嵌入主 App。两端 entitlement 都使用 `group.com.zhouwei.shouxia`。
- 只读快照包含版本、更新时间、可用状态和待取记录 ID／码／地点／常用地点标记，不包含短信正文、指纹或历史记录。源码写入成功后发布，App 前台读取也可修复快照；短信 Intent 等待活动刷新后返回。组件没有原记录写入入口。
- 待取定义保持 `!isCompleted && !isArchived`。按新到旧排列，按地点成组，组顺序由最新记录决定；相同时间用 ID 稳定排序。地点 key 沿用去空白、忽略大小写的既有规则；缺失地点独立成组，常用地点保留“请确认”。固定地点不存在时保持空筛选，不回退到全部。
- 小号显示第一项，默认总待取数；中号每行可点击，最多三项并显示余量；锁屏圆形／行内／矩形只显示件数。隐藏码配置仅保留在桌面组件。长码若无法完整容纳则明确“长码请打开查看”，绝不截成另一串码。使用系统前景／背景色与隐私标记；具体浅深色、着色和无障碍效果待设备检查。
- 快照文件使用原子替换及首次解锁后可读的数据保护。缺失、损坏、版本不符、标记不可用或超过 24 小时，显示待更新，不显示零件成功态。写快照失败不伪造原记录写入失败；仓库暴露 `surfaceRefreshFailed`，前台加载有提示。替换失败尝试移除旧快照；系统已缓存的画面仍受 WidgetKit 调度影响。
- 链接为 `shouxia://pickup?id=<UUID>`，不含码。打开后重新读取原记录，仅仍待取时进入现有取件台；已完成／交出／删除时提示重新选择，读取失败不打开旧记录。锁屏件数链接返回列表。
- 实时活动按设置偏好自动同步全部待取；会话只持久化 ID 和 8 小时到期时间，不冻结成员。只保留一个活动；前台自动恢复，后台只更新已有活动。源读取失败或系统权限关闭时结束展示，保留用户的开关偏好，并区分诊断结果。
- 串行 revision worker 防止关闭开关期间的旧启动请求复活。ActivityKit 不直接写源记录；系统拒绝或失效不回写完成状态。
- 已审查 `ca5a1e7` 的 controller、attributes 和 WidgetKit 原型；仅沿用其串行 worker 与长码不截断思路，未合并旧分支、Watch target 或跨设备同步。

### 签名与验证边界

Apple 的 [App Group 配置说明](https://developer.apple.com/documentation/xcode/configuring-app-groups) 要求应用与扩展配置同组。最初只读检查发现本机已有两份 `com.zhouwei.shouxia` 描述文件都没有 App Group entitlement，未发现本扩展的描述文件。用户随后明确授权，已通过 `xcodebuild -allowProvisioningUpdates` 完成兼容的开发签名；实际产物与两端 embedded profile 均验证包含正确 App Group 和目标手机。签名构建成功与覆盖安装回执见下方，仍不替代交互验收。

活动按 Apple [ActivityKit 生命周期说明](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) 使用 `request/update/end`；过期标记与真正结束分开。活动不会上传取件码或请求推送 token。

- `bash scripts/test_surface_core.sh`：14 项主机 XCTest 通过，0 失败，日志 `/tmp/shouxia-persistent-activity-tests.log`。测试实际仓库写入与快照读取；ActivityKit 使用 fake client，验证状态、持久恢复和串行顺序，不证明系统卡片运行。
- Release 无签名通用模拟器构建通过，日志 `/tmp/shouxia-surfaces-build.log`，DerivedData `/tmp/shouxia-surfaces-20260921`。
- Debug `build-for-testing` 通过，日志 `/tmp/shouxia-surfaces-test-build.log`；这是 iOS 测试编译，不是执行完整 iOS 测试。
- `HCT-2026-09-08-01`：缺失／损坏／过期快照不可作为空成功；注入快照写失败保留源写成功和独立失败状态；活动源读失败／启动失败结束展示；串行测试确认结束可取消等待中的启动。检查阶段发现 `fileExists` 不能区分源文件缺失与不可访问，已改成仅 `fileReadNoSuchFile` 表示新安装空数据。
- `HCT-2026-09-08-02`：测试待取筛选、地点分组／缺失地点／常用地点、导入／完成／交接／更正／恢复，以及全部待取动态成员、取空／撤销、持久开关、前后台创建边界和 8 小时过期恢复。不迁移原数据，仍待用户验证真实使用与显示。

### 用户设备验收与反馈

用户确认原记录、桌面组件、锁屏件数、完成撤销可用；后续截图证明旧实时活动可显示，但黑色卡片和手动开始／结束不符合使用预期。因此改为上述自动展示逻辑，旧版“本次取件、固定成员、一小时、结束后不恢复”的约定全部作废。

本轮 Debug 真机签名构建通过：`/tmp/shouxia-persistent-activity-build.log`；14 项核心测试通过。主 App 和扩展 `codesign --verify --strict` 均通过。最新安装结果见[真机测试清单](DEVICE_TEST_SYSTEM_SURFACES_2026-09-21.md)。测试中系统活动使用 fake client，不替代新外观、灵动岛宽度及真实后台刷新验收。

初期 CoreDevice 服务问题已在设备发现时自动安装组件后解除，后续真机安装成功；没有进行模拟器 UI 验证。文件图标及交接重导入仍待用户验证，不能从构建或其他检查推定通过。

## 第 4 项：锁屏直接完成的工程评估

当前不实现。展示扩展只读与现有 App 单一写入边界可直接保留；直接完成会引入 AppIntent 后台执行的身份校验、写入串行化、重复点击幂等、失败反馈和跨入口撤销一致性。现有 JSON actor 只保证一个进程内的串行，不能将它直接当作多进程写入锁。

下一次评估应以本次真机反馈为输入：回 App 完成是否真的影响取件、锁屏误触风险是否可接受、撤销在锁定状态如何发现。只有确认收益后，再设计带记录 ID 校验的完成命令及统一持久化事务；按钮出现不等于可安全写入。不为这次展示功能提前迁移数据库或增加完成 Intent。
