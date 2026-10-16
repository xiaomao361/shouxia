# 来源索引

获取日：2026-10-15（Asia/Shanghai）。样本来源与上下文来源分开，搜索摘要不等于成功打开。

|ID|来源|类型 / 读取层|使用与限制|
|---|---|---|---|
|S01|[三师市监处罚〔2023〕145号，第1页](https://www.xjbtnss.gov.cn/mobile/xwzx/scjg/202312/W020231212429282974164.pdf)|public_real / direct_pdf_read|web工具超时；直接HTTP 200、pypdf读取第1页。只使用短信引文，非法律分析。两条只换码的通知同家族。|
|S02|[一条快捷指令同步多家快递短信，三张公开配图](https://post.smzdm.com/p/a96mn807/)|public_real / direct_html_and_images_read|web工具失败；HTTP 200读取HTML并逐张目视核验兔喜、妈妈驿站、菜鸟图。作者展示的真实通知，真实性仅到作者自述/图像层。项目不存原图。|
|S03|[妈妈驿站运单后五位取件讨论，主帖短信](https://www.v2ex.com/t/1159521)|public_real / web_open|主帖已自行用XX遮住地点及链接；只用主帖短信，不采纳评论中的品牌归属或原因推测。|
|S04|[（2023）鲁0323知民初88号判决书转载中的邮政取件短信](https://zh.wikisource.org/zh-hans/山东省沂源县人民法院（2023）鲁0323知民初88号民事判决书)|public_real / web_open|维基文库转载司法文书，未取得法院同源正文；保留二手转录来源限制。己到原字保留；两条同模板只换码，收一条。|
|S05|[老人遭遇取件难，报道引用的丰巢短信](https://m.app.dawuhanapp.com/p/66334.html)|public_real / web_open|新闻引文已掩码；不从周边报道补入短信里没有的承运商。|
|S06|[南京航空航天大学学生服务：菜鸟取件指南](https://www.sohu.com/a/190322811_349991)|published_template / web_open|页面明确称短信模板；自提柜与货架两种。配图web读取失败，不声称看过这些图片。|
|S07|[短信宝物流通知文案](https://www.smsbao.com/words/238.html)|vendor_template / web_open|短信服务商示例，不是丰巢官方规范或真实投递凭据；原码被星号遮挡。|
|S08|[互亿无线：取货码短信通知模板](https://www.ihuyi.com/muban/detail/4240.html)|vendor_template / web_open|短信服务商XX占位模板，不是承运商正式统一模板。|
|S09|[互亿无线：通知客户取件模板](https://www.ihuyi.com/muban/detail/4229.html)|vendor_template / web_open|取出柜子的反例：旧地点不能自动当作当前取件地点。仅保留短摘录及语义摘要。|
|S10|[快宝驿站：取件码设置规则](https://www.kuaidihelp.com/kdy/356.html)|vendor_format / web_open|支持字母货架、日期、手机/单号尾号组合的证据；页面对段数的文字和示例有不一致，不将三段当硬限制。营销比例不采纳。|
|S11|[shareven/parcel柜号单元样本](https://github.com/shareven/parcel/blob/d7e4c974ffd1e4de2da9291df0d295856cd89818/app/src/test/java/com/xxxx/parcel/SmsParserLockerNumberTest.kt)|open_source_fixture / github_raw_read|MIT，提交固定；测试字符串，不称真实短信。附许可证。|
|S12|[pickup-code-app/parcel-split-prefix](https://github.com/zixij644-elaborate/pickup-code-app/blob/f5075d3e4d2f4ffe4da259c699f472a790ec7013/app/src/test/resources/corpus/parcel-split-prefix.txt)|open_source_fixture / github_raw_read|GPL-3.0仓库；作者声明同形脱敏。原始图片未取得，真实来源声明未独立复核；不移植代码。本地仅短文本/结构或改写对照。|
|S13|[pickup-code-app/addr-5g-column](https://github.com/zixij644-elaborate/pickup-code-app/blob/f5075d3e4d2f4ffe4da259c699f472a790ec7013/app/src/test/resources/corpus/addr-5g-column.txt)|open_source_fixture / github_raw_read|GPL-3.0仓库；作者声明同形脱敏。原始图片未取得，真实来源声明未独立复核；不移植代码。本地仅短文本/结构或改写对照。|
|S14|[pickup-code-app/real-multicode-brands](https://github.com/zixij644-elaborate/pickup-code-app/blob/f5075d3e4d2f4ffe4da259c699f472a790ec7013/app/src/test/resources/corpus/real-multicode-brands.txt)|open_source_fixture / github_raw_read|GPL-3.0仓库；作者声明同形脱敏。原始图片未取得，真实来源声明未独立复核；不移植代码。本地仅短文本/结构或改写对照。|
|S15|[pickup-code-app/multi-code-window-overlap](https://github.com/zixij644-elaborate/pickup-code-app/blob/f5075d3e4d2f4ffe4da259c699f472a790ec7013/app/src/test/resources/corpus/multi-code-window-overlap.txt)|open_source_fixture / github_raw_read|GPL-3.0仓库；作者声明同形脱敏。原始图片未取得，真实来源声明未独立复核；不移植代码。本地仅短文本/结构或改写对照。|
|S16|[pickup-code-app/parcel-tuxi-digit-dash](https://github.com/zixij644-elaborate/pickup-code-app/blob/f5075d3e4d2f4ffe4da259c699f472a790ec7013/app/src/test/resources/corpus/parcel-tuxi-digit-dash.txt)|open_source_fixture / github_raw_read|GPL-3.0仓库；作者声明同形脱敏。原始图片未取得，真实来源声明未独立复核；不移植代码。本地仅短文本/结构或改写对照。|
|S17|[pickup-code-app语料格式及脱敏说明](https://github.com/zixij644-elaborate/pickup-code-app/blob/f5075d3e4d2f4ffe4da259c699f472a790ec7013/docs/CORPUS.md)|method_reference / github_raw_read|说明期望值需人工确认、脱敏应保留形态；不沿用作者准确率。|
|S18|[Apple WWDC19：Text Recognition in Vision](https://developer.apple.com/videos/play/wwdc2019/234/)|apple_documentation / web_open|on-device、语言纠正可能损伤码、候选及boundingBox。|
|S19|[Apple WWDC21：Extract document data using Vision](https://developer.apple.com/videos/play/wwdc2021/10041/)|apple_documentation / web_open|查询支持语言，中文accurate模式语言优先级；演讲示例不是当前所有系统的性能保证。|
|S20|[Apple VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)|apple_documentation / web_shell_and_index|正文页面为JS壳；API成员由搜索索引及本机SDK交叉核对，不将壳当完整文档。|
|S21|[Apple topCandidates](https://developer.apple.com/documentation/vision/vnrecognizedtextobservation/topcandidates(_:))|apple_documentation / web_shell_and_index|索引说明候选上限10；实际可少于请求值。正文JS壳。|
|S22|[厦门大学后勤：2026新生快递收寄攻略](https://hqjt.xmu.edu.cn/info/1023/285382.htm)|context_only / web_open|官方同一站点服务多个承运商的实例；不是短信样本，不能计入承运商模板覆盖。|
|S23|[中国邮政智能包裹柜自提服务采购](https://www.chinapost.com.cn/cn/report/2412/18339-1.htm)|context_only / web_open|柜方系统发码、邮政投件的角色分离证据；没有具体短信。|
|S24|[浙江在线：便利店快递代收](https://zjnews.zjol.com.cn/zjnews/hznews/201711/t20171129_5858066.shtml)|context_only / web_open|报道四位码与便利店取件，但没有完整短信；不能冒充便利店真实短信fixture。|
|S25|[申通代理点取件提醒报道](https://www2.cqcb.com/headline/2020-10-29/3190371.html)|context_only / web_open_image_failed|文本说有凭证、单号、地点等；未读取其截图，故不采样短信。|
|S26|[人民日报转载：门卫室代收](https://www.sdcourt.gov.cn/lylsqfy/367109/367114/7948206/index.html)|search_lead / web_timeout|搜索有摘要，直接打开超时；不纳入已核验样本。|
|S27|[51CTO快捷指令文章](https://blog.51cto.com/u_17648568/14540362)|search_lead / web_empty|搜索有递管家通知，但打开正文0行、来源链未核验，不作真实样本。|
|LOCAL|本轮人工构造的边界用例|synthetic / authored|由研究者构造；只证明代码面对该输入的行为，不证明实际分布。|

## 查询及排除记录

本轮先后检索丰巢、菜鸟、兔喜、妈妈驿站、申通、圆通、中通、韵达、顺丰、京东、极兔、邮政；搭配取件/取货码、短信模板、门卫室、便利店、多码、GitHub fixture等关键词。另查Apple Vision官方资料。没有全国站点采集。
- Tavily research pro一次请求返回429，未产生研究报告；之后使用网页搜索、逐页open、公开HTTP正文与GitHub固定提交文件核验完成。
- 黑猫投诉有案例明确禁止转载；未收录其正文或截图。
- 搜索遇到大量PHP中文网/聚合教程的6位码、期限等泛化陈述，无厂商依据，不采用。
- S25的截图读取失败、S26正文超时、S27正文为空：分别保留具体缺口，不记为“该场景不存在”。
- S01 PDF、S02页面：web失败后公开HTTP读取成功；S01核验第1页渲染，S02核验三张配图。无登录、无UI操作。
- S14提供三卡片品牌错配的开源声明；本轮未复制整个文件、未取得原图，故只作佐证与构造设计依据，不记为三条真实短信。
- 补充定向检索京东帮助中心、顺丰官网及极兔凭码通知后，仍未获取可独立核验的近期京东/极兔/德邦真实完整通知；便利店有服务场景报道但短信原文不足；门卫室只得不完整搜索线索。

## 版权与脱敏

非许可网页只保存短摘录、字段/结构摘要和必要的脱敏模板片段；不保存整篇正文或公开原图。S02三个片段替换地名和码，保留其句式关系；数字角色不互换。S03网址替换为example.invalid，不能点击查询。公开司法文书只引用必要通知内容，不采集当事人信息。示例电话13000000000不是可联系对象。
O01/O02来自MIT测试字符串，见THIRD_PARTY_NOTICES.md；O03/O04为GPL仓库短语料，保留固定提交和许可指针。不移植第三方解析代码。来源类型与运行输入表示类型是两个维度：public_real表示出处是公开通知，deidentified_text表示回放的不是逐字原件。
