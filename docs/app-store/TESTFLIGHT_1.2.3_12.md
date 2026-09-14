# 收下 1.2.3 (12) TestFlight 测试说明

Status: Uploaded — `1.2.3 (12)` 于 2026-09-14 10:57 +0800 上传成功，Apple 返回 `Uploaded package is processing` 与 `Upload succeeded`；尚未确认处理完成。由用户自行配置 TestFlight 开测，本轮不提交正式 App Store 审核。

## What to Test

本轮修复一条短信共用一个“取货码”标签时漏掉后续取货码的问题，并补充妈妈驿站地点识别，保留 Build 11 的暗色模式适配。

1. 粘贴一条包含两个取货码的通知，确认两个码分别保存，取件地点正确。
2. 重复粘贴同一条通知，确认不会重复添加；旧版本已经保存第一个码时，再次粘贴只补上第二个码。
3. 通过短信自动化导入同类通知，确认能保存两个码。
4. 导入同一行含两个取货码的截图，检查识别结果、地点与重复保护。
5. 从现有版本覆盖安装，确认待取、已完成、归档和设置数据保留；回归浅色与暗色外观。

## 已验证

- 2026-09-14：iPhone 17 Pro / iOS 26.5 模拟器自动化测试 54 项通过、0 失败，2 项真实 OCR 图片测试缺少夹具而跳过。
- 2026-09-14：修复源码以开发包覆盖安装到用户 iPhone 14 Pro；用户随后反馈测试未发现问题。反馈限于用户实际测试场景，不追认全部入口或 TestFlight 升级验收。
- Build 从 11 递增为 12。首次以 1.2.2 上传时，Apple 返回 90186（通道关闭）和 90062（必须高于已批准版本），因此 Marketing Version 递增为 1.2.3；除版本号和构建号外，应用源码与本轮通过测试、真机试用的版本一致。
- Release Archive：`/tmp/Shouxia-1.2.3-12.xcarchive`。
- Bundle ID：`com.zhouwei.shouxia`；版本：`1.2.3 (12)`；架构：`arm64`。
- App 与 dSYM UUID：`528228A0-4951-334F-A253-1395A87CFDE9`；归档代码签名校验通过。
- 沿用项目上传配置：自动分发签名、固定 build 号、不上传符号（历史 Xcode 打包问题的已有设置，dSYM 保留在本地归档）。

## 待验收

Apple 处理完成、TestFlight 选组与开测、TestFlight 覆盖安装和实际截图 OCR 验收。

上传回执：`/tmp/shouxia-build12-1.2.3-upload.log`；Xcode 返回 `EXPORT SUCCEEDED`、退出码 0。
