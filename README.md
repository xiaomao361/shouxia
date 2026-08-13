# shouxia

“收下”是一款给实际去取快递的人使用的 iOS 取件码收件箱：自己的取件短信可以通过个人自动化进入，他人托取的文字可以主动粘贴，聊天里收到的物流截图可以从相册本机识别；需要请别人代取时，可以把多件待取信息打成一份本地“收下交接包”发送给实际取件的人。App 提取取件码与地点，取件后用一次滑动完成。

App Icon 以“杏桃包裹 + 云白取件卡”为核心图形，直接表达 App 管理的是附着于包裹的取件信息；Logo 与 App 内空状态复用同一套几何语言。

## 公开页面

- [中国大陆 App Store](https://apps.apple.com/cn/app/id6795735956)
- [收下主页](https://xiaomao361.github.io/shouxia/)
- [隐私政策](https://xiaomao361.github.io/shouxia/privacy/)
- [获取支持](https://xiaomao361.github.io/shouxia/support/)

## 设计

- [Figma：收下 · App Design v2](https://www.figma.com/design/fjQN8yRyNkYPqMUcL9I6B2)
- 视觉方向是“晚风杏桃”：天空浅蓝和云白提供呼吸感，杏桃色承担包裹与完成温度，薄荷色只负责行动和微风提示。
- 完成动效分为轻抬、阈值确认、向右下轻轻归位和五秒撤销承接，总时长约 460ms；开启“减少动态效果”时改为淡出淡入。
- 可编辑品牌源文件位于 [`docs/brand`](docs/brand)，与 Figma 和 Xcode App Icon 使用相同几何。

## 当前阶段

项目已经建立首个 SwiftUI 纵向薄切片，最低支持 iOS 17。原始文本会经过本地解析、内容指纹去重和本地 JSON 存储，再显示为轻量云白纸签；相册图片由 Apple Vision 在本机 OCR，只保存取件码、地点、来源和必要片段，不保存原图与无关全文。轻点卡片可进入取件现场大字模式，同一地点的多个包裹可以左右切换；向右滑动后，卡片会轻抬并向右下归位。收下记录保留录入与完成时间，并可继续归档、恢复或永久删除。首页明确区分“自己的取件短信”和“他人托取”两类入口；待取记录可批量生成 `.shouxia` 交接包，接收方打开后预览确认导入。短信自动收码采用“普通快捷指令接好文本 → 信息个人自动化运行该快捷指令”的两阶段配置；首页设置入口支持手动隐藏，首次短信来源导入后只自动隐藏一次，并可从“隐私与关于”恢复。

## 产品边界

- 第一版只解决取件通知的收集、快速查看、完成和轻量记录管理。
- 默认本地处理和存储，不依赖账号、云端或物流平台 API。
- 数据分析和统计留到有真实使用数据后再定义，不进入 1.0。
- 不做物流追踪、家庭共享、聊天机器人、信息流或 Android 客户端。
- 核心验证是近乎无摩擦的录入，以及克制但令人满足的完成体验。

## 文档

- [产品 Seed](docs/PRODUCT_SEED.md)
- [双入口改造与 TestFlight 计划](docs/PLAN_DUAL_INTAKE_AUTOMATION_TESTFLIGHT_2026-07-30.md)
- [开发与验证](docs/DEVELOPMENT.md)
- [App Store 1.0 上架资料](docs/app-store/RELEASE_CHECKLIST.md)
- [App Store 6.5 英寸截图](docs/app-store/screenshots/final-6.5)

## 下一步

`1.0` 已在中国大陆 App Store 上架。`1.1.0 (4)` 已完成 TestFlight 真机验收，包括长列表滚动、从 App Store `1.0` 升级后的本地数据保留，以及两台真机之间的“生成交接包 → 系统分享 → 冷启动预览 → 批量导入 → 重复打开保护”。下一步是使用 Build 4 提交 `1.1.0` App Review。
