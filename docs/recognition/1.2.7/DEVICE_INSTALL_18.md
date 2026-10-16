# 1.2.7（18）手机安装记录

2026-10-15，经用户要求，签名 Debug 开发包覆盖安装至用户 iPhone。devicectl 安装退出码 0，应用列表读回 `com.zhouwei.shouxia` / `1.2.7` / `18`。

- 主 App、分享扩展、小组件产物均核对为 1.2.7（18）。
- 签名构建成功，`codesign --verify --deep --strict` 通过。
- 未卸载旧 App，未启动 App、未操作手机界面；已有记录和真实手机交互仍需用户确认。
- 未提交代码、推送、上传 TestFlight 或提交审核。

日志与本机证据（临时文件可能清理）：

- `/tmp/shouxia-127-18-device-build.log`
- `/tmp/shouxia-127-18-install.json`
- `/tmp/shouxia-127-18-installed-apps.json`
- 产物 `/tmp/shouxia-127-18-device/Build/Products/Debug-iphoneos/收下.app`

[手机测试清单](PHONE_TEST_CHECKLIST.md)；[此前解析与更正验证](review-fixes/README.md)。本轮构建号变更不修改解析逻辑，未重复此前已经通过的 129 项主机测试。
