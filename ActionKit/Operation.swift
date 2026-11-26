import Foundation
import ActionKitCore

enum Operation: String, CaseIterable, Identifiable {
    case echo, resolveWeChat, extractTicket, buildWeChat, parseAlipay, encode, decode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .echo: "测试文本"
        case .resolveWeChat: "解析微信小程序链接"
        case .extractTicket: "提取微信 Ticket"
        case .buildWeChat: "拼接微信小程序链接"
        case .parseAlipay: "解析支付宝链接参数"
        case .encode: "URL 编码"
        case .decode: "URL 解码"
        }
    }

    var symbol: String {
        switch self {
        case .echo: "text.bubble"
        case .resolveWeChat: "link"
        case .extractTicket: "ticket"
        case .buildWeChat: "link.badge.plus"
        case .parseAlipay: "curlybraces"
        case .encode: "arrow.up.doc"
        case .decode: "arrow.down.doc"
        }
    }

    var subtitle: String {
        switch self {
        case .echo: "原样返回，检查操作与魔法变量"
        case .resolveWeChat: "从 wxmpurl.cn 网页提取 URL Scheme"
        case .extractTicket: "从微信 URL Scheme 读取 t 参数"
        case .buildWeChat: "将已有 Ticket 拼接为微信链接"
        case .parseAlipay: "读取 URL 参数并返回 JSON 文本"
        case .encode: "将参数值转换为百分号编码"
        case .decode: "还原一层 UTF-8 百分号编码"
        }
    }

    var inputLabel: String {
        switch self {
        case .echo, .encode, .decode: "文本"
        case .resolveWeChat, .parseAlipay: "链接"
        case .extractTicket: "URL Scheme"
        case .buildWeChat: "Ticket"
        }
    }

    var example: String {
        switch self {
        case .echo: "你好，ActionKit！\n这是一段测试文本。"
        case .resolveWeChat: "https://wxmpurl.cn/请替换为真实链接"
        case .extractTicket: "weixin://dl/business/?t=example_ticket"
        case .buildWeChat: "example_ticket"
        case .parseAlipay: "alipays://platformapi/startapp?appId=2021000000000000&page=pages%2Findex&query=name%3DActionKit%26from%3Dshortcuts"
        case .encode: "你好 ActionKit + & / ?"
        case .decode: "%E4%BD%A0%E5%A5%BD%20ActionKit%20%2B%20%26%20%2F%20%3F"
        }
    }

    var guidance: String {
        switch self {
        case .echo:
            "输入内容会原样返回，包括空格、换行和表情。可以先用这个操作检查快捷指令是否能找到 ActionKit。"
        case .resolveWeChat:
            "输入完整的 HTTPS wxmpurl.cn 链接。ActionKit 读取网页中的静态 url_scheme，不运行 JavaScript。需要登录、验证、动态生成或已失效的页面可能无法解析。示例地址是占位符，请替换。"
        case .extractTicket:
            "读取 weixin://dl/business/?t= 中的 t 参数并解码一层。缺少、为空或重复的 t 参数会报错。示例 Ticket 仅用于格式测试，不能打开真实小程序。"
        case .buildWeChat:
            "输入已有、未编码的 Ticket。操作会编码参数值并返回微信 URL Scheme，不会创建、续期或验证 Ticket。需要跳转时，请在快捷指令中连接“打开 URL”。"
        case .parseAlipay:
            "解析链接中的查询参数并返回 JSON 文本，保留重复参数。外层参数只解码一次，+ 保持为 +；query 等参数中的嵌套内容仍是字符串。此操作不联网解析支付宝短链接，也不验证小程序是否可用。"
        case .encode:
            "按 UTF-8 编码单个参数值，仅保留字母、数字和 - . _ ~。请不要把编码后的完整 URL 当作可直接打开的链接。"
        case .decode:
            "只解码一层百分号编码。默认 + 保持不变；只有处理表单编码时才需要将其转换为空格。无效的百分号序列或 UTF-8 数据会报错。"
        }
    }

    var needsNetwork: Bool { self == .resolveWeChat }

    func run(input: String, plusAsSpace: Bool) async throws -> String {
        switch self {
        case .echo: ActionKitProcessor.echo(input)
        case .resolveWeChat: try await WeChatLinkFetcher().fetchScheme(from: input)
        case .extractTicket: try ActionKitProcessor.extractTicket(from: input)
        case .buildWeChat: try ActionKitProcessor.buildWeChatScheme(ticket: input)
        case .parseAlipay: try ActionKitProcessor.parseAlipayURL(input)
        case .encode: try ActionKitProcessor.encodeURLComponent(input)
        case .decode: try ActionKitProcessor.decodeURLComponent(input, plusAsSpace: plusAsSpace)
        }
    }
}
