# App Review Notes

## English

Shouxia (“收下”) is a local-only pickup-code inbox for the person who will actually collect the parcels. A person’s own pickup SMS can enter through a Messages automation, while pickup text or screenshots forwarded by family and friends can be added manually. No account or demo login is required.

The app has three import paths:

1. Paste: the primary button is Apple's system `PasteButton`. The user may also enable “打开时识别剪贴板” in Import Settings. That option is off by default, checks only after the app enters the foreground and the pasteboard change count has changed, and locally attempts to parse the current text once. Irrelevant text is ignored. iOS may show its system paste-permission prompt; the app never reads the clipboard in the background.
2. Messages personal automation: the user first creates or imports a regular shortcut named “收下自动收码”. It converts Shortcut Input to text and explicitly connects that text to the “短信内容” parameter of the “保存取件短信” App Intent. The user then creates a Messages personal automation that runs this regular shortcut. The app cannot create or inspect the personal automation and does not read message history.
3. Photo recognition: the user may select up to five logistics screenshots with the system photo picker. Apple Vision performs OCR entirely on device. Candidates are merged into one review and deduplicated by pickup code across images. A single clearly labelled code from one image may be added directly; multiple images, multiple codes, or unlabelled candidates require confirmation. The original images and unrelated OCR text are not stored.

Import Settings also allows one optional common pickup point. It is used only as a fallback for future imports whose source contains no location, and records visibly distinguish this default from a recognized or user-corrected location. Records imported in the same photo batch can still be collected continuously when no location is available.

The “添加‘收下自动收码’” button in the setup guide opens this Apple iCloud Shortcut sharing page:

`https://www.icloud.com/shortcuts/cd785f47a8244d32b1cf3c7c6f4dad8a`

After the user confirms the shortcut import, the user must still create the Messages personal automation manually and select “Run Immediately”. The app does not claim that this automation can be created silently.

The App Shortcut card that may appear in Shortcuts registers the App Intent action with the system. It does not create the regular shortcut or the Messages personal automation.

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

“收下”是一款完全本地处理、给实际去取快递的人使用的取件码收件箱，不需要账号或测试登录。自己的取件短信可以通过系统自动化进入，他人托取的文字或截图可以主动交给 App。

审核员可以复制上面的演示文本，打开 App 后点击系统“粘贴”按钮，检查解析、去重、轻点卡片进入大字取件模式、滑动完成、撤销、归档和永久删除。也可以在“导入设置”中主动开启“打开时识别剪贴板”；此选项默认关闭，仅在 App 进入前台且剪贴板发生变化后读取一次，iOS 可能显示系统粘贴授权提示，无关内容会被静默忽略，后台不会读取。

系统照片选择器支持一次选择最多五张物流截图；图片只在本机 OCR，随后跨图按取件码去重并统一确认，原图和无关全文不会保存。可选的“常用取件点”只补全以后导入且原文缺少地点的记录，并会显示来源标记；同批图片即使没有地点也可连续取件。

短信自动导入包含两段：普通快捷指令先把“快捷指令输入”转换成文本并连接到“保存取件短信”的“短信内容”，随后由用户创建的 iOS“信息”个人自动化运行该快捷指令。App 无法替用户创建或查询个人自动化，也不会读取短信历史或其他 App 的通知。

App 内“添加‘收下自动收码’”按钮会打开 Apple iCloud 快捷指令分享页：

`https://www.icloud.com/shortcuts/cd785f47a8244d32b1cf3c7c6f4dad8a`

用户确认导入后，仍需亲自创建“信息”个人自动化并选择“立即运行”；App 不会声称能够静默创建该自动化。
