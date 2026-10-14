# 2026-10-14 主线整合

用户授权将后续分支整合到 main，并更新文档。本轮不安装、不上传、不部署，不以代码合并代表 App Store 新版本发布。

## 整合范围

- 核对远端 main 已为 `038f020`，包含 1.2.4 (`7e69844` / `41252e0`) 与 1.2.5 (`5712b3a` / `038f020`)。原主目录本地 main 停在 `ac5cc4e`，因此此前只读主目录会漏看锁屏实现。
- 将 `codex/shouxia-1.2.6-16` 的 iOS 16 兼容改动、既有测试和版本文档提交，再整合到 main；加入本轮系统截图分享入口，使用边界见 [截图分享导入](SHARE_IMAGE_IMPORT.md)。
- 旧 `codex/apple-watch@ca5a1e7` 的活动原型保留历史并按当前 main 实现取代；不复制重复 ActivityKit target，不恢复暂停的手表专用布局，不启动独立 Watch App 或同步方向。旧原型的暂停决定仍有效。
- `codex/shouxia-1.2.4-14` 和 `codex/shouxia-1.2.5-15-release` 的提交已是当前发布基线祖先，不重复合入旧代码。

## 原目录未提交内容

整合前把三个工作区的 78 个改动/未跟踪文件复制到 `/Users/zhouwei/Downloads/收下分支整合备份-20261014`，逐文件 SHA-256 与原件一致；同时保留各目录原差异和状态。主目录旧的短信引导与系统图标改动已由较新主线实现覆盖，其原始内容仍保存在副本和 Git stash，不覆盖新版。旧截图脚本与历史素材恢复为原目录本地内容，不混入此次功能提交。其他工作区和分支不删除。

## 验证与剩余边界

- 主机回归：86 项通过，含 8 项新增队列接收、故障保留、字段与重复导入测试。HCT-2026-09-08-01/02 的本次证据见截图分享文档；不等同于试行长期可靠性成立。
- iOS Simulator `build-for-testing` 和通用 iOS Release 无签名构建通过（`/tmp/shouxia-share-build.log`、`/tmp/shouxia-share-device-build.log`）；UI 和真实 OCR 夹具未运行。新分享扩展 App Group entitlement、激活规则和嵌入产物已检查。
- 新入口保存后在下次打开 App 入库，并在此时更新系统展示；不是保存后即时更新小组件。新扩展签名和实际系统分享菜单、布局、OCR、取消与重复分享仍需用户真机观察。
- 此前 1.2.6 (16) TestFlight 上传事实保持；本轮新增代码尚未上传，发布前需要新构建号。1.2.5 审核结果及 1.2.6 测试组可见性未在本轮核查。

相关旧工作区/备份保持可恢复；具体提交与主线整合由 Git 历史记录。

## 最终本地整合状态

- `42d33a4`：提交 1.2.6 兼容修改、系统截图分享扩展及相关文档。
- 主目录 main 快进至该提交；`051fb99` 用 `ours` 策略保留旧手表原型提交历史，源码树与 `42d33a4` 完全相同，不启用其暂停布局。
- 四条后续分支（1.2.4、1.2.5、1.2.6、apple-watch）均已验证为本地 main 的祖先。分支和其他工作区保留，不删除。
- 整合前主目录内容保存在 stash `3025c782`；完整 Git bundle 备份已恢复到独立裸库，旧原型说明、Swift 文件和新分享扩展配置逐字节读回一致。
- 原主目录 27 个历史截图/脚本文件恢复并核对哈希；截图脚本仍为本地修改，历史素材仍为未跟踪文件，不纳入功能提交。旧版短信引导/图标草稿由新版主线覆盖，原件仍在 stash 与文件副本中。
- 本轮完成本地提交与合并，未推送远端；远端 main 在检查时仍为 `038f020`。未安装、上传 TestFlight、提交审核或部署。历史上传的 1.2.6 (16) 不因此次合并改变。

## 后续授权：远端推送与开发签名

用户随后授权推送代码并继续开发。`20a8062` 已推送远端 main，`git ls-remote` 与本地 HEAD 完整 SHA 一致；原有截图脚本/素材本地修改未提交。此次更新仅补记录，不代表发布新版 App。

新增分享扩展的 Debug 通用 iOS 自动签名构建通过（`/tmp/shouxia-share-signed-build.log`）。产物 `/tmp/shouxia-share-signed-20261014/Build/Products/Debug-iphoneos/收下.app` 中主 App、分享扩展、小组件均通过 `codesign --verify --deep --strict`；三个签名 entitlement 与 embedded profile 均含 `group.com.zhouwei.shouxia`，application identifier 匹配，描述文件含一个开发设备。版本仍为 1.2.6 / 16，此包用于开发测试，不是此前已上传的包。

截至本记录，手机未安装此开发包，未打开 App 或操作系统分享面板；真实 OCR/分享菜单/取消/部分失败/重复分享/前台与冷启动接收仍待用户操作验收。后续 TestFlight 发布需新的构建号。

## 用户授权后的覆盖安装

2026-10-14 用户明确允许覆盖安装，并选择自己手动检查。已确认通过有线连接的真实设备为 iPhone 14 Pro / iOS 27.0.1，安装上述 Debug 签名包，devicectl 返回 exit 0 / outcome success / bundleID `com.zhouwei.shouxia`；应用列表读回收下 1.2.6、builtByDeveloper=true。未卸载、未打开 App、未操作分享菜单。安装记录 `/tmp/shouxia-share-install.log`、`/tmp/shouxia-share-install-result.json`，应用读回 `/tmp/shouxia-share-installed-apps.json`。

下一步由用户从照片选择取件截图 → 系统分享 → 收下（首次可能在“更多”）→ 核对保存 → 打开收下确认待取。实际分享入口、OCR、取消/重复分享以及原有数据仍待用户反馈；安装成功不代表交互验收通过。
