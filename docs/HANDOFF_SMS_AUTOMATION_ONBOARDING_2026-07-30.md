# 收下短信自动收码与 TestFlight 改造 Handoff

Date: 2026-07-30
Repo: `/Users/zhouwei/Documents/ClaraCore/apps/shouxia`
Branch: `main`
Baseline: `69b0ef31902bfacf422a65d2d2f0cc2742a4b190`（与 `origin/main` 一致）

## 一句话目标

保留已经在真机跑通的“信息个人自动化 → 快捷指令 → 收下 App Intent”能力，把产品重构为“自己的自动收、别人托的随手收”的双入口取件码收件箱，修正 App 内错误引导及对应材料，用 `1.0.0 (2)` 完成 TestFlight 验收；真实用户验收完成前不重新提交 App Review。

本 handoff 的当前执行计划见：

- [`PLAN_DUAL_INTAKE_AUTOMATION_TESTFLIGHT_2026-07-30.md`](PLAN_DUAL_INTAKE_AUTOMATION_TESTFLIGHT_2026-07-30.md)

已生成并验证可访问的普通快捷指令分享页：

- 名称：`收下自动收码`
- iCloud 链接：`https://www.icloud.com/shortcuts/cd785f47a8244d32b1cf3c7c6f4dad8a`
- 页面元数据已确认标题正确；仍需在真机验证首次导入、重复导入和导入失败路径。

## 当前真实状态

### 功能不是不可行

用户已在真机完成端到端测试，确认以下链路能够把新收到短信的完整正文自动传给“收下”并成功解析、保存：

```text
“信息”个人自动化收到匹配短信
→ 运行一个普通快捷指令
→ 从“快捷指令输入”中获取文本
→ 调用“保存取件短信”，将“短信内容”连接到上一步的“文本”
→ 收下后台解析并保存
```

因此：

- “短信自动收码”是已获得真机证据的产品能力；
- `SavePickupMessageIntent` 能接收字符串并调用统一的 `PickupRepository`；
- 当前问题是配置引导错误，不是底层能力不存在；
- App 不读取短信历史，也不拦截通知；正文由用户创建的系统“信息”个人自动化传入。

### 当前发布状态

2026-07-30 在 App Store Connect 实际页面确认：

- App：`收下`
- 版本：`iOS App 1.0`
- Build：`1.0.0 (1)`
- 状态：`等待审核`
- 提交时间：`2026-07-29 09:55`
- 发布方式：审核通过后手动发布
- 页面提供“取消提交”操作

用户已决定先通过 TestFlight 验证本轮产品和引导改造，不着急发布正式版本。针对这次核心引导问题，用户此前已决定撤回正式审核，但本 session 没有替用户点击，也没有获得撤回完成后的状态证据。开始执行时必须先确认当前 App Store Connect 状态，不能把“等待审核”或“已撤回”当作既成事实。

如果仍是“等待审核”，应使用“取消提交”撤回本次审核。这不是下架 App；当前 App 尚未发布。撤回后通常显示“开发者拒绝”，修复后可选择新 Build 再次提交，审核队列会重新开始。

Apple 说明：

- <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/remove-a-submission-from-review>
- <https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses>

## 当前错误及根因

错误入口位于 `Shouxia/Features/InboxView.swift` 的 `AutomationSetupView`。

现有四步引导让用户：

```text
自动化 → 信息 → 设置“包含取件” → 直接选择“保存取件短信”
```

这个流程漏掉了把触发器输入转换成文本并连接到 App Intent 参数的步骤。结果是自动化虽然可以触发，但“保存取件短信”的“短信内容”参数没有获得短信正文。

以下现有描述也需要同步修正：

- `docs/DEVELOPMENT.md`
- `docs/PRODUCT_SEED.md`
- `docs/app-store/APP_REVIEW_NOTES.md`
- `docs/app-store/METADATA_ZH_HANS.md`
- `docs/app-store/RELEASE_CHECKLIST.md`
- 第 3 张 App Store 截图及其生成素材：
  - `docs/app-store/screenshots/raw/03-automation.png`
  - `docs/app-store/screenshots/final/03-message-automation.png`
  - `docs/app-store/screenshots/final-6.5/03-message-automation.png`

特别需要删除或改写的错误认知：

- 不能再暗示个人自动化可直接选择 App 动作后自然获得短信正文；
- 不能再说 App Shortcut 卡片“无需单独运行”就足以完成整条链路；
- `AppShortcutsProvider` 只注册 App 动作，不会创建普通快捷指令或个人自动化；
- 第三方 App 不能静默创建、修改或查询用户的“信息”个人自动化。

## 目标用户流程

### 双入口产品模型

```text
自己的快递
→ “信息”个人自动化
→ 普通快捷指令“收下自动收码”
→ 收下 App Intent
→ 自动进入待取列表

家人朋友托取的快递
→ 粘贴聊天文字 / 识别物流截图
→ 进入同一个待取列表
```

核心表达：

> 自己的自动收，别人托的随手收。

### 推荐方案：一个可导入的普通快捷指令 + 两屏个人自动化引导

先创建并分享一个普通快捷指令，建议命名为“收下自动收码”，其内部固定为：

```text
动作 1：从“快捷指令输入”中获取文本
动作 2：保存取件短信
        短信内容 = 动作 1 输出的“文本”
```

App 内提供“添加收下自动收码快捷指令”入口，打开经过真机验证的 iCloud 快捷指令分享链接。用户导入后，再由图文引导创建个人自动化：

```text
快捷指令 → 自动化 → 新建个人自动化 → 信息
→ 发件人：任何发件人
→ 信息包含：取件
→ 立即运行
→ 执行动作：运行快捷指令
→ 选择“收下自动收码”
→ 保存
```

这样可以把最容易接错变量的普通快捷指令压缩成一次导入；由于 iOS 没有公开 API 允许 App 代建“信息”个人自动化，后半段仍必须由用户手动完成。

### 降级方案：完整手动图文引导

如果无法在本轮建立、长期维护并验证 iCloud 分享链接，则 App 内必须完整展示两阶段配置：

1. 新建普通快捷指令，并正确连接“快捷指令输入 → 获取文本 → 保存取件短信”；
2. 新建“信息”个人自动化，用“运行快捷指令”调用它。

不能为了减少页面长度再次省略第一阶段。

### 本轮需要作出的产品决定

优先实际尝试推荐方案。只有在 iCloud 链接无法稳定用于新用户安装时，才退回完整手动引导。无论选择哪种方案，都必须用一台真实 iPhone 从“未安装该普通快捷指令”的状态走完整配置。

## 实现范围

### 1. 修正 App 内引导

修改 `AutomationSetupView`，至少做到：

- 解释系统限制：App 不能替用户创建个人自动化；
- 把“普通快捷指令”和“个人自动化”明确分成两个阶段；
- 若采用 iCloud 链接，提供明确的导入按钮及失败后的手动路径；
- 用截图或足够清晰的逐步说明展示“运行快捷指令”的选择；
- 不声称 App 能判断自动化是否配置成功；
- 保留“使用第一条真实短信验证”的提示；
- 明确只支持进入苹果“信息”App 的 SMS/iMessage，不支持读取支付宝等第三方通知。

不要在尚未获得真实分享链接前提交占位 URL。

### 2. 保持底层 App Intent 边界

重点复核 `Shouxia/Intents/SavePickupMessageIntent.swift`，但不要因引导问题无故重写已跑通的导入链路：

- 参数仍为完整短信正文字符串；
- `openAppWhenRun = false`；
- App Intent、粘贴和图片入口继续共用 `PickupRepository`；
- 去重、本地处理和隐私边界保持不变。

如需修改 Intent，只能由新的失败证据驱动，并补充对应测试。

### 3. 同步开发文档和产品事实

至少更新：

- `docs/DEVELOPMENT.md`：写入真实两段式链路和真机验收结果；
- `docs/PRODUCT_SEED.md`：修正 implementation update；
- `README.md`：如首页直接描述了错误流程则同步；
- `docs/LESSONS.md`：记录“自动化触发成功不等于正文已传入”的可复用教训。

文档必须区分：

- App Intent 已被系统注册；
- 自动化成功触发；
- 完整短信正文成功传入；
- App 在后台成功解析并持久化。

只有最后两项都获得真机证据，才能称为“短信自动收码端到端成功”。

### 4. 重做测试与商店材料草案

更新：

- `docs/app-store/METADATA_ZH_HANS.md`
- `docs/app-store/APP_REVIEW_NOTES.md`
- `docs/app-store/RELEASE_CHECKLIST.md`
- 第 3 张商店截图和对应生成脚本/素材

商店说明应继续诚实表达“需要一次系统快捷指令设置”，并避免让用户以为 App 可以直接读取短信或通知。

第 3 张截图必须展示修正后的真实流程。不能继续使用当前四步错误引导截图。商店截图本轮先作为 TestFlight 讨论和验收草案，不在用户测试完成前用于重新提交正式 App Review。

审核说明应给审核员一条最短可验证路径：

- 粘贴示例文本可直接验收主要解析能力；
- 短信自动化是可选系统配置；
- 如需验证自动化，提供准确的两阶段步骤；
- 不要求审核员登录；
- 不声称 App 读取短信历史或通知中心。

### 5. 版本、Build 与 TestFlight

- 保持营销版本 `1.0.0`；
- 将 `CURRENT_PROJECT_VERSION` 从 `1` 更新为 `2`，Debug/Release 配置保持一致；
- `1.0.0 (2)` 已于 2026-07-30 09:22（Asia/Shanghai）Archive 并上传成功，随后完成 App Store Connect 处理；用户已确认在真机安装 TestFlight 构建；
- 不删除或覆盖 `1.0.0 (1)`；
- 先加入 TestFlight 内部测试组；
- 根据真实反馈继续使用后续 Build 迭代；
- 本轮不选择 Build 2 重新提交正式 App Review。

## 验收标准

### 工程检查

- `git diff --check` 通过；
- 项目单元/集成测试全部通过；
- Debug 与 Release 构建通过；
- 版本显示为 `1.0.0 (2)`；
- 不引入账号、服务器、分析 SDK 或新的数据收集。

### 真机端到端验收

必须在真实 iPhone 上从配置起点完整走一遍，不能只手动运行 App Intent：

1. 删除或停用旧测试自动化，确保不会被历史配置“误证明”；
2. 按 App 新引导添加普通快捷指令；
3. 创建“信息”个人自动化并选择“立即运行”；
4. 让设备收到一条包含“取件”的真实测试短信；
5. 确认自动化自动触发；
6. 确认完整短信正文进入 Intent，而不是空文本或预填常量；
7. 确认 App 未在前台时仍能保存；
8. 打开 App，核对取件码、地点、来源和录入时间；
9. 再次输入同一正文，确认去重；
10. 输入不匹配触发条件的短信，确认不会导入。

不要把以下证据单独当作端到端成功：

- App Shortcut 卡片存在；
- “保存取件短信”动作能被搜索到；
- 手动运行 Intent 成功；
- 自动化显示已运行；
- 模拟器测试通过。

### 引导验收

请一名没有参与开发的人仅按 App 内说明配置；如果仍需要开发者口头补充“还要获取文本”或“这里要运行另一个快捷指令”，引导即未通过。

### TestFlight 验收

- App Store Connect 已确认旧提交的当前状态，并记录是否撤回；
- Build `1.0.0 (2)` 处理完成并加入内部测试组；
- 新七张截图均为 `1242 × 2688`，第 3、4 张分别展示真实快捷指令导入和个人自动化配置；
- 元数据、隐私说明、支持页和审核说明与 Build 2 一致；
- 审核样本和截图不含真实手机号、地址、取件码或账号；
- 一名未参与开发的用户能仅按 App 内说明完成设置；
- 自己的短信自动进入，别人发来的文字或截图可以轻松录入；
- 本轮没有重新提交正式 App Review，也没有公开发布。

## 明确不做

- 不尝试拦截通知中心；
- 不尝试读取短信历史；
- 不承诺支持支付宝、菜鸟、丰巢等第三方 App 通知自动导入；
- 不引入短信扩展、私有 API、服务器转发或云端解析；
- 不把个人自动化伪装成 App 可以静默安装的能力；
- 不在本轮扩展账号、同步、家庭共享或物流追踪。

## 工作区保护

创建本 handoff 前，工作区已经存在以下未提交改动，它们属于之前的 App Store 准备工作，不能清理、重置或覆盖：

```text
 M README.md
 M docs/app-store/METADATA_ZH_HANS.md
 M docs/app-store/RELEASE_CHECKLIST.md
 M scripts/render_app_store_screenshots.sh
?? docs/app-store/screenshots/final-6.5/
?? scripts/AppStoreExportOptions.plist
```

下个 session 开始时重新运行 `git status --short`，逐文件确认这些改动与本轮修复如何合并。不要使用 `git reset --hard`、`git checkout --` 或自动 stash。

## 下个 session 的建议起手式

```text
请在 /Users/zhouwei/Documents/ClaraCore/apps/shouxia 继续双入口产品与短信自动收码改造。
先完整阅读 docs/PLAN_DUAL_INTAKE_AUTOMATION_TESTFLIGHT_2026-07-30.md
和 docs/HANDOFF_SMS_AUTOMATION_ONBOARDING_2026-07-30.md，
核对 App Store Connect 当前状态和 dirty worktree，不要覆盖已有材料。
优先建立并真机验证“可导入普通快捷指令 + 手动创建信息自动化”的路径；
然后修改首页双入口、App 内引导、文档和截图草案，
升级为 1.0.0 (2)，完成测试、Release 构建、真机端到端验收和 TestFlight 内部测试。
未获得真实用户证据前不要重新提交正式 App Review。
```
