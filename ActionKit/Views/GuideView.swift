import SwiftUI

struct GuideView: View {
    var body: some View {
        List {
            Section("添加到快捷指令") {
                step("1", title: "先打开一次 ActionKit", detail: "安装后先启动应用，再打开苹果“快捷指令”。")
                step("2", title: "搜索并添加操作", detail: "新建或编辑快捷指令，点“添加操作”，搜索 ActionKit 或具体操作名称。每个操作都可单独添加。")
                step("3", title: "连接魔法变量", detail: "点操作的输入字段，选取上一步的结果。所有操作都返回文本，可以直接传给下一步。")
            }

            Section("示例：微信小程序链接") {
                VStack(alignment: .leading, spacing: 12) {
                    pipelineRow("1", "文本", "填入真实的 https://wxmpurl.cn/… 链接")
                    pipelineRow("2", "解析微信小程序链接（ActionKit）", "输入选择上一步的文本")
                    pipelineRow("3", "提取微信 Ticket（ActionKit）", "输入选择解析结果，可保存 Ticket 供后续使用")
                    pipelineRow("4", "拼接微信小程序链接（ActionKit）", "输入选择 Ticket；如需跳转，再添加系统“打开 URL”")
                }
                .padding(.vertical, 6)
                Text("若只需要跳转，可把解析出的 URL Scheme 直接连接到系统“打开 URL”。跳转结果取决于微信版本、Ticket 有效期和小程序权限。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("示例：读取支付宝参数") {
                Text("把支付宝链接传给“解析支付宝链接参数（ActionKit）”，然后添加系统“从输入中获取词典”。读取 parameters 键，就能得到按原始顺序排列的参数列表；每项包含 name 和 value，重复参数也会保留。")
                    .font(.subheadline)
                Text("例如读取 App ID：对 parameters 列表使用“重复每一项”，找到 name 等于 appId 的项目，再读取它的 value。query 参数内的嵌套内容会作为文本返回，不会自动拆分。")
                    .font(.subheadline)
                Text("URL 编码与解码各自是一个独立操作。它们针对单个参数值，解码一次只去除一层百分号编码。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("后台执行与隐私") {
                Label("操作不要求打开 ActionKit", systemImage: "bolt")
                Text("所有操作都允许在快捷指令后台执行。网络请求仍受系统执行时限、网络状态和快捷指令自身权限限制；这不代表应用可无限持续后台运行。")
                Text("仅微信网页解析会请求输入的链接。其他处理在设备上完成。应用不保存输入历史，不收集统计数据；复制结果仅在你点击“复制结果”后写入剪贴板。")
            }
            .font(.subheadline)

            Section("限制与排查") {
                Text("找不到操作时，请确认安装的是保留了 App Intents 元数据的构建，先启动 ActionKit，然后重新打开快捷指令。系统索引可能需要时间。重新签名和安装后的发现行为仍需真机验证。")
                Text("微信网页解析只读取静态 HTML 中的 url_scheme；不执行 JavaScript，不绕过登录或验证。支付宝解析只读取 URL 本身，不跟随短链接。")
                Text("ActionKit 不生成 Ticket，也不延长其有效期；示例 Ticket 和示例支付宝 App ID 仅用于格式测试。")
                Text("最低系统版本为 iOS 18.0。iPhone 13 / iOS 18.3.2、SideStore 安装、快捷指令索引及后台运行均需要实际设备验收，不能由应用内测试替代。")
            }
            .font(.subheadline)

            Section {
                HStack {
                    Text("ActionKit")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                Text("原生 SwiftUI · App Intents · 无额外扩展")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("使用说明")
    }

    private func step(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.indigo, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }

    private func pipelineRow(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(number). \(title)")
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
