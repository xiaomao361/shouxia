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
