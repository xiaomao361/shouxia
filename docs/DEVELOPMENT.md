# 开发与验证

## 环境

- macOS 与 Xcode，安装工程所需的 iOS SDK；工程最低部署目标为 iOS 16.0。
- Swift 6.0 及以上工具链用于主机测试脚本。
- Python 3 用于样本校验与识别回放。
- 真机及发行构建需要 Apple Developer 签名与一致的 App Group 配置。

主应用、分享扩展和小组件共享 `group.com.zhouwei.shouxia`。使用其他开发团队构建时，需要为三个 target 配置可用的 Bundle ID、entitlements 和 provisioning profile，并同步代码中的共享容器标识。

## 工程结构

```text
Shouxia/
  App/                 应用入口与生命周期
  Features/            首页、取件、历史、设置、导入与交接界面
  Intents/             保存取件短信 App Intent
  Models/              取件记录与分享模型
  Resources/           图标、隐私清单和离线教程
  Services/            解析、存储、OCR 和系统展示发布
Shared/                识别核心、分享队列、系统快照与会话模型
ShouxiaShare/          系统文字与图片分享扩展
ShouxiaWidgets/        WidgetKit 小组件与实时活动界面
ShouxiaTests/          解析、存储、分享、状态与主题测试
scripts/               主机测试、识别回放和素材处理
```

`PickupRecognitionCore` 负责共用识别逻辑，`PickupRepository` 负责主记录的读写与去重。分享扩展只向 App Group 接收队列写入最小字段；主应用接收后统一入库，并发布供小组件读取的快照。不同导入入口的核对策略见[识别机制](RECOGNITION.md)。

## 构建

在仓库根目录执行无需签名的通用 iOS 构建：

```sh
xcodebuild build \
  -project Shouxia.xcodeproj -scheme Shouxia \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/shouxia-build CODE_SIGNING_ALLOWED=NO
```

仅编译模拟器应用和 XCTest 源码：

```sh
xcodebuild build-for-testing \
  -project Shouxia.xcodeproj -scheme Shouxia \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/shouxia-test-build CODE_SIGNING_ALLOWED=NO
```

这两条命令不安装或启动应用。发行归档的检查项见[发布流程](app-store/RELEASE_CHECKLIST.md)。

## 自动检查

### 主机逻辑测试

```sh
bash scripts/test_surface_core.sh
```

脚本将可移植 Swift 源码复制到临时 Swift Package，执行解析、存储、分享队列、交接、系统快照、实时活动状态与 Store 测试。它不启动模拟器、不操作设备，也不执行 UIKit 主题测试或两个可选真实图片 OCR 测试。

### 识别回归

修改识别逻辑后执行：

```sh
bash scripts/check_recognition.sh /tmp/shouxia-recognition-check
```

该命令先运行主机测试，再编译实际 Swift 源码，对文字、自动导入、文字分享和图片标注行执行断言回放。失败返回非零退出码；输出目录包含摘要与诊断结果。

单独运行断言或查看候选证据：

```sh
python3 scripts/check_pickup_recognition.py --output /tmp/shouxia-recognition-check
bash scripts/replay_pickup_samples.sh docs/recognition/1.2.9/contracts.jsonl
```

回放中的图片输入是标注文字行，不能验证 Vision 图像识别。已有样本和格式变体属于开发回归集；测试通过不代表未知模板准确率。不得根据新实现输出批量覆盖预期值，预期变更应说明对应输入和语义依据。

## 设备验证

涉及以下能力时，应另行记录设备、系统版本、应用版本、输入与实际结果：

- 真实短信触发、锁屏运行及快捷指令参数传递。
- 原图 OCR、系统分享入口、取消与保存重试。
- 覆盖升级后的记录保留、完成、撤销与永久删除。
- 小组件刷新、实时活动生命周期及明暗外观。
- 大字体、VoiceOver 和减少动态效果。

构建、主机测试、设备运行和交互验收是不同的验证层。报告结果时注明执行范围与跳过项。

## 变更约定

- 解析、存储和交接语义变更应补充相应回归，保留失败、部分完成与需核对状态。
- 地点来源区分识别、常用默认与用户更正；缺失信息不得从其他通知推断。
- 主应用、分享扩展和小组件的版本保持一致。新分发包递增构建号，实现回退也不复用旧构建号。
- 公开指南说明稳定行为；用户可见变更写入 [CHANGELOG](../CHANGELOG.md)。本地日志和发行凭据保存在 `.private/`，不提交证书、账号信息或原始私人样本。
