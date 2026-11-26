# ActionKit

原生 SwiftUI iOS 应用，为苹果「快捷指令」提供七个可独立搜索和添加的 App Intents 操作。最低系统版本 **iOS 18.0**，目标设备包含 **iPhone 13 / iOS 18.3.2**。界面、参数说明与错误提示使用简体中文。

所有 AppIntent 都编译在 **ActionKit 主应用 target** 中。没有额外的 `.appex`，不需要 App Groups、越狱、JIT、私有 API 或付费开发者账号，也不会修改、替换微信或支付宝。编译本身无需任何 Apple 账号；通过 SideStore 安装仍需要用户自己的 Apple 账号和 SideStore 所需的正常签名设置。

## 验证状态

本仓库提供完整源码、单元测试、XcodeGen 工程配置、GitHub Actions 工作流和未签名 IPA 打包校验脚本。

- 当前交付环境为 Linux，无法执行 Apple Xcode、SwiftUI、App Intents 编译或 iOS 真机安装；**不能将代码检查视为 iOS 编译成功**。
- 工程 YAML、工作流 YAML、Info.plist 与打包脚本已做语法检查。
- 已在 Linux 的 Swift 6.0.3 工具链上编译 Foundation 核心库，**49 项单元测试通过**；覆盖核心处理、网络状态、取消与响应大小限制。这不覆盖 Apple 专有框架。SwiftUI / App Intents 源码另做了 Swift 语法解析，仍需 macOS SDK 的完整类型检查和元数据编译。
- GitHub Actions 将在 macOS 上先运行核心处理测试，再实际编译 arm64 真机应用。只有编译成功、App Intents 元数据存在且 IPA 校验通过，才上传 IPA。
- 实际 macOS 编译与 IPA 产物以 [GitHub Actions 运行记录](https://github.com/NamSaekYawGeek/ActionKit/actions) 和本次 PR 的 Checks 为准；仅下载成功运行中的 Artifact。Linux 测试不代替 Xcode 构建。
- **尚未真机验证**：iPhone 13 / iOS 18.3.2 安装和启动、七个操作的索引与搜索、魔法变量传递、后台与锁屏执行、SideStore 重签后元数据发现、真实微信网页抓取、真实微信 Ticket 有效性、支付宝真实分享链接兼容性、VoiceOver 和不同屏幕布局。详见文末验收清单。

## 操作

| 快捷指令中的操作名称 | 输入 | 输出 |
| --- | --- | --- |
| 测试文本（ActionKit） | 文本 | 原样文本，保留空白、换行和 Unicode |
| 解析微信小程序链接（ActionKit） | `wxmpurl.cn` 网页 URL | HTML 中的 `url_scheme` 文本 |
| 提取微信 Ticket（ActionKit） | 微信小程序 URL Scheme | 已有的 `t` 参数文本 |
| 拼接微信小程序链接（ActionKit） | 已有 Ticket | `weixin://dl/business/?t=...` 文本 |
| 解析支付宝链接参数（ActionKit） | 支付宝小程序链接 | JSON 文本；可交给「从输入中获取词典」继续处理 |
| URL 编码（ActionKit） | 任意文本 | RFC 3986 URL **组件**百分号编码文本 |
| URL 解码（ActionKit） | 百分号编码文本；可选「将 + 视为空格」 | 解码一次后的 UTF-8 文本 |

所有操作都有 `@Parameter` 参数、`parameterSummary` 和 `ReturnsValue<String>` 返回值。参数可使用上一步输出或魔法变量，结果可交给「文本」「显示结果」「从输入中获取词典」等系统操作。

操作的 `isDiscoverable = true`、`openAppWhenRun = false`。它们不需要显示 ActionKit 界面即可处理数据；这里的后台是指**快捷指令调用时允许在后台完成工作**，并非常驻后台服务。系统仍控制执行时限、锁屏访问、内存和网络权限，具体行为需要真机验证。遇到错误会抛出带中文说明的错误并停止当前操作，不将错误字符串冒充成功结果。

## 快速使用

1. 通过 SideStore 安装构建出的 IPA，打开 ActionKit 一次。
2. 在「操作」页面选择功能，可填入示例或自己的文本测试，并复制输出。
3. 打开系统「快捷指令」，新建快捷指令，添加操作，搜索 `ActionKit` 或上述中文操作名。也可在应用分类中查找 ActionKit。
4. 先运行「测试文本（ActionKit）」并接上「显示结果」，确认安装后的操作发现与文本传递正常。
5. 再组合需要的操作。可以将上一个操作的结果作为下一个操作的魔法变量。

微信示例流程：

```text
文本（实际的 https://wxmpurl.cn/... 链接）
  → 解析微信小程序链接（ActionKit）
  → 提取微信 Ticket（ActionKit）
  → 拼接微信小程序链接（ActionKit）
  → 显示结果
```

若需要打开生成的链接，可自行接上系统「打开 URL」操作。ActionKit 的数据处理操作本身不会打开微信或支付宝。

URL 组件编码示例：`你好 & a+b` → `%E4%BD%A0%E5%A5%BD%20%26%20a%2Bb`。编码操作适用于单个参数值；不要将整条 URL 编码后期待它仍能直接打开。解码默认保留 `+`，开启「将 + 视为空格」才采用表单查询字符串的约定。解码只执行一次，例如 `%252F` → `%2F`；不完整的 `%`、非法十六进制或无效 UTF-8 会报错。

## 微信与支付宝的边界

- 微信网页操作下载 HTML 后静态提取 `url_scheme`，不执行网页 JavaScript，也不绕过登录、验证码、反爬或风控。若网页通过运行脚本才生成值，或页面格式变化，提取可能失败。
- Ticket 提取与拼接只处理**已存在的 Ticket**，不申请、伪造、刷新 Ticket，也不延长有效期。微信服务器及微信客户端决定链接是否有效、是否允许跳转。
- 只提供与原应用并存的数据处理工具，没有修改任何第三方应用，也不注入其进程。
- 支付宝操作解析 URL 参数，不访问支付宝账号、不请求支付、不打开链接。嵌套编码参数按实现约定解析；输出 JSON 保留重复参数，避免简单字典覆盖数据。
- 除微信 HTML 抓取外，数据处理均在设备本地完成。微信操作会将用户输入的链接发送到目标站点；应用不包含分析 SDK，不主动上传 Ticket 或结果。请谨慎分享真实 Ticket。

支付宝参数解析接受带 host 的 `http`、`https`、`alipay`、`alipays` 完整 URL，不接受包含账号密码的链接。该操作只解析字符串，故不限制 HTTP(S) 链接域名。输出结构如下：

```json
{
  "originalURL": "alipays://platformapi/startapp?appId=123&x=1&x=2&flag&empty=",
  "scheme": "alipays",
  "host": "platformapi",
  "path": "/startapp",
  "parameters": [
    {"name": "appId", "value": "123"},
    {"name": "x", "value": "1"},
    {"name": "x", "value": "2"},
    {"name": "flag", "value": null},
    {"name": "empty", "value": ""}
  ],
  "fragment": null
}
```

参数名、参数值、path 和 fragment 严格按 UTF-8 百分号解码一次；`+` 保留为加号。参数数组保持原始顺序与重复项，区分没有等号的参数（`null`）与空字符串。嵌套的 `query` 参数仍是字符串，不自动递归解析或反复解码；需要时可显式接上 URL 解码操作。

HTML 提取支持静态的引号包围 `url_scheme` 属性或赋值、常用 JS 字符转义（包括 `\xNN` 和 `\uNNNN`）、数字 HTML 实体和 `amp` / `quot` / `apos` / `lt` / `gt`。不执行 JavaScript，不支持通过函数或字符串拼接动态生成 Scheme。

微信网络操作只接受 `wxmpurl.cn` 及其子域名的 HTTP(S) 输入，将 HTTP 输入升级为 HTTPS；拒绝用户凭证和非标准端口。最多允许 5 次 HTTPS 重定向，目标仅限 `wxmpurl.cn` 及其子域名、`mp.weixin.qq.com`。单次请求超时 15 秒，整个资源超时 30 秒，响应按流读取且上限 2 MiB；仅接受 UTF-8 HTML/纯文本，或未声明 MIME 的响应。使用临时 URLSession，不保存 Cookie 或磁盘缓存。若真实链接跳转到其它合法的新域名，将明确报错，需要确认后更新允许列表。

## 项目结构

```text
ActionKit/
  ActionKitApp.swift             SwiftUI 入口
  Operation.swift                操作目录与应用内测试调度
  Intents/ActionKitIntents.swift  七个 AppIntent，全部属于主应用
  Views/                        简体中文界面
Sources/ActionKitCore/           Foundation 解析、编码、错误与网络抓取
Tests/ActionKitCoreTests/        核心处理单元测试
docs/DEVICE-CHECKLIST.md         真机验收记录表
Config/Info.plist               应用信息，无额外扩展声明
Package.swift                  本地 Swift Package，供应用与测试共用
project.yml                    XcodeGen 工程定义
scripts/build-ipa.sh            真机编译与完整 app 打包
scripts/verify-ipa.py           IPA、架构、系统版本与元数据校验
.github/workflows/build-ipa.yml GitHub Actions macOS 构建
```

只有一个 iOS application target。核心 Swift Package 作为库链接进主应用，不生成安装到手机的扩展或独立 App ID。ActionKit 自身通常只需要一个 App ID；SideStore 本身和 Apple 免费账号的其它限制仍适用。

## GitHub Actions 构建

1. 将此目录完整提交到自己的 GitHub 仓库，确保 `.github/workflows/build-ipa.yml` 也已提交。
2. 在仓库 **Actions → Build unsigned ActionKit IPA → Run workflow** 手动运行。向 `main` / `master` 推送或提交 Pull Request 也会触发。
3. 工作流使用 `macos-15`，明确选择 `/Applications/Xcode_16.2.app`，安装 XcodeGen，执行 `swift test --parallel`，再生成 Xcode 工程并编译。
4. 成功后下载 **ActionKit-unsigned-ipa** Artifact，解压得到 `ActionKit.ipa` 和 SHA-256 文件。Artifact 本身的 ZIP 不是 IPA，不要直接交给 SideStore。
5. 若构建失败，查看任务日志及 **ActionKit-build-diagnostics** 中的 `xcodebuild.log` / `.xcresult`。不要使用失败任务留下的不完整文件。

工作流只需要 `contents: read`，不需要证书、描述文件、Apple ID、开发者 Team ID 或仓库 Secrets。没有发布到 App Store、TestFlight 或 GitHub Releases 的步骤。GitHub 托管 runner 的用量仍受 GitHub 账号配额约束。

`macos-14` 已在 2026 年 11 月停止支持，因此使用 `macos-15`。如 GitHub 后续移除 Xcode 16.2，应根据 [runner 官方软件清单](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) 更新工作流的 `DEVELOPER_DIR`；保持 deployment target 为 iOS 18.0，并重新完成兼容性验证。

### 元数据与未签名打包

`xcodebuild` 使用 `Release`、`iphoneos`、`generic/platform=iOS`、`ARCHS=arm64`，并以 `CODE_SIGNING_ALLOWED=NO` / `CODE_SIGNING_REQUIRED=NO` 禁用签名。正常保留 App Intents 编译阶段，不关闭元数据生成，不手工重建应用内容。

脚本完整复制 `ActionKit.app` 到 `Payload/ActionKit.app` 后 ZIP 打包。校验脚本要求：

- 应用为 iOS 18.0 起的 `iphoneos` arm64 Mach-O 二进制；
- 包内有非空 `Metadata.appintents/actionsdata`；
- 不含 `.appex`、`_CodeSignature` 或 `embedded.mobileprovision`。

元数据存在是快捷指令可发现操作的必要条件之一，**不等于已证明 SideStore 重签后系统完成索引**。该部分仍需真机验收。

## 在本地 Mac 编译

需要 macOS、完整 Xcode 16.2（或兼容的更新版本）、Xcode Command Line Tools 和 Homebrew。只安装命令行工具不能构建 iOS 应用。

```bash
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode_16.2.app/Contents/Developer
swift test --parallel
bash scripts/build-ipa.sh
```

成功产物位于 `dist/ActionKit.ipa`。如只想打开工程：

```bash
xcodegen generate --spec project.yml
open ActionKit.xcodeproj
```

`ActionKit.xcodeproj` 是生成文件，不提交到版本库；所有可复现配置保存在 `project.yml`。可以修改 `PRODUCT_BUNDLE_IDENTIFIER` 为自己的唯一值。若在 Xcode 中直接运行到设备，需要自己配置个人团队签名，这与工作流生成未签名 IPA 是两条独立流程。

## SideStore 安装

先按 [SideStore 官方文档](https://docs.sidestore.io/) 完成 SideStore 的安装、配对和当前版本要求的设置，再把 Artifact 解压得到的 `ActionKit.ipa` 导入 SideStore，由 SideStore 使用你的账号重签安装。

未签名 IPA 不能直接点击安装。免费个人团队的签名有效期、刷新要求、应用数量和 App ID 配额由 Apple 与 SideStore 决定；ActionKit 不会绕过这些限制。不要删除 app 内的 `Metadata.appintents`，也不要通过删除扩展的脚本处理此应用，因为本版本本来就没有扩展。

安装后打开一次应用，再进入快捷指令搜索。如果暂时没有操作，先检查 ActionKit 能正常启动，关闭并重新打开快捷指令，等待系统索引，必要时重启设备；仍未出现时检查下载的是成功任务产物、重签过程是否保留元数据，并记录 iOS / SideStore 版本。重新安装或签名标识改变后，旧快捷指令可能需要重新添加操作。

## 真机验收清单

以下项目均须在 **iPhone 13 / iOS 18.3.2** 上实测后才能标记通过：

- [ ] SideStore 能签名、安装、刷新和再次启动 ActionKit。
- [ ] 快捷指令能独立搜索、添加全部七个操作。
- [ ] 各输入参数接收魔法变量，输出能继续用于后续操作。
- [ ] 空文本、中文、emoji 和换行原样返回。
- [ ] 微信真实链接返回正确 Scheme；无效网页、断网、超时、缺少字段时报明确错误。
- [ ] Ticket 提取与拼接保持内容；真实 Ticket 的有效期和微信跳转行为按微信实际规则工作。
- [ ] 支付宝重复参数、嵌套编码、空参数与中文参数均符合预期。
- [ ] URL 编码/解码覆盖 `+`、空格、百分号、中文、emoji 和非法输入。
- [ ] ActionKit 未在前台时可由快捷指令执行；锁屏情形记录系统是否要求解锁。
- [ ] 使用说明、测试、取消、复制、深浅色、文字放大、横屏与 VoiceOver 正常。

实际网页与第三方链接格式可能随服务端更新而变化。提交兼容性问题时附上经过脱敏的链接结构、HTML 样本或错误信息，避免公开仍然有效的 Ticket。
