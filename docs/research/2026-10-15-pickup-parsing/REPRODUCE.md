# 数据约定与复现方法

## 数据解释

`samples.jsonl`每行一条研究样本。稳定ID不复用；纠错保留ID和修改说明。字段：

- `source_id/source_url/retrieved_at/source_type`：出处与读取日。人工构造的source_url为null，不伪造网页来源。
- `representation`：脱敏文本、短摘录重建、仅结构、仅码格式或人工构造；不能因为source_type是public_real就认为回放的是原始短信。
- `source_excerpt`：必要的短摘录；可为空，不把推断写进引文。
- `text/ocr_lines/layout`：回放输入。没有ocr_lines时按文本换行。C22保留公开fixture的布局参考，纯逻辑回放不执行Vision排序或证实该布局真实。
- `expected_groups`：每条通知/包裹对应的码、地点、承运商、服务。每字段含value、state、evidence、原文跨度及可选note。跨度使用Unicode code point；将来Swift实现需显式转换成String.Index/UTF-16，不能把它当NSRange直接用。
- `known/not_stated/partial/masked/placeholder/ambiguous`：有依据、未说明、部分信息、遮挡、占位、歧义。null与空数组不是同义：无组的负例与组内缺字段分开。
- `template_family/duplicate_of/derived_from`：初步家族与派生链；来源同模板换数字不独立计数。本轮没有复制完全重复行，duplicate_of均为空；关系写在family、derived_from和注释中。
- `interference/ambiguities/annotation_note`：数字角色与标注限制；例如R04四位数字具体角色未知。
- `split=development_observed`：全部已参与研究，不能称为盲测留出。标注由本轮研究者完成，尚无独立人工复核。

`baseline-results.jsonl`保留每入口returned/error及原始返回字段；没有吞掉异常。42条四入口、1条仅手动入口，共169次。`isHighConfidence`仅为现有规则的布尔值，不是人工标签。当前混合platform没有强行映射为carrier。

## 复现规则回放

以下命令从当前工作树只读复制代码至临时目录，不改项目文件、不运行App。应先比对baseline-environment.json中的哈希；若代码已变化，输出属于新版本，不覆盖本轮证据。临时编译ImagePure只移除UIKit/Vision图像加载器和方向转换，保留其余类型与算法原样。Shared/PickupImageShareQueue.swift有既有未提交变更，记录的是当时工作树哈希，不单靠HEAD认版本。

在仓库根目录：

```sh
research_tmp=$(mktemp -d)
export SHOUXIA_RESEARCH_TMP="$research_tmp"
python3 - <<'PYCOPY'
from pathlib import Path
import os, shutil
p=Path(os.environ['SHOUXIA_RESEARCH_TMP'])
for f in ['Shouxia/Services/PickupParser.swift','Shouxia/Models/PickupRecord.swift','Shared/PickupSharedTextParser.swift','Shared/PickupImageShareQueue.swift']:
    shutil.copyfile(f,p/Path(f).name)
s=Path('Shouxia/Services/ImagePickupRecognizer.swift').read_text()
selected='import Foundation\n'+s[s.index('struct RecognizedTextLine'):s.index('struct ImageTextRecognizer')]+s[s.index('struct ImagePickupExtractor'):s.index('private extension CGImagePropertyOrientation')]
(p/'ImagePure.swift').write_text(selected)
PYCOPY
```

将以下内容保存到临时目录的`main.swift`：

```swift
import Foundation
func item(_ p: ParsedPickup) -> [String:Any] { ["code":p.code,"location":p.location as Any? ?? NSNull(),"platform":p.platform as Any? ?? NSNull()] }
func item(_ p: ImagePickupCandidate) -> [String:Any] { ["code":p.code,"location":p.location as Any? ?? NSNull(),"platform":p.platform as Any? ?? NSNull(),"isLabelled":p.isLabelled,"isHighConfidence":p.isHighConfidence,"ocrConfidence":p.confidence] }
func run(_ action: () throws -> [[String:Any]]) -> [String:Any] {
 do { return ["outcome":"returned","items":try action()] }
 catch {return ["outcome":"error","error":String(describing:error),"items":[]]}
}
let input=try String(contentsOfFile: CommandLine.arguments[1],encoding:.utf8)
for line in input.split(separator:"\n") {
 let s=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [String:Any]
 guard let text=s["text"] as? String else {continue}
 var result:[String:Any]=["id":s["id"]!,"inputRepresentation":s["representation"]!]
 result["manual"]=run {try PickupParser().parseAll(text).map(item)}
 if s["representation"] as? String != "format_only" {
  result["automatic"]=run {try PickupParser().parseAll(text, requiresLabel:true).map(item)}
  result["shared_text"]=run {try PickupSharedTextParser().candidates(from:text).map(item)}
  let strings=(s["ocr_lines"] as? [String]) ?? text.components(separatedBy:.newlines)
  let layout=s["layout"] as? [String:Any], boxes=layout?["boxes"] as? [[Double]]
  let lines=strings.enumerated().map { i,t in RecognizedTextLine(text:t,confidence:0.92,minX:boxes?[i][0] ?? 0,midY:boxes == nil ? Double(strings.count-i)*0.04 : 1-(boxes![i][1]+boxes![i][3]/2)/2400) }
  result["image_lines"]=run {try ImagePickupExtractor().candidates(from:lines).map(item)}
 }
 let data=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys,.withoutEscapingSlashes]);print(String(decoding:data,as:UTF8.self))
}

```

编译和运行（结果写临时目录，避免覆盖研究证据）：

```sh
xcrun swiftc "$research_tmp/PickupParser.swift" "$research_tmp/PickupRecord.swift" "$research_tmp/PickupSharedTextParser.swift" "$research_tmp/PickupImageShareQueue.swift" "$research_tmp/ImagePure.swift" "$research_tmp/main.swift" -o "$research_tmp/baseline"
"$research_tmp/baseline" docs/research/2026-10-15-pickup-parsing/samples.jsonl > "$research_tmp/baseline-results.jsonl"
```

C22盒子以左上原点像素记录，runner只投影为当前模型的minX/midY；当前extractor实际按传入行顺序关联，不能从这个回放宣称二维布局算法已通过。其余行给统一0.92，不能用于OCR置信度阈值校准。

## OCR探针

原图从S02的三个公开配图URL读取，只留在临时目录；没有添加到项目或分享给外部模型API。Vision读取原图，使用当前配置（accurate、中文优先、usesLanguageCorrection=false、top1），按当前排序规则生成RecognizedTextLine，再调用ImagePickupExtractor。使用的是macOS Vision URL handler，不是UIKit图片入口。只持久化码匹配与否、长度、地点是否存在及错误，不保存原始OCR全文或图片中的联系电话残片。

此探针得到R02成功、R03/R04 e5rt引擎错误；没有自动转成noPickupCode，也没有更换OCR模型掩盖错误。不能从样本名R03/R04推导它们已通过真实OCR。下列代码保存了该探针的完整实验方法；历史码在本轮仅用于内存内比对；为避免把截图码再次持久化，下列复现代码用占位字符串，复现者应从原图目视填入本地临时文件。不调用任何查询/取件服务。

```swift
import Foundation
import Vision
import ImageIO
let originals=["<从R02原图本地填入>","<从R03原图本地填入>","<从R04原图本地填入>"]
let root=CommandLine.arguments[1]
for i in 0..<3 {
 let u=URL(fileURLWithPath:root+"/public-\(i).jpg")
 let req=VNRecognizeTextRequest();req.recognitionLevel = .accurate;req.recognitionLanguages=["zh-Hans","en-US"];req.usesLanguageCorrection=false
 var row:[String:Any]=["sampleId":["R02","R03","R04"][i],"host":"macOS command-line Vision; not iOS UIKit pipeline","revision":req.revision,"languages":req.recognitionLanguages,"languageCorrection":req.usesLanguageCorrection,"topCandidates":1]
 do {
  row["supportedLanguages"]=try req.supportedRecognitionLanguages()
  try VNImageRequestHandler(url:u,options:[:]).perform([req])
  let observations=req.results ?? []
  let lines=observations.compactMap { o -> RecognizedTextLine? in
   guard let c=o.topCandidates(1).first else{return nil};return RecognizedTextLine(text:c.string,confidence:c.confidence,minX:o.boundingBox.minX,midY:o.boundingBox.midY)
  }.sorted { a,b in abs(a.midY-b.midY)>0.018 ? a.midY>b.midY : a.minX<b.minX }
  row["lineCount"]=lines.count
  let joined=lines.map(\.text).joined();row["historicalCodePresentInOCR"]=joined.contains(originals[i])
  do {
   let candidates=try ImagePickupExtractor().candidates(from:lines)
   row["extractorOutcome"]="returned";row["candidateCount"]=candidates.count
   row["historicalCodeExtracted"]=candidates.contains { $0.code==originals[i] }
   row["candidates"]=candidates.map { c -> [String:Any] in
    ["codeMatchesHistorical":c.code==originals[i],"codeLength":c.code.count,"locationPresent":c.location != nil,"locationLength":c.location?.count ?? 0,"platform":c.platform as Any? ?? NSNull(),"isLabelled":c.isLabelled,"isHighConfidence":c.isHighConfidence]
   }
  }catch{row["extractorOutcome"]="error";row["error"]=String(describing:error)}
 }catch {row["ocrOutcome"]="error";row["error"]=String(describing:error)}
 let d=try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]);print(String(decoding:d,as:UTF8.self))
}

```

将S02三个配图依次保存为临时目录public-0.jpg、public-1.jpg、public-2.jpg，替换临时main.swift为上述探针，使用PickupParser.swift、PickupRecord.swift、ImagePure.swift和main.swift编译（无需shared-text文件），传临时目录参数执行。重新运行的OS/设备/错误可能不同，应保存为新的实验记录。

## 研究验证边界

见validation.json：JSON结构/引用/证据跨度检查、169个入口结果数量、当前源哈希和本轮开始时所有既有未提交文件哈希对照。它证明研究产物结构可读与工作树边界，不证明研究标注已经双人验收、不证明新算法改善，也不证明真实iOS用户体验。
