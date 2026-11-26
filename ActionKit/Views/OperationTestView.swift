import SwiftUI
import UIKit

struct OperationTestView: View {
    let operation: Operation

    @State private var input = ""
    @State private var plusAsSpace = false
    @State private var output: String?
    @State private var errorMessage: String?
    @State private var isRunning = false
    @State private var copied = false
    @State private var task: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    var body: some View {
        Form {
            Section {
                Label(operation.needsNetwork ? "需要网络 · 可后台执行" : "本地处理 · 可后台执行",
                      systemImage: operation.needsNetwork ? "network" : "iphone")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.indigo)
                Text(operation.guidance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                TextEditor(text: $input)
                    .font(.body.monospaced())
                    .frame(minHeight: 160)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($inputFocused)
                    .accessibilityLabel(operation.inputLabel)
                    .disabled(isRunning)
                Button("填入示例") {
                    input = operation.example
                    output = nil
                    errorMessage = nil
                    copied = false
                }
                .disabled(isRunning)
                if operation == .decode {
                    Toggle("将 + 视为空格", isOn: $plusAsSpace)
                        .disabled(isRunning)
                }
            } header: {
                Text(operation.inputLabel)
            } footer: {
                Text("这里与快捷指令操作使用相同的处理逻辑；应用内测试不能代替快捷指令真机验证。")
            }

            Section {
                if isRunning {
                    HStack {
                        ProgressView()
                        Text("正在处理…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("取消", role: .cancel) { cancel() }
                    }
                } else {
                    Button(action: run) {
                        Label("运行测试", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
            }

            if let errorMessage {
                Section("无法完成") {
                    Label {
                        Text(errorMessage).textSelection(.enabled)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .foregroundStyle(.red)
                }
            }

            if let output {
                Section {
                    if output.isEmpty {
                        Text("返回了空文本。")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(output)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        UIPasteboard.general.string = output
                        copied = true
                    } label: {
                        Label(copied ? "已复制" : "复制结果", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                } header: {
                    Text("返回文本")
                } footer: {
                    Text("在快捷指令中，此结果会成为可供后续操作选择的魔法变量。")
                }
            }
        }
        .navigationTitle(operation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { inputFocused = false }
            }
        }
        .onDisappear { cancel() }
    }

    @MainActor
    private func run() {
        inputFocused = false
        output = nil
        errorMessage = nil
        copied = false
        isRunning = true
        let submittedInput = input
        let submittedPlusAsSpace = plusAsSpace
        task = Task { @MainActor in
            do {
                let value = try await operation.run(input: submittedInput, plusAsSpace: submittedPlusAsSpace)
                try Task.checkCancellation()
                output = value
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            // A cancelled task must not overwrite the state of a newer run.
            if !Task.isCancelled {
                isRunning = false
                task = nil
            }
        }
    }

    @MainActor
    private func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }
}
