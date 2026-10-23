# 收下 · Shouxia

收下是一款在本机整理取件码的 iOS 应用。它从短信、文字和截图中提取取件码与地点，提供大字查看、取件完成和代取信息交接，无需账号或服务端。

[App Store](https://apps.apple.com/cn/app/id6795735956) · [产品主页](https://xiaomao361.github.io/shouxia/) · [使用帮助](docs/app-store/SUPPORT_ZH_HANS.md) · [隐私政策](https://xiaomao361.github.io/shouxia/privacy/)

## 功能

- **导入取件信息**：主动粘贴文字、一次识别最多 5 张截图，或从其他应用的系统分享菜单导入。
- **短信自动收码**：通过快捷指令和“信息”自动化，将收到的取件短信传入应用；按系统版本提供设置说明。
- **现场取件**：放大显示取件码，连续查看同地点或同批次包裹，支持更正取件码与地点。
- **记录管理**：滑动标记完成、短时撤销、查看历史、恢复待取和确认删除；历史不会自动清理。
- **代取交接**：复制按地点分组的普通文字，或发送可供收下导入的 `.shouxia` 交接包。
- **系统展示**：桌面和锁屏小组件，以及由用户开启的锁屏与灵动岛实时活动。

## 本地处理与隐私

文字解析、Apple Vision 图片识别和记录存储均在设备上完成。应用不包含账号、广告、第三方统计或云同步，不读取短信历史。图片导入只保存必要的取件字段，不保存原图或 OCR 全文。

剪贴板自动识别与实时活动默认关闭。短信自动收码需要用户在系统“快捷指令”中配置；应用无法创建或查询个人自动化。取件信息只有在用户主动复制或分享时才会交给其他应用。详见[数据处理说明](docs/app-store/PRIVACY_POLICY_ZH_HANS.md)。

## 系统要求

| 功能 | 要求 |
| --- | --- |
| 主应用、分享扩展、基础小组件 | iOS 16.0 及以上 |
| 实时活动 | iOS 16.1 及以上 |
| 桌面小组件地点筛选与隐藏码 | iOS 17 及以上 |
| 灵动岛 | 支持该功能的 iPhone |
| 应用内短信设置视频 | iOS 27；其他版本提供文字说明 |

最低部署版本表示工程兼容目标，各系统的实机覆盖情况应随版本验证。仓库源码与商店分发版本可能不同，下载版本以 App Store 为准。

## 构建与开发

工程使用 Swift、SwiftUI、App Intents、Vision、WidgetKit 和 ActivityKit，包含主应用、分享扩展和小组件扩展。在安装对应 iOS SDK 的 Xcode 中打开 `Shouxia.xcodeproj`，选择 `Shouxia` scheme；设备构建需配置签名与 App Group。

运行不启动模拟器的本机逻辑测试和识别回归：

```sh
bash scripts/check_recognition.sh /tmp/shouxia-recognition-check
```

环境要求、命令和测试范围见[开发指南](docs/DEVELOPMENT.md)。

## 文档与贡献

- [文档索引](docs/README.md)
- [功能与数据约定](docs/PRODUCT.md)
- [识别机制](docs/RECOGNITION.md)与[研究样本](docs/research/2026-10-15-pickup-parsing/README.md)
- [小组件与实时活动](docs/SYSTEM_SURFACES.md)
- [版本变更](CHANGELOG.md)与[发布流程](docs/app-store/RELEASE_CHECKLIST.md)
- [贡献指南](CONTRIBUTING.md)

问题反馈可通过 [GitHub Issues](https://github.com/xiaomao361/shouxia/issues) 或 [支持邮箱](mailto:zhouwei@linux.com) 提交。请提供应用版本、iOS 版本、复现步骤及预期结果，并对短信和截图中的个人信息脱敏。
