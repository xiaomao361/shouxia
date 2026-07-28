# App Review Notes

## English

Shouxia (“收下”) is a local-only pickup-code organizer. No account or demo login is required.

The app has three import paths:

1. User-initiated paste: copy a pickup notification, open the app, and tap the “粘贴通知” button. The app does not read the clipboard on launch or in the background.
2. Messages personal automation: the user may create an iOS Shortcuts “Message” personal automation and pass the message text to the “保存取件短信” App Intent. The app cannot create this personal automation automatically and does not read message history.
3. Photo recognition: the user may select a logistics screenshot with the system photo picker. Apple Vision performs OCR entirely on device. A single clearly labelled pickup code is added directly; multiple or unlabelled candidates require confirmation. The original image and unrelated OCR text are not stored.

The App Shortcut card that may appear in Shortcuts exists only to register the App Intent action with the system. Users are not expected to run it manually.

The app cannot read notifications from Alipay or other third-party apps. Those notifications are supported only through user-initiated copy and paste.

Sample text for review:

`【菜鸟驿站】您的包裹已到北门驿站，取件码 3-2-4012，请及时领取。`

Expected result:

- Pickup code: `3-2-4012`
- Location: `北门驿站`

Tap the resulting pickup card to open the large-code pickup mode. If multiple
pending records have the same parsed location, swipe horizontally to move
between their codes.

All message text and parsed records remain on device. The app contains no advertising, analytics SDK, account system, or network backend.

## 中文

“收下”是一款完全本地处理的取件码整理工具，不需要账号或测试登录。

审核员可以复制上面的演示文本，打开 App 后点击“粘贴通知”，检查解析、去重、轻点卡片进入大字取件模式、滑动完成、撤销、归档和永久删除。也可以从系统照片选择器选择一张包含“取件码”标签的物流截图；图片只在本机 OCR，原图和无关全文不会保存。

短信自动导入依赖用户自己创建的 iOS“信息”个人自动化；App 无法替用户创建，也不会读取短信历史或其他 App 的通知。
