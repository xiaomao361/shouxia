# 收下 1.2.12（30）TestFlight 上传记录

2026-10-20，用户明确授权提交 TestFlight。本包保留当前已安装开发包的实现：恢复1.2.11（27）外观方案，以1.2.12（30）交付，不复用旧build。恢复范围与手机安装凭据见[设备记录](DEVICE_1.2.12_30.md)。

## 来源与验证

- 主App、分享扩展、小组件版本均1.2.12（30），最低系统iOS16.0；Release签名归档成功。
- 与本次已安装开发包的62项文件快照逐项SHA-256一致，归档后及上传后再次核对通过；恢复对照中应用/测试源码与27相同，只有工程版本/build元数据不同。
- 三个bundle严格签名、App Group、Mach-O/dSYM UUID一致性及主App深度签名检查通过；声明不使用非豁免加密。Xcode27.1（27A9275）。
- 本次恢复已新跑162项host测试，0失败；Debug构建/签名及iPhone14Pro安装、独立版本读回通过。上传没有修改应用源码，沿用这些检查，不重复运行相同测试；不等同于真机明暗/息屏/OCR全场景验收。
- 继续使用原生ActivityKit容器，通过官方颜色接口提供浅/深配色；未仿制通知玻璃。主App启动、回前台和前台外观变化时同步主题；App关闭期间切换系统主题仍需再次打开收下。
- 归档与凭据目录：`.private/releases/1.2.12-30/`，包含`Shouxia-1.2.12-30.xcarchive`、`archive-validation.json`、`source-manifest.json`、`source-snapshot/`与`restore-comparison.json`。
- 沿用既有AppStoreExportOptions：app-store-connect、destination=upload、自动签名、不自动改版本；`uploadSymbols=false`，dSYM保存在本地归档。

## 上传状态

**2026-10-20 09:14:35 +0800 上传成功，Apple已接收并开始处理。** `xcodebuild -exportArchive`退出0，日志包含`Uploaded package is processing.`、`Upload succeeded.`和`EXPORT SUCCEEDED`。

回执和完整日志保存在`.private/releases/1.2.12-30/upload-receipt.json`、`upload.log`，归档日志为`archive.log`。未独立确认Apple处理完成、TestFlight可安装或测试组可见；未修改测试组、邀请测试者、提交Beta Review、App Store正式审核或发布。未操作任何设备/浏览器UI，未Git提交或推送。

## 测试说明（本地草稿，尚未写入App Store Connect）

本版恢复已选定的实时活动浅/深色适配方案，并移除自定义橙色轮廓。打开收下同步当前系统外观后，检查锁屏卡片文字与取件码可读性；切换浅色/深色后再次打开收下检查，并观察息屏、滑动、灵动岛及Mac展示。系统容器在不同宿主上可能呈现不同底色，不承诺与普通通知完全相同。恢复后的实际视觉效果仍由用户复核。

覆盖更新后也请检查原有待取记录、自动收码、截图/分享导入与取件完成正常；发现问题时提供版本、系统版本、入口及预期/实际结果。后续交付新包继续使用更高build，1.3.x范围和时间另定。
