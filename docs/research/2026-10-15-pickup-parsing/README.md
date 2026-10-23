# 取件通知解析研究

本目录记录 2026-10-15 的样本采集、字段标注与解析基线。源码版本和文件哈希见 [baseline-environment.json](baseline-environment.json)。这是历史研究快照；当前识别机制见[本地识别](../../RECOGNITION.md)。

研究重点为通知边界、数字用途和取件码与地点/快递信息的关联。保留 Apple Vision 与本地规则作为实现基础，不依赖运行时网络服务。

## 内容

- [研究结论](RESEARCH.md)
- [样本审阅表](SAMPLES.md)与[机器可读标注](samples.jsonl)
- [来源索引](SOURCES.md)与[结构化来源](sources.json)
- [历史回放对照](BASELINE.md)与[原始结果](baseline-results.jsonl)
- [数据约定与复现](REPRODUCE.md)
- [OCR 探针结果](ocr-probe.jsonl)
- [第三方样本许可](THIRD_PARTY_NOTICES.md)

## 样本范围

共 44 条：7 条公开通知记录、2 条机构模板、3 条短信厂商模板、1 条厂商码格式、4 条开源用例和 27 条人工边界用例。公开通知包含脱敏改写、掩码和二手转录，表示类型逐条标注；初步划分为 37 个模板/机制家族。

43 条有可执行文本，T05 只有结构摘要。历史回放执行 169 次入口调用；三张公开图片的 macOS Vision 探针记录 1 次成功和 2 次计算引擎错误。

全部样本已参与研究与开发，不是独立留出集。结果不代表真实用户分布、未知模板准确率或 iPhone OCR 验收。数据和历史输出保留原样，新的回放写入独立输出目录。
