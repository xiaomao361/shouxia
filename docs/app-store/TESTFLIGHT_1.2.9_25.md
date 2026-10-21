# 收下 1.2.9（25）TestFlight 上传记录

2026-10-19。用户在 iPhone 14 Pro 安装开发包后反馈“看起来好像没啥事”，授权提交 TestFlight，供其他人测试。记录为一般试用反馈，不扩大为全部模板、入口或设备验收。

## 构建与来源

- 当前已试用工作树，主 App、分享扩展、小组件均 **1.2.9（25）**；最低系统 16.0。
- 识别源码与已安装开发包及自动验收快照一致。51 项应用/工程源码副本与 SHA-256 保存在 `.private/releases/1.2.9-25/source-snapshot/` 和 `source-manifest.json`；归档后逐项核对一致。原有截图脚本/素材的未提交改动保留。
- Xcode **27.1 / 27A9275**。Release 签名归档成功；三个 bundle 的严格签名、App Group、最低系统及 Mach-O/dSYM UUID 校验通过。App 声明不使用非豁免加密。
- 归档 `.private/releases/1.2.9-25/Shouxia-1.2.9-25.xcarchive`；校验同目录 `archive-validation.json`。
- 沿用 `scripts/AppStoreExportOptions.plist`：app-store-connect、destination=upload、自动签名、固定版本号。`uploadSymbols=false` 保持既有设置，dSYM 保存在本地归档。

## 本版与验证

离线规则随安装包分发，未增加规则下载或通知上传。候选、数字用途、替代/备选关系与保存决策分层；保留不可用、待核对及部分完成状态，补齐尾号/日期/分机误收、同行误排除、引用格式、遮挡、更正与多码列表遗漏保护。

158 项主机测试通过；240 条开发输入、957 次入口调用、1968 项断言通过。含 135 条同家族格式变体，不是独立真实模板或产品准确率。源码与验证工具未变化，沿用已有检查，没有为上传重复运行无变化的测试。详见[改造与验证](../recognition/1.2.9/README.md)。真实模板覆盖、iOS 16 运行及外部测试仍待反馈。

## 上传状态

**2026-10-19 11:13:18 +0800 上传成功，Apple 已接收并开始处理。** `xcodebuild -exportArchive`退出0，日志明确包含 `Uploaded package is processing.`、`Upload succeeded.` 和 `EXPORT SUCCEEDED`。

回执：`.private/releases/1.2.9-25/upload-receipt.json`；日志：`/tmp/shouxia-129-upload.log`。上传后51项源码与归档快照一致。未独立确认处理完成、TestFlight可安装或测试组可见；本轮没有更改测试组、邀请测试者或提交Beta Review，测试说明尚未写入App Store Connect。

未操作手机、Simulator、Xcode 或浏览器 UI；未提交代码或推送，未提交 App Store 正式审核或发布。

## 给测试者的说明（本地草稿，尚未写入 App Store Connect）

本次主要改进取件信息识别稳定性，所有识别仍在本机完成。

请先确认覆盖更新后原有待取、历史和设置正常，再用你平时收到的真实通知测试：

1. 从文字、短信自动收码、截图或系统分享导入，核对完整取件码、前导零、取件点和快递信息。
2. 通知带有尾号、日期、电话或分机时，这些数字不应被误存为取件码。
3. 多条通知和多个取件码应尽量完整保留；有遮挡、截断或不明确的内容时，应提示核对或遗漏。
4. 试用保存前更正、取消勾选、重复导入，以及从其他 App 分享后重新打开收下接收。已有正常使用的自动收码快捷指令无需重设。

发现问题时，请说明 App 版本、iOS 版本、导入入口、实际结果与期望结果。分享原文或截图前可遮挡姓名、电话、地址等私人信息，并保留与识别错误有关的格式。
