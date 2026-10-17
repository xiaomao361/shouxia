# 1.2.8（24）识别热修上传记录

2026-10-17 用户授权上传正式热修构建，说明当前无法进行本机或 TestFlight 测试，由用户在 App Store Connect 选择构建、送审及发布。该授权允许继续上传，不作为真机运行验收。

## 来源与归档

- 主 App、分享扩展、小组件 Release 归档统一 **1.2.8（24）**，最低系统 16.0；Xcode 27.0 / 27A266a。
- 签名、App Group、三个二进制及对应 dSYM UUID 检查通过；App 声明不使用非豁免加密。
- 51 项应用/工程文件归档前快照与归档后源码哈希一致。`.private/releases/1.2.8-24/source-manifest.json` 和 `source-snapshot/` 保留归档源码；不包含在 Git 提交中。
- 签名归档：`.private/releases/1.2.8-24/Shouxia-1.2.8-24.xcarchive`；校验：同目录 `archive-validation.json`。
- 沿用既有 `scripts/AppStoreExportOptions.plist`，上传 App Store Connect、自动签名、不自动更改版本号；`uploadSymbols=false`，dSYM 保留在本地归档。

## 测试结论

- 153 项主机测试，0 失败；新增 30 条构造输入对照，当前四入口的正常代码序列符合预期。
- 以前的 43 条研究示例和 7 条复核示例完整回放结果与修复前一致，证明本轮没有改变它们已有结果；原有未知地点/歧义仍保留，不能写成“所有示例全部字段识别正确”。
- 用户本次原图在 macOS Vision → 提取器中得到正确取件码、地点；品牌 OCR 误读保留未知。不是 iPhone UIKit 识别验证。
- 本版 generic Simulator Debug 构建及签名设备 Release 归档通过，未启动 App 或操作 UI。未执行 iPhone / TestFlight 测试。
- 修复范围、对照表、原图边界及待验收项见[热修记录](HOTFIX_1.2.8_24.md)。

## 上传状态

**2026-10-17 13:42:34 +0800 上传成功，Apple 已接收并开始处理**。`xcodebuild -exportArchive` 退出码 0，回执包含 `Uploaded package is processing.`、`Upload succeeded.` 和 `EXPORT SUCCEEDED`。尚未独立确认处理完成、可选构建或可安装性。

回执：`.private/releases/1.2.8-24/upload-receipt.json`；日志 `/tmp/shouxia-128-upload.log`。归档后及上传后 51 个源码文件哈希与快照一致。用户后续在 App Store Connect 选择 1.2.8（24）继续送审及发布，本轮没有代为提交审核或发布。

官网、帮助、隐私及商店文案仅在仓库本地同步；未单独执行站点部署或核查线上站点，未将元数据写入 App Store Connect。未提交 Beta Review、App Store 审核或正式发布。
