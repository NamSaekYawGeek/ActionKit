import AppIntents
import ActionKitCore

// These intents belong to the application target. No App Intents extension or
// AppShortcut phrase is required for discovery in the Shortcuts action editor.
// Returning String makes each result usable as a Shortcuts magic variable.

struct EchoTextIntent: AppIntent {
    static var title: LocalizedStringResource = "测试文本（ActionKit）"
    static var description = IntentDescription(
        "接收文本并原样返回，用于检查 ActionKit 的快捷指令操作和魔法变量。",
        categoryName: "ActionKit",
        searchKeywords: ["测试", "文本", "原样返回"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "文本", description: "需要原样返回的文本，包括空格和换行。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("原样返回 \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: ActionKitProcessor.echo(text))
    }
}

struct ResolveWeChatLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "解析微信小程序链接（ActionKit）"
    static var description = IntentDescription(
        "获取 wxmpurl.cn 链接的网页 HTML，提取静态 url_scheme 字段并返回微信 URL Scheme。需要网络；不会执行网页脚本或打开微信。",
        categoryName: "ActionKit",
        searchKeywords: ["微信", "wxmpurl", "小程序", "url_scheme"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "链接", description: "完整的 HTTPS wxmpurl.cn 小程序链接。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var link: String

    static var parameterSummary: some ParameterSummary {
        Summary("解析微信小程序链接 \(\.$link)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let scheme = try await WeChatLinkFetcher().fetchScheme(from: link)
        return .result(value: scheme)
    }
}

struct ExtractWeChatTicketIntent: AppIntent {
    static var title: LocalizedStringResource = "提取微信 Ticket（ActionKit）"
    static var description = IntentDescription(
        "从 weixin://dl/business/?t= 格式的微信小程序 URL Scheme 提取并解码 Ticket。离线处理。",
        categoryName: "ActionKit",
        searchKeywords: ["微信", "Ticket", "小程序", "提取"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "URL Scheme", description: "含有 t 参数的 weixin://dl/business/ 链接。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var scheme: String

    static var parameterSummary: some ParameterSummary {
        Summary("从 \(\.$scheme) 提取微信 Ticket")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try ActionKitProcessor.extractTicket(from: scheme))
    }
}

struct BuildWeChatSchemeIntent: AppIntent {
    static var title: LocalizedStringResource = "拼接微信小程序链接（ActionKit）"
    static var description = IntentDescription(
        "将已有 Ticket 编码为 t 参数，拼接 weixin://dl/business/?t= 链接。不会生成、续期或验证 Ticket。离线处理。",
        categoryName: "ActionKit",
        searchKeywords: ["微信", "Ticket", "拼接", "URL Scheme"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "Ticket", description: "已有的原始 Ticket；不要预先进行 URL 编码。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var ticket: String

    static var parameterSummary: some ParameterSummary {
        Summary("用 Ticket \(\.$ticket) 拼接微信链接")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try ActionKitProcessor.buildWeChatScheme(ticket: ticket))
    }
}

struct ParseAlipayURLIntent: AppIntent {
    static var title: LocalizedStringResource = "解析支付宝链接参数（ActionKit）"
    static var description = IntentDescription(
        "解析支付宝小程序链接的 URL 查询参数，返回 JSON 文本；保留重复参数。可连接快捷指令的“从输入中获取词典”操作继续读取字段。离线处理，不解析短链接跳转。",
        categoryName: "ActionKit",
        searchKeywords: ["支付宝", "小程序", "URL", "参数", "JSON"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "链接", description: "支付宝小程序 URL Scheme 或包含参数的网页 URL。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var link: String

    static var parameterSummary: some ParameterSummary {
        Summary("解析支付宝链接 \(\.$link) 的参数")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try ActionKitProcessor.parseAlipayURL(link))
    }
}

struct EncodeURLComponentIntent: AppIntent {
    static var title: LocalizedStringResource = "URL 编码（ActionKit）"
    static var description = IntentDescription(
        "按 UTF-8 对单个 URL 参数值进行百分号编码，只保留 RFC 3986 未保留字符。整个 URL 的冒号、斜杠和问号也会被编码。离线处理。",
        categoryName: "ActionKit",
        searchKeywords: ["URL", "编码", "百分号", "encode"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "文本", description: "需要编码的原始文本或单个参数值。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("URL 编码 \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try ActionKitProcessor.encodeURLComponent(text))
    }
}

struct DecodeURLComponentIntent: AppIntent {
    static var title: LocalizedStringResource = "URL 解码（ActionKit）"
    static var description = IntentDescription(
        "解码一层 UTF-8 百分号编码。默认保留 +；处理表单编码时可打开“将 + 视为空格”。无效的百分号或 UTF-8 编码会返回错误。离线处理。",
        categoryName: "ActionKit",
        searchKeywords: ["URL", "解码", "百分号", "decode"]
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "文本", description: "需要解码的百分号编码文本。", inputConnectionBehavior: .connectToPreviousIntentResult)
    var text: String

    @Parameter(title: "将 + 视为空格", default: false)
    var plusAsSpace: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("URL 解码 \(\.$text)") {
            \.$plusAsSpace
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try ActionKitProcessor.decodeURLComponent(text, plusAsSpace: plusAsSpace))
    }
}
