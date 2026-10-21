# 收下 1.3.0（33）TestFlight 上传记录

2026-10-21，用户明确授权提交TestFlight。归档基于已推送的`337ad87fa5d82a7019afe06b7d651b516aad9ae2`，不增加功能或更改build。候选范围和测试说明见[版本记录](RELEASE_1.3.0_33.md)。

## 来源与归档验证

- Xcode27.1（27A9275）Release签名归档成功；主App、分享扩展、小组件均为1.3.0（33），最低iOS16。
- 57份应用/工程/测试/媒体哈希与提交源码及构建前快照一致；三个bundle严格签名、App Group与Mach-O/dSYM UUID匹配，主App深度签名通过，声明不使用非豁免加密。
- 四份视频/封面与提交资源SHA-256一致，只进入主App。应用实现和媒体沿用用户一般试用认可的32，仅工程版本元数据变化。
- 沿用同一源码刚完成的162项host测试与1,968项四入口断言，不重复跑无变化测试。归档不代表新用户独立配置、真实短信、旧系统或完整视觉验收。
- 归档与凭据目录为`.private/releases/1.3.0-33/`，包括`Shouxia-1.3.0-33.xcarchive`、`archive.log`、`archive-validation.json`、`source-manifest.json`及`source-snapshot/`。
- 上传选项为app-store-connect、destination=upload、自动签名、不自动改版本；`uploadSymbols=false`，dSYM保存在本地归档。

## 当前上传状态

**2026-10-21 15:39:43 +0800 上传成功，Apple已接收并开始处理。** 用户恢复Xcode账号/团队访问后，复用同一1.3.0（33）归档续传，没有重新编译或更改build。第二轮`xcodebuild -exportArchive`退出0，包含`Uploaded package is processing.`、`Upload succeeded.`及`EXPORT SUCCEEDED`三项成功标记。上传后再次核对57份源码哈希，与归档快照及337ad87一致。

成功回执为`upload-attempt-2.json`和最新状态`upload-receipt.json`，日志为`upload-attempt-2.log`。Apple后续处理完成、TestFlight可安装及测试组可见性尚未确认；未修改测试组、邀请测试者、提交Beta Review、正式App Store审核或发布。

## 首轮上传历史：账号检查受阻，后已恢复

**2026-10-21 15:31 +0800，上传未成功，Apple尚未接收33。** `xcodebuild -exportArchive`退出70，在`IDEDistributionUploadAccountStep`报`Failed to Use Accounts`：Xcode找不到具有团队App Store Connect访问权限的账号。这不是Apple对二进制包的处理或审核拒绝，也不能据此断言账号已过期。

本地当时未发现可用的替代App Store Connect API上传凭据。用户随后明确回复已处理Xcode → Settings → Accounts的开发者账号及团队访问，第二轮复用同一33归档上传成功。Agent没有打开Xcode、操作账号界面或请求账号密码。

失败回执保留在`upload-attempt-1.json`、`upload-attempt-1.log`；初次`upload.log`保留，第二轮使用独立日志，不覆盖失败证据。`upload-receipt.json`更新为第二轮成功后的当前状态，首轮失败不再代表当前上传状态。

## 测试说明

暂沿用[1.3.0候选中的本地测试草稿](RELEASE_1.3.0_33.md#testflight测试说明本地草稿)，尚未写入App Store Connect。重点请不熟悉快捷指令的测试者仅靠App内教程完成配置，并以真实短信验证；看完视频不等于配置成功。
