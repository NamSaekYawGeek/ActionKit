import Foundation

/// Stateless data transformations shared by the app's tests and background App Intents.
public enum ActionKitProcessor {
    public static func echo(_ text: String) -> String { text }

    /// RFC 3986 component encoding, not whole-URL encoding. Existing '%' is encoded again.
    public static func encodeURLComponent(_ text: String) throws -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let result = text.addingPercentEncoding(withAllowedCharacters: unreserved) else {
            throw ActionKitError.invalidPercentEncoding
        }
        return result
    }

    /// Exactly one percent-decoding pass. '+' remains literal unless explicitly requested.
    public static func decodeURLComponent(_ text: String, plusAsSpace: Bool = false) throws -> String {
        let bytes = Array(text.utf8)
        var decoded: [UInt8] = []
        decoded.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 37 { // %
                guard index + 2 < bytes.count,
                      let high = hex(bytes[index + 1]), let low = hex(bytes[index + 2]) else {
                    throw ActionKitError.invalidPercentEncoding
                }
                decoded.append(high * 16 + low)
                index += 3
            } else {
                decoded.append(plusAsSpace && byte == 43 ? 32 : byte)
                index += 1
            }
        }
        guard let result = String(bytes: decoded, encoding: .utf8) else {
            throw ActionKitError.invalidPercentEncoding
        }
        return result
    }

    public static func extractTicket(from scheme: String) throws -> String {
        let components = try weChatComponents(scheme)
        let parameters = try queryParameters(components.percentEncodedQuery)
        let tickets = parameters.filter { $0.name == "t" }
        guard tickets.count <= 1 else { throw ActionKitError.ambiguousTicket }
        guard let ticket = tickets.first?.value, !ticket.isEmpty else { throw ActionKitError.missingTicket }
        guard !ticket.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw ActionKitError.invalidScheme
        }
        return ticket
    }

    /// A ticket is opaque data. It is encoded once; validity/expiry is determined by WeChat.
    public static func buildWeChatScheme(ticket: String) throws -> String {
        guard !ticket.isEmpty else { throw ActionKitError.emptyInput }
        guard !ticket.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw ActionKitError.invalidScheme
        }
        return "weixin://dl/business/?t=" + (try encodeURLComponent(ticket))
    }

    /// Reads static quoted JS/JSON strings only. Never evaluates remote JavaScript.
    public static func extractWeChatScheme(from html: String) throws -> String {
        guard !html.isEmpty else { throw ActionKitError.missingURLScheme }
        // Attributes can contain &quot; or numeric references around the JS string.
        let source = decodeHTMLEntities(html)
        let pattern = #"(?<![A-Za-z0-9_$#])(?:"url_scheme"|'url_scheme'|url_scheme)\s*[:=]\s*("(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*')"#
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        guard !matches.isEmpty else { throw ActionKitError.missingURLScheme }
        var candidates = Set<String>()
        var firstError: Error?
        for match in matches {
            guard let range = Range(match.range(at: 1), in: source) else { continue }
            do {
                // A literal prefix of an expression is not the value of that expression.
                // Reject concatenation, property/method calls and other dynamic continuations.
                let following = source[range.upperBound...].drop(while: { $0.isWhitespace })
                if let next = following.first, ![";", ",", "}", "<", ">"].contains(next) {
                    throw ActionKitError.invalidHTML
                }
                let candidate = try decodeJavaScriptString(String(source[range]))
                _ = try extractTicket(from: candidate)
                candidates.insert(candidate)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        guard !candidates.isEmpty else { throw firstError ?? ActionKitError.missingURLScheme }
        guard candidates.count == 1, let result = candidates.first else { throw ActionKitError.ambiguousURLScheme }
        return result
    }

    /// Returns JSON with an ordered parameter array, retaining duplicates and null values.
    /// Only the outer query is parsed. Nested 'query' values remain decoded strings.
    public static func parseAlipayURL(_ text: String) throws -> String {
        let components = try validatedComponents(text)
        guard let scheme = components.scheme?.lowercased(),
              ["https", "http", "alipays", "alipay"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else {
            throw ActionKitError.invalidURL
        }
        let parameters = try queryParameters(components.percentEncodedQuery)
        var object: [String: Any] = [
            "originalURL": text,
            "scheme": scheme,
            "host": host,
            "path": try decodeURLComponent(components.percentEncodedPath),
            "parameters": parameters.map { parameter -> [String: Any] in
                ["name": parameter.name, "value": parameter.value.map { $0 as Any } ?? NSNull()]
            },
            "fragment": components.percentEncodedFragment.map { $0 as Any } ?? NSNull()
        ]
        if let fragment = components.percentEncodedFragment {
            object["fragment"] = try decodeURLComponent(fragment)
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
        guard let result = String(data: data, encoding: .utf8) else { throw ActionKitError.invalidURL }
        return result
    }

    private struct QueryParameter {
        let name: String
        let value: String?
    }

    private static func queryParameters(_ query: String?) throws -> [QueryParameter] {
        guard let query, !query.isEmpty else { return [] }
        return try query.split(separator: "&", omittingEmptySubsequences: false).map { entry in
            let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return QueryParameter(
                name: try decodeURLComponent(String(parts[0])),
                value: parts.count == 2 ? try decodeURLComponent(String(parts[1])) : nil
            )
        }
    }

    private static func validatedComponents(_ text: String) throws -> URLComponents {
        guard !text.isEmpty else { throw ActionKitError.emptyInput }
        guard !text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }) else {
            throw ActionKitError.invalidURL
        }
        // Foundation may silently repair malformed '%' input; validate before constructing components.
        _ = try decodeURLComponent(text)
        guard let components = URLComponents(string: text), components.url != nil, components.scheme != nil else {
            throw ActionKitError.invalidURL
        }
        return components
    }

    private static func weChatComponents(_ text: String) throws -> URLComponents {
        let components = try validatedComponents(text)
        guard components.scheme?.lowercased() == "weixin", components.host?.lowercased() == "dl",
              components.percentEncodedPath == "/business/", components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil else {
            throw ActionKitError.invalidScheme
        }
        return components
    }

    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 65 + 10
        case 97...102: return byte - 97 + 10
        default: return nil
        }
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        let pattern = #"&(?:amp|quot|apos|lt|gt|#[0-9]+|#x[0-9A-Fa-f]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let entity = String(result[range])
            let named: [String: String] = ["&amp;": "&", "&quot;": "\"", "&apos;": "'", "&lt;": "<", "&gt;": ">"]
            if let replacement = named[entity] {
                result.replaceSubrange(range, with: replacement)
            } else {
                let isHex = entity.hasPrefix("&#x")
                let digits = entity.dropFirst(isHex ? 3 : 2).dropLast()
                if let value = UInt32(digits, radix: isHex ? 16 : 10), let scalar = UnicodeScalar(value), value != 0 {
                    result.replaceSubrange(range, with: String(scalar))
                }
            }
        }
        return result
    }

    private static func decodeJavaScriptString(_ quoted: String) throws -> String {
        let input = Array(quoted.unicodeScalars)
        guard input.count >= 2, input.first == input.last else { throw ActionKitError.invalidHTML }
        let quote = input[0]
        var output = String.UnicodeScalarView()
        var index = 1
        let end = input.count - 1
        func readHex(_ count: Int, at offset: Int) throws -> UInt32 {
            guard offset + count <= end else { throw ActionKitError.invalidHTML }
            var value: UInt32 = 0
            for position in offset..<(offset + count) {
                guard input[position].value < 128, let digit = hex(UInt8(input[position].value)) else {
                    throw ActionKitError.invalidHTML
                }
                value = value * 16 + UInt32(digit)
            }
            return value
        }
        while index < end {
            let scalar = input[index]
            index += 1
            if scalar != "\\" {
                guard scalar != quote, scalar != "\n", scalar != "\r" else { throw ActionKitError.invalidHTML }
                output.append(scalar)
                continue
            }
            guard index < end else { throw ActionKitError.invalidHTML }
            let escape = input[index]
            index += 1
            switch escape {
            case "\"", "'", "\\", "/": output.append(escape)
            case "b": output.append("\u{8}")
            case "f": output.append("\u{C}")
            case "n": output.append("\n")
            case "r": output.append("\r")
            case "t": output.append("\t")
            case "v": output.append("\u{B}")
            case "\n": break // JavaScript line continuation.
            case "\r": if index < end, input[index] == "\n" { index += 1 }
            case "x", "u":
                let length = escape == "x" ? 2 : 4
                var value = try readHex(length, at: index)
                index += length
                if (0xD800...0xDBFF).contains(value) {
                    guard index + 6 <= end, input[index] == "\\", input[index + 1] == "u" else {
                        throw ActionKitError.invalidHTML
                    }
                    let low = try readHex(4, at: index + 2)
                    guard (0xDC00...0xDFFF).contains(low) else { throw ActionKitError.invalidHTML }
                    value = 0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00)
                    index += 6
                }
                guard let decoded = UnicodeScalar(value) else { throw ActionKitError.invalidHTML }
                output.append(decoded)
            default: throw ActionKitError.invalidHTML
            }
        }
        return String(output)
    }
}
