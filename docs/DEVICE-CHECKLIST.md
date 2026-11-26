# ActionKit 真机验收记录

状态：**待实测**。此表不是通过证明，只有在对应设备上实际执行后才能勾选。

| 环境 | 记录 |
| --- | --- |
| 设备 | iPhone 13 |
| iOS | 18.3.2 |
| ActionKit 版本 / Git 提交 | 待填写 |
| Actions 构建链接 / IPA SHA-256 | 待填写 |
| SideStore 版本 | 待填写 |
| 签名方式 / 安装后 bundle ID | 待填写，不记录账号密码 |
| 测试日期 | 待填写 |

## 安装与发现

- [ ] Actions 真机编译成功，下载 IPA 校验和匹配。
- [ ] SideStore 安装后可以打开应用、查看中文说明。
- [ ] 刷新签名后仍能打开应用与执行快捷指令。
- [ ] 系统快捷指令可以分别搜索到下表全部七个操作。
- [ ] ActionKit 无额外扩展，安装没有要求新增其它扩展 App ID。

## 七个操作

每项均须测试「直接输入」和「上一步文本的魔法变量输入」，并把返回结果继续传给系统「显示结果」。

| 操作 | 测试输入 | 预期 | 结果 |
| --- | --- | --- | --- |
| 测试文本（ActionKit） | 中文、emoji、前后空白、换行；另测空文本 | 原样返回 | 待测 |
| 解析微信小程序链接（ActionKit） | 有效的真实 wxmpurl.cn 链接 | 返回 HTML 中可用的 weixin Scheme | 待测 |
| 提取微信 Ticket（ActionKit） | `weixin://dl/business/?t=a%2Bb%26c` | `a+b&c` | 待测 |
| 拼接微信小程序链接（ActionKit） | `a+b&c` | `weixin://dl/business/?t=a%2Bb%26c` | 待测 |
| 解析支付宝链接参数（ActionKit） | `alipays://platformapi/startapp?appId=123&x=1&x=2&flag&empty=` | JSON 保留重复 x、null flag 和空 empty | 待测 |
| URL 编码（ActionKit） | `你好 & a+b` | `%E4%BD%A0%E5%A5%BD%20%26%20a%2Bb` | 待测 |
| URL 解码（ActionKit） | `a+b%20c` | 默认 `a+b c`；开关开启后 `a b c` | 待测 |

## 错误与系统行为

- [ ] 无效 URL、非 wxmpurl.cn 域名、HTTP 错误、HTML 缺少 url_scheme 均明确报错。
- [ ] 网页跳转、超时、断网、响应过大时操作结束并显示错误，不无限等待。
- [ ] 应用内网络测试可以取消；取消后不再覆盖新测试结果。
- [ ] 非微信 Scheme、缺少 t、重复 t、空 Ticket 被拒绝。
- [ ] 解码 `%`、`%GG`、`%FF` 会报错，不静默改写输入。
- [ ] 操作在 ActionKit 未处于前台时执行，不主动打开 ActionKit、微信或支付宝。
- [ ] 锁屏触发快捷指令，记录成功、需要解锁或系统拒绝的具体情况。
- [ ] 操作之间能通过魔法变量传递中文、emoji、长文本与 JSON。
- [ ] 真实 Ticket 的有效链接可通过后接系统「打开 URL」跳转；过期 Ticket 由微信决定结果。
- [ ] 真机真实支付宝链接与应用内解析结果一致。

## 界面

- [ ] 深浅色、竖屏与横屏布局正常。
- [ ] 大字体与 VoiceOver 能访问操作、参数、错误与复制结果。
- [ ] 输入中文、复制长结果、离开测试页面均正常。

## 问题记录

记录复现步骤、实际错误、系统是否要求解锁、是否发生在重签或更新之后。共享前删除真实 Ticket、账号信息与链接内敏感参数。
