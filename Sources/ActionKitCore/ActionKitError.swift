import Foundation

/// Errors are safe to display in Shortcuts and in the app. They never include ticket values.
public enum ActionKitError: LocalizedError, Equatable, Sendable {
    case emptyInput
    case invalidURL
    case invalidScheme
    case missingTicket
    case ambiguousTicket
    case missingURLScheme
    case ambiguousURLScheme
    case invalidPercentEncoding
    case invalidHTML
    case network(String)
    case httpStatus(Int)
    case responseTooLarge
    case unsupportedEncoding
    case redirectNotAllowed
    case tooManyRedirects

    public var errorDescription: String? {
        switch self {
        case .emptyInput: return "输入不能为空。"
        case .invalidURL: return "URL 无效：请提供完整链接，检查空格、域名和百分号编码。"
        case .invalidScheme: return "微信 Scheme 无效：需要 weixin://dl/business/?t=… 格式。"
        case .missingTicket: return "链接中没有非空的 t（Ticket）参数。"
        case .ambiguousTicket: return "链接包含多个 t 参数，无法确定应使用哪个 Ticket。"
        case .missingURLScheme: return "网页中未找到可读取的 url_scheme。页面可能已失效，或需要登录、验证或执行 JavaScript。"
        case .ambiguousURLScheme: return "网页包含多个不同的 url_scheme，无法安全确定目标链接。"
        case .invalidPercentEncoding: return "百分号编码无效：每个 % 后必须有两位十六进制数字，且解码结果必须是有效 UTF-8。"
        case .invalidHTML: return "网页中的 url_scheme 字符串格式不受支持或转义不完整。"
        case .network(let reason): return "获取网页失败：\(reason)"
        case .httpStatus(let status): return "服务器返回 HTTP \(status)，无法读取小程序链接。"
        case .responseTooLarge: return "网页超过允许的大小（2 MiB），已停止读取。"
        case .unsupportedEncoding: return "网页字符编码不受支持，无法读取 HTML。"
        case .redirectNotAllowed: return "网页重定向到不允许的地址；仅允许 HTTPS 的 wxmpurl.cn、其子域名和 mp.weixin.qq.com。"
        case .tooManyRedirects: return "网页重定向次数过多，已停止请求。"
        }
    }
}
