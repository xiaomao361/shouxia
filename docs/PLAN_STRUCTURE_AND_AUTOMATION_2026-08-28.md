# 收下结构与自动化测试规划

日期：2026-08-28

当前进度：视图目录与文件边界已完成首轮机械拆分，`InboxView.swift` 从约 2357 行降至约 649 行；自动化测试结构仍按本文阶段 1、3、4、5 继续推进。

## 结论

下一阶段不做一次性“大重构”，而是先固定当前 `1.2.0 (8)` 的行为基线，再按功能边界机械拆分 `InboxView.swift`，最后补一层少而稳定的 UI 冒烟测试。

测试策略分为三层：解析与持久化规则用单元测试覆盖，前后台与剪贴板判断通过可替换依赖做确定性测试，系统粘贴授权、照片选择器、快捷指令和跨 App 分享保留为真机验收。这样既能防住最近出现的自动剪贴板回归，也不会把易受系统弹窗影响的流程硬塞进脆弱的 UI 自动化。

## 当前事实

- 工程只有 `Shouxia` 和 `ShouxiaTests` 两个 target，尚无 UI 测试 target 或 `.xctestplan`。
- 当前自动化测试共 39 项：37 项通过，2 项真实图片 OCR 测试在未提供外部夹具时按设计跳过。
- `PickupParserTests` 已覆盖手动与自动剪贴板的语义差异、常见取件通知和图片候选提取。
- `PickupRepositoryTests` 已覆盖导入、当前待取码去重、完成/撤销、交接、归档、永久删除与自动导入阻止标记。
- `PickupStore` 已支持注入临时 `PickupRepository`，适合直接增加状态层测试，不需要先引入 ViewModel。
- `InboxView.swift` 约 2357 行，同时包含首页、交接、图片确认、设置、自动化引导、取件大字模式和编辑表单。
- Xcode 工程仍使用手工 `PBXGroup` 和 Sources Build Phase；增加或移动 Swift 文件时必须同步维护 `project.pbxproj`，不能假设目录中的文件会自动加入 target。
- 当前工作树包含尚未提交的 Build 8 功能与文档修改。结构调整必须在它们完成真机验收并形成独立基线后开始，避免把产品修复与机械拆分混进同一提交。

## 目标与非目标

### 目标

1. 将 `InboxView` 收敛为首页布局、App 生命周期响应和页面路由，不再内嵌其他完整页面。
2. 保持 `PickupStore` 为 iOS 17 Observation 状态源，由根视图以 `@State` 持有；不增加只复制界面状态的 ViewModel。
3. 让自动剪贴板的“是否读取、是否处理、何时记住 changeCount”可以脱离 `UIPasteboard` 单独测试。
4. 为核心用户路径建立稳定的回归门禁，并明确哪些能力只能通过真机验收。
5. 每个阶段都能单独构建、测试、提交和回退。

### 非目标

- 不改变当前视觉、文案、导航、动画和数据格式。
- 不新增账号、云同步、后台轮询或跨设备回执。
- 不为了测试引入第三方架构、快照测试或依赖注入框架。
- 不在结构拆分阶段顺手修改解析规则和产品行为。

## 建议的目标目录

第一轮只调整视图边界，`Models`、`Services` 和 `Intents` 暂时保持稳定：

```text
Shouxia/
  App/
    ShouxiaApp.swift
  Features/
    Inbox/
      InboxView.swift
      InboxMoodCopy.swift
      PickupCard.swift
    Handoff/
      PickupHandoffComposeView.swift
      PickupHandoffReviewView.swift
      HandoffActivityView.swift
    ImageImport/
      ImageImportReviewView.swift
    Settings/
      AboutView.swift
      ImportPreferencesView.swift
      AutomationSetupView.swift
    PickupMode/
      PickupModeView.swift
      PickupCodePage.swift
      PickupRecordEditView.swift
    History/
      HistoryView.swift
    PickupStore.swift
    ShouxiaTheme.swift
  Models/
  Services/
  Intents/
ShouxiaTests/
ShouxiaUITests/        # 到自动化阶段再创建
```

`ImageImportReview`、`HandoffSharePayload`、sheet 路由枚举等辅助类型跟随真正拥有它们的功能移动。跨文件后只把必要类型从 `private` 放宽为默认的模块内可见，不提升为 `public`。

完成第一轮后，再根据实际复杂度决定是否拆分 403 行的图片识别服务；326 行的 `PickupRepository` 目前仍是一致的本地持久化边界，不因行数单独拆仓储层。

## 分阶段执行

### 阶段 0：冻结 Build 8 行为基线

前置条件：先对当前 Build 8 源码重新执行真机验收，并将现有产品修复作为独立提交收口。结构提交不与它混合。

完成标准：

- 当前 39 项测试结果不退化；
- 自动剪贴板只接受明确取件语义；
- 手动粘贴接受裸的 4 至 8 位数字；
- 永久删除后的相同原文不会自动复活；
- 首页先展示本地记录，再检查剪贴板；
- 当前基线有独立、可定位的 Git 提交。

### 阶段 1：先补测试缝隙

在拆视图前增加两个小型测试边界：

1. `PickupStoreTests`
   - 加载成功与读取失败提示；
   - 自动导入无关文本保持安静；
   - 成功、重复、完成失败、撤销和交接后的 records/notice 状态；
   - 使用临时目录中的真实 `PickupRepository`，不 mock 业务规则。
2. `ClipboardImportPolicyTests`
   - 功能关闭时不读取；
   - `changeCount` 未变化时不读取；
   - 新变化只产生一次读取请求；
   - 并发检查期间不重复进入；
   - 已读取但无字符串时也记住本次变化，避免反复询问；
   - 记录先加载、剪贴板后检查的启动顺序不被改回去。

实现上只抽出一个很小的 `ClipboardImportPolicy` 或 coordinator，并为系统剪贴板提供一个可替换的读取协议。它只负责生命周期判断和读取编排，文本是否属于取件通知仍由 `PickupParser` 决定，写入与去重仍由 `PickupRepository` 决定。

### 阶段 2：机械拆分完整功能页

按以下顺序逐批移动，每批只处理文件边界和访问级别：

1. `Handoff`：交接选择、预览和系统分享包装；
2. `ImageImport`：图片识别确认与候选行；
3. `Settings`：关于、导入设置和自动化引导；
4. `PickupMode`：大字模式、代码页和编辑表单；
5. `Inbox`：情绪文案、卡片与首页剩余布局。

每一批都必须保持 sheet identity、绑定、回调、无障碍标签和动画参数不变。每批单独通过全量测试后再进入下一批。目标不是追求最少行数，而是让 `InboxView.swift` 不再包含其他功能的完整页面；预计最终控制在约 500 至 700 行。

### 阶段 3：整理测试文件，不重写测试框架

随着覆盖增加，将现有测试按职责拆开：

```text
ShouxiaTests/
  PickupParserTests.swift
  ImagePickupExtractorTests.swift
  PickupRepositoryImportTests.swift
  PickupRepositoryLifecycleTests.swift
  PickupHandoffPackageTests.swift
  PickupStoreTests.swift
  ClipboardImportPolicyTests.swift
  Fixtures/
```

真实 OCR 图片夹具应使用去除手机号、姓名、地址和运单号后的合成或脱敏图片，纳入测试 bundle。完成后把现在依赖环境变量的两个 OCR 用例分成：默认必跑的小型脱敏夹具，以及开发者可选的外部批量样本。

### 阶段 4：增加最小 UI 测试层

新建 `ShouxiaUITests` target，只覆盖稳定且高价值的路径：

1. 空列表启动并能看到导入入口；
2. 带一条待取 fixture 启动，进入大字模式并返回；
3. 完成一条记录后出现撤销，撤销后回到待取；
4. 打开记录页，恢复为待取；
5. 打开隐私与关于、导入设置和自动化说明，关键控件存在且无障碍名称正确。

fixture 通过 `DEBUG` 下的固定 launch argument 选择，例如 `-ui-test-scenario pending-one`。App 为该场景创建临时 repository，禁止连接正式本地数据。沿用已有 `-screenshot-mode` 和 `-keep-undo-visible`，但把参数解析集中到一个 `AppLaunchOptions`，避免各视图重复读取 `ProcessInfo`。

UI 自动化只验证可见状态和核心导航，不做像素级截图断言，也不依赖随机文案。测试中为关键元素增加稳定的 accessibility identifier；面向用户的 accessibility label 继续保持自然中文，两者职责分开。

### 阶段 5：统一本地质量门禁

新增一个可重复执行的本地检查脚本，按顺序运行：

```text
git diff --check
plutil 校验 Info.plist 与 PrivacyInfo.xcprivacy
xcodebuild test（ShouxiaTests）
xcodebuild test（ShouxiaUITests，仅在已有可用 Simulator 时）
xcodebuild analyze
```

脚本不自动启动 Simulator、不安装真机、不归档、不上传。GitHub Actions 等远程 CI 等本地门禁稳定后再加，并锁定与工程兼容的 Xcode 版本；远程 CI 不能替代真机产品验收。

## 测试分层与边界

| 层级 | 自动化覆盖 | 不放在这一层 |
| --- | --- | --- |
| 解析与模型单元测试 | 自动/手动语义边界、验证码排除、取件码格式、地点、指纹、旧数据解码 | 系统剪贴板授权 |
| Repository 集成测试 | 去重、抑制记录、持久化、损坏文件、完成/撤销、归档/删除、交接原子性 | SwiftUI 导航 |
| Store 状态测试 | records、notice、乐观完成与失败回滚、入口调用结果 | 系统 sheet 和动画观感 |
| 生命周期策略测试 | enabled、changeCount、重复进入、启动顺序、静默忽略 | 真实 `UIPasteboard` 弹窗 |
| XCUITest 冒烟测试 | 启动 fixture、主要导航、完成/撤销、关键无障碍标识 | PhotosPicker、分享面板、快捷指令跨 App 流程 |
| 真机验收 | 粘贴授权、前后台切换、相册、微信/AirDrop 交接、短信自动化、VoiceOver、减少动态效果 | 可被稳定单测覆盖的纯业务规则 |

## 优先补充的回归用例

第一批测试应直接围绕已经发生过或风险最高的问题：

- 删除由自动剪贴板导入的记录后，保持同一剪贴板内容并重新进 App，不再自动出现；
- 自动剪贴板拒绝“验证码 829146”“登录码 829146”和裸数字；
- 自动剪贴板接受“取件码 829146”，手动粘贴仍接受 `829146`；
- 相同待取码来自不同完整文案或不同入口时只保留一条；
- 已完成的短码可被未来不同通知复用；
- 本地已有记录时启动，记录加载期间不切成错误的空状态；
- 同一个 pasteboard `changeCount` 在多次 active 事件中只读取一次；
- repository 文件或抑制文件损坏时显示可理解的错误，并且不覆盖原文件。后一个用例如果需要恢复策略，应先单独确定产品行为再实现。

## 每批提交的完成标准

- 只包含当前批次的结构或测试变化，不夹带新的产品需求；
- `git diff --check`、plist 校验和全量单元测试通过；
- 新增文件全部进入正确 target，Release 配置也能编译；
- 结构拆分前后的用户可见文案、无障碍标签、动画和数据格式一致；
- 文档中的测试数量和发布状态随实际结果更新；
- 真机、Archive、TestFlight 和 GitHub 推送只在用户明确要求对应层级后执行。

## 推荐的第一个实施批次

先执行“阶段 0 + 阶段 1”，不要立即拆 2357 行的视图。原因是最近的问题集中在启动顺序和剪贴板生命周期；先把这些规则变成确定性测试，后续移动页面时才能快速判断是纯结构变化还是行为回归。完成这批后，再从依赖最少的 `Handoff` 视图开始机械拆分。
