# 收下 1.2.1 (9) TestFlight 测试说明

Status: Uploaded — 2026-09-03 09:52:28 +0800 App Store Connect 已接收 `1.2.1 (9)` 并开始处理；等待处理完成与真机验收。

## Beta App Description

收下是给实际去取快递的人使用的本地优先取件码收件箱。自己的取件短信可以通过系统自动化进入，他人托取的文字或连续截图可以通过主动粘贴、本机识别进入。需要请别人代取时，可以批量发送“收下交接包”；分享成功后，发送方本侧流程结束并标记为“交给别人”。

## What to Test

本轮只修复部分 iPhone 17 Pro 上系统粘贴按钮在无可粘贴文字时只剩背景、图标与“粘贴”标题消失的问题。

1. 在剪贴板没有文字时打开首页，确认左侧按钮仍显示禁用态图标与“粘贴”。
2. 从其他 App 复制一段普通文字后返回，确认按钮进入可用态，图标和标题保持可见。
3. 点击粘贴按钮，确认系统主动粘贴行为不变，并能导入 4 至 8 位数字或完整取件通知。
4. 在 iPhone 14 Pro 与实际复现问题的 iPhone 17 Pro 上比较按钮布局，确认左侧按钮不会被右侧“识别取件截图”压缩为空控件。
5. 从 App Store 正式版覆盖安装 Build 9，确认现有待取、已完成和归档记录保留。

## 已知边界

- 本轮不改变剪贴板解析、自动识别、去重、图片识别或交接逻辑；
- 自动剪贴板仍只接受与“取件码、提货码、领取码”等标签直接关联的代码；
- 真机视觉问题必须在实际复现问题的 iPhone 17 Pro 上验收；模拟器通过不代表问题已经在真机关闭；
- 本 Build 仅用于 TestFlight 验证，不代表新的正式 App Store 版本已经提交审核。

## 验证记录

- 2026-09-03：`iPhone 17 Pro / iOS 26.5` 模拟器完整测试通过；39 项，37 通过，2 项按预期跳过，0 失败。
- 测试结果：`/tmp/shouxia-build9-test/Logs/Test/Test-Shouxia-2026.09.03_09-43-56-+0800.xcresult`
- `1.2.0 (9)` 首次上传被 Apple 校验拒绝，未进入 TestFlight；错误码 `90186`、`90062`。正式版已是 `1.2.0`，候选因此升级为 `1.2.1 (9)`。
- 2026-09-03：`1.2.1 (9)` arm64 Release Archive 成功；Bundle ID `com.zhouwei.shouxia`。
- App 与 dSYM UUID：`7A8FF38E-7627-3412-9C3D-6429B66866AB`。
- 归档：`/tmp/Shouxia-1.2.1-9.xcarchive`
- 2026-09-03 09:52:28 +0800：App Store Connect 返回 `Uploaded package is processing`、`Upload succeeded` 与 `Uploaded Shouxia`。
- 上传日志包：`/var/folders/y7/85mgk2794hb_d9xb3qcpcj680000gn/T/Shouxia_2026-09-03_09-49-47.661.xcdistributionlogs`
