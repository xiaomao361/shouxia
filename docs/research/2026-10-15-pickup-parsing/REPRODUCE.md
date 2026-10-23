# 数据约定与复现

## 标注结构

`samples.jsonl` 每行一条样本。ID 稳定且不复用，纠错时保留标识并补充说明。

| 字段 | 含义 |
| --- | --- |
| `source_id` / `source_url` / `retrieved_at` / `source_type` | 来源、采集日期及类型；构造样本无网页 URL |
| `representation` | 脱敏文本、短摘录重建、结构摘要、码格式或人工构造 |
| `source_excerpt` | 必要短摘录，不包含推断 |
| `text` / `ocr_lines` / `layout` | 文本与可选 OCR 行、布局输入 |
| `expected_groups` | 各通知的码、地点、承运商与服务，以及字段状态、证据和原文跨度 |
| `template_family` / `duplicate_of` / `derived_from` | 模板家族与派生关系 |
| `interference` / `ambiguities` / `annotation_note` | 干扰角色、歧义及标注限制 |
| `split` | `development_observed`，表示已参与研究与开发 |

字段状态包括 `known`、`not_stated`、`partial`、`masked`、`placeholder` 和 `ambiguous`。无组的负例与组内缺字段不同，`null` 与空数组不等同。跨度按 Unicode code point 计数，使用 Swift `NSRange` 前需要转换为 UTF-16 范围。

C22 的布局来自公开 fixture 参考，纯逻辑回放不执行 Vision 排序，也不证明原始版式。来源是公开通知不表示当前文本为逐字原件，应同时查看 `representation`。

## 当前源码回放

在仓库根目录执行：

```sh
bash scripts/replay_pickup_samples.sh docs/research/2026-10-15-pickup-parsing/samples.jsonl
python3 scripts/check_pickup_recognition.py --output /tmp/shouxia-recognition-check
```

脚本只读复制实际 Swift 源码至临时目录，编译后执行。图片入口使用标注行，不运行真实 OCR。第一条命令输出诊断，第二条执行固定预期断言；完整主机测试入口见[开发指南](../../DEVELOPMENT.md)。

使用当前源码得到的是新回放，不应覆盖历史基线文件。需要对隔离的源码快照运行断言时，可使用 `check_pickup_recognition.py --source-root` 参数；源码集合须完整且与目标版本匹配。

## 历史基线

`baseline-environment.json` 记录 2026-10-15 的 Git HEAD 与实际工作树文件哈希。该实验包含当时未提交的文件，因此只检出记录的提交不能证明已还原全部实验源码。

`baseline-results.jsonl` 保存 42 条四入口与 1 条仅手动入口的结果，共 169 次调用；T05 仅有结构，不执行。结果区分 `returned` 与 `error`，保留错误类型。`isHighConfidence` 是实现输出，不是人工真值；历史 `platform` 不强行转换成承运商。

与基线比较前先核对文件哈希；缺少匹配源码时只能检查历史产物，不能声称精确重跑。现有脚本的结果结构可能随实现演进，应与其版本一并记录。

## OCR 探针范围

[ocr-probe.jsonl](ocr-probe.jsonl) 保存三张公开图片的 macOS Vision 观察。配置为 accurate、`zh-Hans/en-US`、关闭语言纠正和 top1，输入使用 URL handler，与 iOS UIKit 加载链不同。

探针保存匹配结果、长度、地点是否存在及具体错误，不保存原图、OCR 全文或联系电话片段。R02 成功，R03/R04 为计算引擎错误；失败不转换为无取件码。

重新采集时应记录宿主、系统、Vision revision、支持语言、请求配置、输入来源与代码哈希。新结果写入独立文件；不同宿主的结果不能覆盖原实验或直接解释为 iPhone 缺陷。

## 结果限制

[validation.json](validation.json) 记录历史数据结构、引用、证据跨度、结果数量与源码哈希检查。它不证明标注已独立复核、算法对未知模板有效或真实设备体验通过。
