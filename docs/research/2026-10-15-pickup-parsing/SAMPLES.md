# 样本审阅表

完整标注以samples.jsonl为准；以下是便于审阅的表格。`?`表示原文未说明或无法判定，不是推断为空。44条中27条明确是人工用例。全部已经参与本轮研究，只作开发/诊断集。

|ID / 来源类型|输入与模板家族|期望码 → 地点 / 承运商 / 取件服务|干扰与边界|
|---|---|---|---|
|R01 / public_real ([S01](SOURCES.md))|【妈妈驿站】取货码C5-26-35,您有圆通快递包裹，已到样例园东门圆通速递，询13000000000<br>`mama-labelled-arrival`|C5-26-35 → 样例园东门圆通速递 / 圆通 / 妈妈驿站|11位联系电话|
|R02 / public_real ([S02](SOURCES.md))|【兔喜生活】您的快件已到样例府辉码生鲜超市店,请您取件时佩戴好口罩,做好个人防护凭2-2-4071及时取件,联系电话[原图已遮挡]<br>`tuxi-ping-code-supermarket`|2-2-4071 → 样例府辉码生鲜超市店 / ? / 兔喜生活|行外日期时间；原图掩码联系电话|
|R03 / public_real ([S02](SOURCES.md))|【妈妈驿站】取货码4-73，您有圆通快递包裹，已到样例府S1-203语新超市妈妈驿站，询[原图已遮挡]<br>`mama-labelled-arrival`|4-73 → 样例府S1-203语新超市妈妈驿站 / 圆通 / 妈妈驿站|S1-203门牌|
|R04 / public_real ([S02](SOURCES.md))|【菜鸟】取件码1-2-4082的韵达2635包裹到样例府羽丹百货超市，请20:30前取，询[原图已遮挡]<br>`cainiao-code-carrier-tail`|1-2-4082 → 样例府羽丹百货超市 / 韵达 / 菜鸟|2635角色不明的包裹标识；20:30营业/取件提示时间；2635只标非取件码包裹标识，具体数字角色未知|
|R05 / public_real ([S03](SOURCES.md))|[韵达快递] 请凭取件码到 XX 小区妈妈驿站取件，到店扫码或点 https://example.invalid/XX 查看取件码<br>`link-only-mama`|? → XX 小区妈妈驿站 / 韵达 / 妈妈驿站|网址；实际小区未知；码需外部查询，离线无法恢复|
|R06 / public_real ([S04](SOURCES.md))|【快递超市】你的中国邮政己到样例园绿色果园，请凭Y820078来取，联系电话：13000××××××<br>`postal-alpha-ping`|Y820078 → 样例园绿色果园 / 邮政 / ?|掩码手机号；己/已可能是文书转录错误，不可宣称OCR实际错字|
|R07 / public_real ([S05](SOURCES.md))|[丰巢]您的快递24H未领，关注丰巢智能柜绑定取件手机号，激活取件码****至样例设计院第四生活区大门西侧丰巢快递柜领取。<br>`fengchao-masked-activation`|? → 样例设计院第四生活区大门西侧丰巢快递柜 / ? / 丰巢|24H时长；码被遮挡，不能标成没有发码|
|T01 / published_template ([S06](SOURCES.md))|【菜鸟驿站】请您凭取货码12345678至样例大学5号教学楼负一层6号自提柜领取2017-09-05其他包裹，电话13000000000<br>`campus-locker-date`|12345678 → 样例大学5号教学楼负一层6号自提柜 / ? / 菜鸟|2017-09-05日期；5号楼；6号柜；电话|
|T02 / published_template ([S06](SOURCES.md))|【菜鸟驿站】中通包裹到样例大学5号楼菜鸟驿站，请18:00前凭『6-2-2004』取。<br>`campus-ping-quoted`|6-2-2004 → 样例大学5号楼菜鸟驿站 / 中通 / 菜鸟|18:00时间；5号楼|
|T03 / vendor_template ([S07](SOURCES.md))|〖丰巢〗凭取件码『hj**cb』至三湘****取中通快递的包裹！<br>`fengchao-masked-alpha`|? → 三湘**** / 中通 / 丰巢|原始星号掩码|
|T04 / vendor_template ([S08](SOURCES.md))|〖XX快递〗您的快递已到，如急需取件，请致电：XX，也可凭〖取货码XX〗于XX到XX中转站领取XX快递。<br>`template-transit-point`|? → XX中转站 / ? / ?|XX占位符|
|T05 / vendor_template ([S09](SOURCES.md))|[只存结构，未回放]<br>`removed-from-cabinet`|? → ? / ? / ?|旧柜位置；时长；当前取件地点未知|
|T06 / vendor_format ([S10](SOURCES.md))|A-1-26-11<br>`shelf-date-tail`|A-1-26-11 → ? / ? / ?|26可为入库日期组成部分|
|O01 / open_source_fixture ([S11](SOURCES.md))|快递已放入7号柜23-32格口，取件码7777<br>`locker-compartment`|7777 → 7号柜 / ? / ?|23-32格口；7号柜|
|O02 / open_source_fixture ([S11](SOURCES.md))|您的快递已存放至丰巢四号柜，取件码1234<br>`locker-chinese-number`|1234 → 丰巢四号柜 / ? / 丰巢|中文四号柜|
|O03 / open_source_fixture ([S12](SOURCES.md))|取<br>件码041327<br>`ocr-split-label`|041327 → ? / ? / ?|标签断行|
|O04 / open_source_fixture ([S16](SOURCES.md))|【兔喜生活】您的包裹已到<br>取件码为7-2914<br>`tuxi-label-two-seg`|7-2914 → ? / ? / 兔喜生活|—|
|C01 / synthetic ([LOCAL](SOURCES.md))|手机尾号2635，快递已到东门驿站，咨询13000000000<br>`negative-phone-tail`|? → 东门驿站 / ? / ?|2635手机号尾号；11位电话|
|C02 / synthetic ([LOCAL](SOURCES.md))|【京东物流】凭手机尾号2635到东门便利店取件。<br>`explicit-tail-credential`|? → 东门便利店 / 京东 / ?|明确可作凭证的手机尾号；独立取件码不存在；尾号是另一种领取凭证|
|C03 / synthetic ([LOCAL](SOURCES.md))|2026-10-15 18:30，包裹到了，请到南门门卫室领取。<br>`negative-date`|? → 南门门卫室 / ? / ?|2026-10-15日期；18:30时间|
|C04 / synthetic ([LOCAL](SOURCES.md))|【菜鸟】登录验证码583920，客服电话951966。<br>`negative-login`|不应提取|583920登录验证码；951966客服电话|
|C05 / synthetic ([LOCAL](SOURCES.md))|【中通快递】您有2个包裹在老六号楼（新4号楼）二单元106妈妈驿站，取货码9-4-0178、5-1-2889<br>`label-list`|9-4-0178 → 老六号楼（新4号楼）二单元106妈妈驿站 / 中通 / 妈妈驿站<br>5-1-2889 → 老六号楼（新4号楼）二单元106妈妈驿站 / 中通 / 妈妈驿站|包裹数量2；楼栋/单元/门牌|
|C06 / synthetic ([LOCAL](SOURCES.md))|【中通】已到北门菜鸟驿站，取件码3-2-4012。<br>【顺丰】已到南门丰巢柜，取件码829146。<br>`two-notifications`|3-2-4012 → 北门菜鸟驿站 / 中通 / 菜鸟<br>829146 → 南门丰巢柜 / 顺丰 / 丰巢|—|
|C07 / synthetic ([LOCAL](SOURCES.md))|【中通】已到北门菜鸟驿站<br>取件码3-2-4012<br>【顺丰】已到南门丰巢柜<br>取件码829146<br>`two-notifications`|3-2-4012 → 北门菜鸟驿站 / 中通 / 菜鸟<br>829146 → 南门丰巢柜 / 顺丰 / 丰巢|—|
|C08 / synthetic ([LOCAL](SOURCES.md))|【中通】已到北门驿站，取件码1234<br>【圆通】已到南门便利店，取件码1234<br>`same-code-different-place`|1234 → 北门驿站 / 中通 / ?<br>1234 → 南门便利店 / 圆通 / ?|—|
|C09 / synthetic ([LOCAL](SOURCES.md))|北门驿站<br>取件码<br>手机尾号2635<br>829146<br>`label-neighbor-phone`|829146 → 北门驿站 / ? / ?|2635手机号尾号|
|C10 / synthetic ([LOCAL](SOURCES.md))|北门驿站<br>取<br>件码041327<br>`ocr-split-label`|041327 → 北门驿站 / ? / ?|—|
|C11 / synthetic ([LOCAL](SOURCES.md))|【丰巢】取件码12-<br>4-6789至北门1号柜取件<br>`ocr-code-split`|12-4-6789 → 北门1号柜 / ? / 丰巢|跨行短横线|
|C12 / synthetic ([LOCAL](SOURCES.md))|【丰巢】取件码８２９１４６，已到北门丰巢柜<br>`unicode-code`|829146 → 北门丰巢柜 / ? / 丰巢|全角数字|
|C13 / synthetic ([LOCAL](SOURCES.md))|【菜鸟】取件码３－２－４０１２，已到东门菜鸟驿站<br>`unicode-code`|3-2-4012 → 东门菜鸟驿站 / ? / 菜鸟|全角数字与横线|
|C14 / synthetic ([LOCAL](SOURCES.md))|【丰巢】取件码O1286I，已到北门丰巢柜<br>`ocr-confusable`|? → 北门丰巢柜 / ? / 丰巢|O/0和I/1；候选O1286I/012861均未证实；保留原串并待确认|
|C15 / synthetic ([LOCAL](SOURCES.md))|【丰巢】凭取件码「829146」至东门2号柜取件<br>`quoted-code`|829146 → 东门2号柜 / ? / 丰巢|引号；柜号2|
|C16 / synthetic ([LOCAL](SOURCES.md))|【极兔速递】请凭A-12-08到晨光便利店取包裹，电话13000000000<br>`code-before-store`|A-12-08 → 晨光便利店 / 极兔 / ?|电话|
|C17 / synthetic ([LOCAL](SOURCES.md))|【申通】快件已存放在东区门卫室，取件码6688<br>`code-before-store`|6688 → 东区门卫室 / 申通 / ?|—|
|C18 / synthetic ([LOCAL](SOURCES.md))|淘宝订单信息<br>【京东物流】已到东区代收点，运单号JD0000000000000，取件码9321<br>`tracking-and-market`|9321 → 东区代收点 / 京东 / ?|淘宝是购物上下文；长运单号|
|C19 / synthetic ([LOCAL](SOURCES.md))|【邮政】已到东门服务站，取件码829146，手机尾号2635<br>`list-and-tail`|829146 → 东门服务站 / 邮政 / ?|手机尾号2635|
|C20 / synthetic ([LOCAL](SOURCES.md))|【邮政】已到东门服务站，取件码829146，2635为手机尾号<br>`list-and-tail`|829146 → 东门服务站 / 邮政 / ?|裸续项2635被后置词解释为尾号|
|C21 / synthetic ([LOCAL](SOURCES.md))|北门菜鸟驿站<br>取件码3-2-4012<br>【德邦】取件码829146<br>`location-cross-boundary`|3-2-4012 → 北门菜鸟驿站 / ? / 菜鸟<br>829146 → ? / 德邦 / ?|—|
|C22 / synthetic ([LOCAL](SOURCES.md))|地址<br>长兴路北段店<br>长兴路北段老李超市旁边<br>取件码<br>3-7-4162<br>`geometric-two-column`|3-7-4162 → 长兴路北段老李超市旁边 / ? / ?|两列键值及值续行|
|C23 / synthetic ([LOCAL](SOURCES.md))|【中通】已到北门驿站，取件码3-2-4012<br>【圆通】请凭7-3-0912到南门便利店取件<br>`mixed-label-strength`|3-2-4012 → 北门驿站 / 中通 / ?<br>7-3-0912 → 南门便利店 / 圆通 / ?|—|
|C24 / synthetic ([LOCAL](SOURCES.md))|【丰巢】取件码829***，已到北门丰巢柜<br>`code-masked`|? → 北门丰巢柜 / ? / 丰巢|码被部分遮挡|
|C25 / synthetic ([LOCAL](SOURCES.md))|快递暂存星河苑3-2-4012室，请联系门卫。<br>`negative-address-hyphen`|? → 星河苑3-2-4012室 / ? / ?|形似三段码的房间号|
|C26 / synthetic ([LOCAL](SOURCES.md))|【快宝驿站】凭取件码A-1-26-11到北门综合服务站取件<br>`shelf-date-tail`|A-1-26-11 → 北门综合服务站 / ? / 快宝驿站|26作为码组成部分|
|C27 / synthetic ([LOCAL](SOURCES.md))|【京东物流】包裹送至东区代收点，取件码为JD-9321，请及时领取。<br>`local-jd-labelled`|JD-9321 → 东区代收点 / 京东 / ?|—|
