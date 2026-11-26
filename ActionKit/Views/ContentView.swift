import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("为快捷指令添一份能力", systemImage: "square.stack.3d.up.fill")
                                .font(.headline)
                                .foregroundStyle(.indigo)
                            Text("小程序链接、Ticket 与 URL 工具。每个操作都能独立添加到快捷指令，并把结果传给下一步。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 16) {
                                Label("7 个操作", systemImage: "square.grid.2x2")
                                Label("支持后台运行", systemImage: "bolt")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    Section("操作与测试") {
                        ForEach(Operation.allCases) { operation in
                            NavigationLink {
                                OperationTestView(operation: operation)
                            } label: {
                                OperationRow(operation: operation)
                            }
                        }
                    }

                    Section {
                        Text("除微信网页解析需要网络外，所有处理均在设备上完成。ActionKit 不会自动打开或修改微信、支付宝等应用。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("ActionKit")
            }
            .tabItem { Label("操作", systemImage: "square.grid.2x2") }

            NavigationStack {
                GuideView()
            }
            .tabItem { Label("使用说明", systemImage: "book.closed") }
        }
    }
}

private struct OperationRow: View {
    let operation: Operation

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: operation.symbol)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 42, height: 42)
                .background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(operation.title)
                    .font(.body.weight(.medium))
                Text(operation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}
