# 收下 TestFlight 与上架检查表

## 已在工程中完成

- [x] iPhone-only，最低支持 iOS 17
- [x] Bundle ID：`com.zhouwei.shouxia`
- [x] 版本号：`1.0.0`
- [x] 构建号：`1`
- [x] 1024 × 1024、RGB、无透明通道 App Icon
- [x] App 内品牌标志与 App Icon 使用同一套“包裹 + 取件卡”语义
- [x] 工具类别
- [x] 声明不使用非豁免加密
- [x] 隐私清单：不跟踪、不收集数据、无跟踪域名
- [x] App 内“隐私与关于”页面
- [x] 简体中文商店文案
- [x] 隐私政策、支持页和审核说明正文

## 2026-07-28 工程收口验证

- [x] 20/20 单元与集成测试通过，包含真实物流截图的本机 OCR 回归
- [x] Debug 与 Release 模拟器构建通过，Release 构建无警告
- [x] 开发签名真机包构建成功，并已覆盖安装、启动于 iPhone 14 Pro
- [x] 图片导入持久化前会裁剪手机号、运单号和无关 OCR 全文
- [x] 测试代码不保留真实样图中的手机号、运单号、地址或取件码

以上证明当前代码能够构建、运行和识别样图，不等同于 TestFlight 或发布验收。

## Apple Developer Program 与签名状态

- [x] 2026-07-28 已通过中国区 Apple 账户提交 Apple Developer Program 订阅
- [x] 2026-07-29 Apple 审核通过，付费会员正式生效
- [x] Team `A5L4GGX82X` 自动签名真机构建成功
- [x] `com.zhouwei.shouxia` 开发 provisioning profile 已生成并嵌入真机包
- [x] 最新开发包已覆盖安装并启动于已配对的 iPhone 14 Pro
- 美区 Apple 账户无法完成购买：账户余额不能替代有效付款方式，现有 Visa 卡也未被该账户接受

## 提交前必须完成

- [x] 确认 Apple Developer Program 付费会员有效
- [x] 在 App Store Connect 创建 App 记录并确认“收下”名称可用
- [x] 确认开发者法定姓名为周维，公开支持邮箱为 zhouwei@linux.com
- [x] 发布 GitHub Pages，并验证隐私政策和支持页的公开 HTTPS URL
- [x] 录入 App 隐私答案：不收集数据
- [x] 完成新版年龄分级问卷
- [x] 确认价格免费、首发销售地区中国大陆、审核通过后手动发布
- [x] 在 App Store Connect 完成中国大陆销售范围与合规字段
- [x] 准备 5 张不含真实个人信息的 6.5 英寸 `1242 × 2688` iPhone 截图
- [x] 使用 Xcode 26.6 Archive 并上传 `1.0.0 (1)`
- [x] 完成出口合规声明
- [x] 准备审核联系人姓名、邮箱和电话（保存在本地忽略文件中，不提交公开仓库）
- [x] 2026-07-29 09:55 正式提交 App Review
- [x] 2026-08-13 `1.0` 审核通过并手动发布；中国大陆供应状态为“可供应”
- [x] 中国大陆 App Store 产品页：`https://apps.apple.com/cn/app/id6795735956`

## 2026-07-30 TestFlight 改造

- [x] `1.0.0 (1)` 已审核通过并在中国大陆上架
- [x] 已知错误引导已由后续 TestFlight 候选替换
- [x] 首页明确区分“自己的短信”和“他人托取”
- [x] 普通快捷指令“收下自动收码”经过真机导入验证
- [x] App 内说明完整覆盖“快捷指令输入 → 文本 → 短信内容”
- [x] 个人自动化运行普通快捷指令，而不是直接选择 App Intent
- [x] Debug/Release 构建号均升级为 `2`
- [x] 2026-07-30 09:22 Archive 并上传 `1.0.0 (2)`；App Store Connect 已进入处理
- [x] Build 2 处理完成并可通过 TestFlight 安装；用户已确认真机安装
- [x] 生成 7 张新的 `1242 × 2688` App Store 截图，包含真实快捷指令与个人自动化页面
- [ ] 在 App Store Connect 中用新 7 张替换旧 5 张
- [ ] 填写 Beta App Description、Feedback Email 和 What to Test
- [x] Build 4 关键真机验收完成后再提交正式 App Review

## 2026-08-03 TestFlight 1.1.0 (3)

- [x] Marketing Version 升级为 `1.1.0`，Build Number 升级为 `3`
- [x] 交接包创建、系统分享、冷启动预览、批量导入与同包去重已进入构建
- [x] 自动化设置入口支持手动隐藏、设置完成隐藏、首次自动化导入后隐藏一次，并可在“关于”恢复
- [x] Release archive 成功，确认 Bundle ID `com.zhouwei.shouxia`、版本 `1.1.0 (3)`、架构 `arm64`
- [x] 2026-08-03 11:04 上传成功；Apple 回执为 `Uploaded package is processing`
- [x] Xcode 26.6 的 `uploadSymbols=true` 在发行打包阶段稳定触发 `Copy failed`；本构建关闭符号上传后成功
- [x] Build 3 已由 Build 4 替代，不再作为正式更新候选
- [ ] 如需外部测试，再配置外部测试组、Beta 测试说明并提交 TestFlight Beta Review

## 2026-08-13 TestFlight 1.1.0 (4)

- [x] Build Number 从 `3` 升级为 `4`
- [x] 包含首页滚动问题修复；Build 4 替代 Build 3 作为后续测试候选
- [x] Release archive 成功，确认 Bundle ID `com.zhouwei.shouxia`、版本 `1.1.0 (4)`、架构 `arm64`
- [x] 2026-08-13 08:40 上传成功；Apple 回执为 `Uploaded package is processing`
- [x] App Store Connect 处理完成，Build 4 已通过 TestFlight 安装
- [x] 真机验证长列表可滚动到底部，内容不被底部区域遮挡
- [x] 从 App Store `1.0` 升级到 TestFlight Build 4 后，本地数据保留
- [x] 两台真机完成“生成交接包 → 系统分享 → 冷启动预览 → 批量导入 → 重复打开保护”验收
- [x] Build 4 确认为 `1.1.0` 正式更新候选

## 2026-08-25 真机验收中 1.2.0 (5)

- [x] Marketing Version 升级为 `1.2.0`，Build Number 升级为 `5`
- [x] 首页改为原生 `List` 与 `swipeActions`，避免整卡手势和纵向滚动争抢
- [x] 大字取件模式增加“已取到，收下”，同地点自动进入下一件
- [x] 增加取件码和地点更正，并保持原始导入指纹用于重复保护
- [x] 一次选择最多五张取件截图，逐张本机 OCR 后按取件码跨图去重
- [x] 同批导入记录在地点缺失时仍可连续取件
- [x] 增加常用取件点，并区分识别、常用默认和用户更正地点
- [x] 增加默认关闭的“打开时识别剪贴板”，只在前台且剪贴板变化时尝试一次
- [x] 系统主动粘贴入口改用 SwiftUI `PasteButton`
- [x] 30 个自动化测试执行完成：28 个通过，2 个可选真实图片夹具测试跳过
- [ ] 用本轮两张真实重叠截图运行批量 OCR 夹具测试（宿主机临时路径尚未传入模拟器测试进程）
- [x] Debug 模拟器构建通过
- [x] Release 模拟器构建通过
- [x] 本地 arm64 Release Archive 成功，版本 `1.2.0 (5)`，App 与 dSYM UUID 一致
- [x] 确认本地 Archive 为开发签名；App Store 分发签名与上传验证留到明确执行 TestFlight 上传时完成
- [x] 最终差异检查通过
- [x] Debug 真机包构建、签名并安装到 iPhone 14 Pro；设备确认版本 `1.2.0 (5)`、类型为 Developer App
- [x] 用户已开始使用最新开发包做日常真机试用，当前已测场景未发现明显问题
- [ ] 真机验证长列表滚动、连续完成、最后一件返回、撤销和更正
- [ ] 真机验证多图重叠去重、同批连续取件和常用取件点来源标记
- [ ] 真机验证剪贴板自动识别的系统授权、有效内容、无关内容和关闭状态
- [x] 准备 `1.2.0 (5)` TestFlight Beta Description、What to Test 和反馈清单
- [ ] 生成并上传新的 TestFlight 构建

## 2026-08-27 当前源码候选 1.2.0 (6)

- [x] Marketing Version 保持 `1.2.0`，Build Number 升级为 `6`
- [x] 系统分享成功结束后，发送方所选记录以“交给别人”完成本侧流程并离开待取
- [x] 取消系统分享不改变发送方记录
- [x] 交接批次本地更新保持原子性；任一记录已非待取时不部分更新
- [x] 旧本地记录缺少 `handedOffAt` 时仍可解码
- [x] 收下记录展示“交给别人”标记，并可恢复为待取
- [x] 32 个自动化测试执行完成：30 个通过，2 个可选真实图片夹具测试跳过
- [x] Debug 模拟器测试构建通过
- [x] Release 模拟器构建通过
- [x] 本地 arm64 Release Archive 成功，确认 Bundle ID `com.zhouwei.shouxia`、版本 `1.2.0 (6)`，App 与 dSYM UUID 一致
- [ ] 真机验证微信或信息分享成功后移出待取并正确标记
- [ ] 真机验证取消分享、恢复待取、批量交接和辅助功能文案
- [x] 2026-08-27 15:03 上传成功；Apple 回执为 `Uploaded package is processing` 与 `Upload succeeded`
- [x] 准备 Build 6 的 TestFlight 测试内容，覆盖交接终态、上一轮界面与取件流程、导入和升级回归
- [ ] 确认 App Store Connect 处理完成且 Build 6 可在 TestFlight 安装
- [ ] 如需外部测试，再配置测试组、Beta 测试说明并提交 TestFlight Beta Review

## 2026-08-27 剪贴板首屏修复候选 1.2.0 (7)

- [x] Build Number 从 `6` 升级为 `7`
- [x] 本地记录加载完成并触发首屏更新后，再异步检查发生变化的剪贴板
- [x] 30 个自动化测试通过，2 个可选真实图片夹具测试按设计跳过
- [x] Debug 真机构建、签名并覆盖安装到 iPhone 14 Pro；设备确认版本 `1.2.0 (7)`
- [x] 准备 Build 7 TestFlight 测试内容，增加启动首屏与剪贴板授权回归
- [ ] 真机确认复制新内容后进入 App 时，已有取件码不再先闪空
- [x] 本地 arm64 Release Archive 成功，确认 Bundle ID `com.zhouwei.shouxia`、版本 `1.2.0 (7)`，App 与 dSYM UUID 一致
- [x] 2026-08-27 18:17 上传成功；Apple 回执为 `Uploaded package is processing` 与 `Upload succeeded`
- [ ] 确认 App Store Connect 处理完成且 Build 7 可在 TestFlight 安装

## 2026-08-28 自动识别与去重修复候选 1.2.0 (8)

- [x] Build Number 从 `7` 升级为 `8`
- [x] 自动剪贴板只提取与取件标签直接关联的代码，拒绝混有取件提示的验证码文本
- [x] 手动粘贴继续接受独立的 4 至 8 位数字，并统一可访问性提示与错误文案
- [x] 完整原文指纹之外，对当前待取记录按取件码跨入口去重；完成后的短码允许未来复用
- [x] 永久删除保留无上限的本地原文指纹阻止标记，手动粘贴仍可重新添加
- [x] 隐私清单声明 UserDefaults 的 `CA92.1` 使用理由
- [x] 37 个自动化测试通过，2 个可选真实图片夹具测试按设计跳过
- [x] PrivacyInfo plist 校验通过且测试构建确认已打包
- [x] 将当前源码重新构建并覆盖安装到 iPhone 14 Pro；设备确认版本 `1.2.0 (8)`
- [x] 用户完成真机验证，包括自动标签文本、混合验证码、裸数字手动粘贴、跨入口去重和结构拆分后的页面回归
- [x] 2026-08-28 14:50 完成 Release Archive 并上传 App Store Connect；Apple 回执为 `Uploaded package is processing` 与 `Upload succeeded`
- [x] 使用当前真机空首页截图重新生成 `1.2.0` 第二版七张候选；首页及完成反馈图均使用当前“粘贴”按钮
- [ ] 获取真实“请人帮取”界面截图后，再决定是否增加第八张；不使用推测生成的界面
- [ ] 人工确认 `1.2.0` 第二版七张截图候选后，在 App Store Connect 替换现有产品页截图
- [ ] 确认 App Store Connect 处理完成且 Build 8 可在 TestFlight 安装

## 2026-09-03 iPhone 17 Pro 粘贴按钮修复候选 1.2.1 (9)

- [x] Build Number 从 `8` 升级为 `9`
- [x] 首次以 `1.2.0 (9)` 上传时，Apple 返回 `90186`（该预发布通道已关闭）与 `90062`（版本必须高于已批准的 `1.2.0`）；营销版本据此升级为 `1.2.1`
- [x] 系统 `PasteButton` 显式使用图标加标题，并设置稳定的最小尺寸与布局优先级
- [x] 保留系统主动粘贴机制，不改为程序化读取剪贴板
- [x] 重新执行 iPhone 17 Pro 模拟器自动化测试：39 项，37 通过，2 项按预期跳过，0 失败
- [x] 重新完成 `1.2.1 (9)` arm64 Release Archive，核验 Bundle ID `com.zhouwei.shouxia` 与 App/dSYM UUID `7A8FF38E-7627-3412-9C3D-6429B66866AB`
- [x] 上传 App Store Connect 并保存 Apple 上传回执：2026-09-03 09:52:28 +0800，`Uploaded package is processing`、`Upload succeeded`
- [ ] 确认 Build 9 处理完成且可在 TestFlight 安装
- [ ] 在实际复现问题的 iPhone 17 Pro 上验证无文本禁用态与有文本可用态

## 2026-09-04 丰巢地点识别修复候选 1.2.2 (10)

- [x] Marketing Version 从 `1.2.1` 升级为 `1.2.2`，Build Number 从 `9` 升级为 `10`
- [x] 复制文字支持“取件码……至……取件”句式，不再把短信开头的“丰巢】凭”误认为地点
- [x] 图片识别支持跨行组合丰巢地点，并识别“丰巢柜”地点类型
- [x] 图片仅识别到取件码但缺少地点时进入人工确认，不再作为完整高置信度结果自动导入
- [x] 真实问题样本只用于本机验证；仓库测试使用脱敏取件码、地点和链接
- [x] iPhone 17 Pro 模拟器完整测试通过：43 项，41 项通过，2 项可选真实图片夹具测试跳过，0 失败
- [x] 用户在 iPhone 14 Pro 开发包上完成本次丰巢图片与复制文字真机验证，未发现问题
- [x] 完成 `1.2.2 (10)` arm64 Release Archive；核验 Bundle ID `com.zhouwei.shouxia`、版本 `1.2.2 (10)`、架构 `arm64` 与 App/dSYM UUID `533F41AA-57DD-3643-88D7-0FA7FAFB3FF5`
- [x] 2026-09-04 09:25 +0800 上传 App Store Connect；Apple 回执为 `Uploaded package is processing` 与 `Upload succeeded`
- [x] 用户确认 Build 10 已完成 App Store Connect 处理并可通过 TestFlight 安装
- [x] 用户从线上 `1.2.0` 覆盖安装 TestFlight Build 10，已有数据保留，并完成丰巢截图、复制文字和首页粘贴按钮真机回归
- [x] 2026-09-07 发布收口复跑 iPhone 17 Pro / iOS 26.5 模拟器完整测试：43 项，41 项通过，2 项可选真实图片夹具测试跳过，0 失败
- [ ] 如能取得实际复现问题的 iPhone 17 Pro，再补充该机型上的粘贴按钮专项验证；不阻塞当前已验收候选提交审核

## 2026-09-07 暗色模式修复候选 1.2.2 (11)

- [x] 用户在 Build 10 提交审核后发现未完整适配系统暗色模式，并主动取消本次审核
- [x] Build Number 从 `10` 升级为 `11`，Marketing Version 保持 `1.2.2`
- [x] 品牌背景、卡片、四级文字、按钮、强调色、标签、描边和完成反馈改为随系统外观动态解析
- [x] 保持现有浅色品牌颜色不变；暗色模式不使用简单反色，也不强制覆盖用户系统外观
- [x] 新增颜色模式与对比度测试；暗色正文和主按钮关键组合均达到至少 `4.5:1`
- [x] iPhone 17 Pro / iOS 26.5 模拟器完整测试通过：46 项，44 项通过，2 项可选真实图片夹具测试跳过，0 失败
- [x] 用户在 iPhone 14 Pro 开发包上完成浅色与暗色模式真机检查，未发现问题
- [x] 完成 `1.2.2 (11)` arm64 Release Archive；核验 Bundle ID `com.zhouwei.shouxia`、版本 `1.2.2 (11)`、架构 `arm64` 与 App/dSYM UUID `270FD9C2-68E9-3200-8C74-E486615C9725`
- [x] 2026-09-07 11:21 +0800 上传 App Store Connect；Apple 回执为 `Uploaded package is processing` 与 `Upload succeeded`
- [ ] 通过 TestFlight 从 Build 10 覆盖安装 Build 11，确认数据保留与暗色模式回归

## 2026-09-14 多取货码修复候选 1.2.3 (12)

- [x] Build Number 从 `11` 升级为 `12`
- [x] 首次以 `1.2.2 (12)` 上传被 Apple 以 `90186` / `90062` 拒绝：`1.2.2` 已批准、通道关闭；Marketing Version 因此递增为 `1.2.3`
- [x] 同一通知多个取货码分别解析、原子保存和去重；兼容旧首码记录及删除抑制，补充妈妈驿站地点识别与图片同一行多码提取
- [x] 54 项自动化测试通过、0 失败，2 项真实 OCR 夹具测试跳过；用户在 iPhone 14 Pro 开发包试用后反馈未发现问题
- [x] `1.2.3 (12)` arm64 Release Archive 和签名校验成功；App/dSYM UUID 均为 `528228A0-4951-334F-A253-1395A87CFDE9`
- [x] 2026-09-14 10:57 +0800 上传成功，Apple 回执为 `Uploaded package is processing` 与 `Upload succeeded`
- [x] 准备 [Build 12 测试说明](TESTFLIGHT_1.2.3_12.md)
- [ ] Apple 处理完成后由用户配置 TestFlight 测试组并开测
- [ ] TestFlight 覆盖安装、实际短信自动化与截图 OCR 验收；本轮未提交正式审核

## 2026-09-14 普通文字复制候选 1.2.3 (13)

- [x] Marketing Version 保持 `1.2.3`，Build Number 为 `13`
- [x] “请人帮取”默认第一项为交接包，第二项普通文字支持预览与复制；不提供普通文字系统分享按钮
- [x] 文字复制保留待取状态；专用包取消或错误不交接
- [x] 最终源码全套 XCTest：59 通过、2 项真实 OCR 夹具测试跳过、0 失败
- [x] 14:36 +0800 修正版开发包覆盖安装 iPhone 14 Pro，设备读回 `1.2.3 (13)`
- [x] arm64 Release Archive、签名和 App/dSYM UUID 一致性通过：`3DEF012A-ED15-3ACC-AEFF-31B366F78187`
- [x] 14:52:51 +0800 上传成功：`Uploaded package is processing`、`Upload succeeded`、`EXPORT SUCCEEDED`
- [x] 准备 [Build 13 测试说明](TESTFLIGHT_1.2.3_13.md)
- [ ] 确认 Apple 处理完成、TestFlight 测试组可见性
- [ ] TestFlight 覆盖安装及最终交互验收；未提交正式 App Store 审核

## TestFlight 产品验收

- [ ] 从未安装普通快捷指令的状态开始配置
- [x] 用真实取件短信验证“信息自动化 → 收下自动收码 → App Intent”端到端导入
- [x] 验证完整短信正文进入 Intent，而不是空文本或预填常量
- [ ] 验证 App 未启动时自动化仍能保存
- [ ] 验证他人发来的文字可以主动粘贴
- [ ] 用他人发来的真实物流截图验证图片 OCR、候选确认、重复保护和隐私裁剪
- [x] 用两台真机验证“生成交接包 → 系统分享 → 冷启动预览 → 批量导入”和重复打开
- [ ] 验证重复通知不会重复添加
- [ ] 验证滑动完成、五秒撤销、归档、恢复和永久删除
- [ ] 验证 VoiceOver 与“减少动态效果”
- [x] 已从 App Store `1.0` 升级安装 TestFlight Build 4，并确认本地数据保留
- [ ] 一名未参与开发的用户无需口头帮助即可完成自动化配置
- [ ] 记录是否需要“为谁取”字段，以及微信截图导入是否过于繁琐
- [ ] 确认截图和审核样本不包含真实个人信息

## 2026-09-21 1.2.4 (14) 准备

- [x] 主 App 与扩展 Debug/Release 同步 1.2.4 (14)
- [x] README、开发说明、元数据、审核说明及测试说明更新
- [x] 主页、支持页、隐私政策及其 Markdown 版本同步，标明新版待发布
- [x] 新功能核心测试 17 项通过
- [ ] 新版完整真机交互验收
- [ ] 发行 Archive／App Store Connect 上传
- [ ] 网页发布及线上内容核对

详见 [Build 14](TESTFLIGHT_1.2.4_14.md)。
