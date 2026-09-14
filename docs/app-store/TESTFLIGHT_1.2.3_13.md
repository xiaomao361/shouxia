# 收下 1.2.3 (13) TestFlight 测试说明

Status: Uploaded — 2026-09-14 14:52:51 +0800 上传成功，Apple 返回 `Uploaded package is processing` 与 `Upload succeeded`，Xcode `EXPORT SUCCEEDED`、退出码 0。Apple 已接收并开始处理；尚未确认处理完成或对测试组开放。

## What to Test

本轮在 Build 12 的多取件码修复与暗色模式基础上，新增普通文字预览和复制，方便把整理好的取件信息粘贴到聊天。交接包仍为默认方式。

1. 打开“请人帮取”，确认第一项“收下交接包”默认选中；第二项为“普通文字”。退出再进入仍默认交接包。
2. 切换普通文字，选择两三件不同地点的包裹，检查按地点整理的预览，复制并粘贴到微信；对方无需安装收下。普通文字没有系统分享按钮。
3. 复制后记录仍保留在待取列表，确认取到后再手动收下。地点缺失时显示待确认，常用取件点保留确认提示。
4. 回归专用交接包：取消不移走待取；系统分享成功后标记“交给别人”；接收方仍可打开、预览并导入。
5. 回归一条通知多个取货码、重复导入及原有首码兼容；检查浅色与暗色模式。
6. 从现有版本覆盖安装 TestFlight，确认待取、历史、归档和设置保留。

## 已验证

- 最终源码 iPhone 17 Pro / iOS 26.5 模拟器 XCTest：61 项，59 通过、2 项真实 OCR 夹具测试跳过、0 失败。
- 普通文字相关 5 项测试包含分组、地点缺失与常用地点提示、同码不同地点不漏项、最小内容导出、空选择和 100 件边界，以及专用包分享取消或失败不交接。
- 2026-09-14 14:36 +0800，当前修正版 Debug 包已按用户要求覆盖安装 iPhone 14 Pro，设备应用列表读回 `1.2.3 (13)`。用户要求推送 TestFlight；本记录不据此补写未经逐项确认的交互验收。
- Release Archive：`.build/Shouxia-1.2.3-13.xcarchive`。
- Bundle ID：`com.zhouwei.shouxia`；版本：`1.2.3 (13)`；架构：`arm64`；签名校验通过。
- App 与 dSYM UUID：`3DEF012A-ED15-3ACC-AEFF-31B366F78187`，两者一致。
- 沿用 `scripts/AppStoreExportOptions.plist`：自动分发签名、固定构建号、`uploadSymbols=false`；dSYM 保留于本地归档。
- 本轮代码收口包含已进入 Build 13 的暗色、多码及普通文字复制；旧截图脚本、原始截图和废弃合成草稿保留在本地，不加入发布提交。

## 回执与边界

- 最终测试结果：`.build/build13-final-tests.xcresult`。
- 归档日志：`/tmp/shouxia-build13-archive.log`。
- 上传日志：`/tmp/shouxia-build13-upload.log`。
- 数据正确性试行 HCT-2026-09-08-01/02：最终回归继续覆盖批量写入失败不报成功、旧指纹兼容、不漏取件码、缺失地点保留未知，以及交接包错误或取消不交接；详见 `../MULTI_CODE_IMPORT.md` 与 `../PLAIN_TEXT_SHARING.md`。该证据不代表试行已证明长期可靠。
- Apple 处理完成、TestFlight 测试组可见性与覆盖安装验收仍待确认；未提交正式 App Store 审核。
