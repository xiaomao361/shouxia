# App Review Notes

Review text for the functionality in this repository. Confirm the submitted build and current distribution status separately before using these notes in App Store Connect.

## English

Shouxia (“收下”) is an on-device pickup-code inbox. No account or demo login is required. Text parsing, Apple Vision OCR, duplicate protection and record storage run locally. There is no advertising, analytics SDK or backend.

### Import paths

1. **Paste**: copy pickup text and use the system Paste button. Optional foreground clipboard recognition is off by default. When enabled, it checks changed clipboard content once after foreground activation; it does not read the clipboard in the background.
2. **Messages automation**: the user imports or creates “收下自动收码”, converts Shortcut Input to text, and connects it to the “短信内容” parameter of “保存取件短信”. iOS 27 uses a Message trigger within the shortcut; iOS 17, 18 and 26 use a separate personal automation. iOS 16 requires confirmation when triggered. The app cannot create or inspect these automations or read message history.
3. **Photo picker**: select up to five screenshots for local OCR. Simple, clearly labelled results may be added directly; other candidates are reviewed and can be corrected. Images and unrelated OCR text are not stored.
4. **Share extension**: share text or up to five images from an app that supports system sharing. Selected minimum fields are queued in the local App Group and imported when the main app next becomes active. Widget refresh follows main-app import and system scheduling.

The setup guide includes the [Apple iCloud shortcut template](https://www.icloud.com/shortcuts/cd785f47a8244d32b1cf3c7c6f4dad8a). Users must confirm template import and configure the Message trigger. On iOS 27, bundled offline videos demonstrate trigger setup and manual creation. Watching a video does not mark automation setup complete.

### Sample review flow

Copy this demonstration text and tap Paste:

```text
【菜鸟驿站】您的包裹已到北门驿站，取件码 3-2-4012，请及时领取。
```

The resulting code is `3-2-4012`, with location `北门驿站`. Open the card for large-code mode, mark it collected and test undo. History supports a recent/all filter, restoration to pending and confirmed permanent deletion.

“请人帮取” offers plain-text copy and a `.shouxia` handoff file. Copying text leaves records pending. Successful file sharing marks selected records handed off; cancellation or error leaves them unchanged. There is no shared account or synchronized recipient state.

### System surfaces and privacy

Home Screen and Lock Screen widgets read a minimal on-device snapshot. Live Activities require iOS 16.1+ and explicit opt-in; codes can be visible on the Lock Screen. Dynamic Island requires compatible hardware. Sessions last at most eight hours and use no push backend.

iOS 16 widgets show all pending items. iOS 17+ Home Screen widgets also support location filtering and code hiding; Lock Screen widgets show counts only. The app does not independently read other apps’ notifications.

## 中文

收下无需账号或测试登录，在本机完成文字解析、图片 OCR、去重与存储，不包含广告、第三方统计或服务端。

审核时可复制上方演示文本，点击“粘贴”，检查取件码、地点、大字取件、完成、撤销、历史筛选、恢复和确认删除。相册与系统分享支持最多 5 张图片，复杂结果进入核对，原图与无关 OCR 全文不保存。

短信自动导入依赖用户配置快捷指令，并将输入文本连接到“保存取件短信”的“短信内容”。iOS 27 在快捷指令内设置“信息”触发器；iOS 17、18、26 使用独立个人自动化；iOS 16 需确认运行。应用无法静默创建或查询自动化，不读取短信历史。iOS 27 提供内置离线教程。

普通文字复制不改变待取状态；交接包仅在系统分享成功且无错误后标记为“交给别人”，双方状态不同步。前台剪贴板自动识别和实时活动默认关闭。小组件由系统调度刷新，实时活动需 iOS 16.1 及以上及用户主动开启。
