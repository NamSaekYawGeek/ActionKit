import Foundation
import XCTest
@testable import ActionKitCore

final class ProcessorTests: XCTestCase {
    func testEchoPreservesTextExactly() {
        let input = "  测试 👨‍👩‍👧‍👦\n第二行\t"
        XCTAssertEqual(ActionKitProcessor.echo(input), input)
        XCTAssertEqual(ActionKitProcessor.echo(""), "")
    }

    func testComponentEncodingUsesOnlyRFC3986UnreservedCharacters() throws {
        XCTAssertEqual(try ActionKitProcessor.encodeURLComponent("AZaz09-._~"), "AZaz09-._~")
        XCTAssertEqual(try ActionKitProcessor.encodeURLComponent("a b+c&d=e/f?g#h"), "a%20b%2Bc%26d%3De%2Ff%3Fg%23h")
    }

    func testUnicodeComponentRoundTrip() throws {
        let input = "中文 / 🙂 + 100%"
        let encoded = try ActionKitProcessor.encodeURLComponent(input)
        XCTAssertTrue(encoded.contains("%E4%B8%AD"))
        XCTAssertEqual(try ActionKitProcessor.decodeURLComponent(encoded), input)
    }

    func testEmptyComponentRoundTrip() throws {
        XCTAssertEqual(try ActionKitProcessor.encodeURLComponent(""), "")
        XCTAssertEqual(try ActionKitProcessor.decodeURLComponent(""), "")
    }

    func testDecoderPreservesPlusByDefault() throws {
        XCTAssertEqual(try ActionKitProcessor.decodeURLComponent("a+b%2Bc"), "a+b+c")
    }

    func testFormDecoderConvertsLiteralPlusButNotEncodedPlus() throws {
        XCTAssertEqual(try ActionKitProcessor.decodeURLComponent("a+b%2Bc", plusAsSpace: true), "a b+c")
    }

    func testDecoderOnlyDecodesOnce() throws {
        XCTAssertEqual(try ActionKitProcessor.decodeURLComponent("%2526%253D"), "%26%3D")
    }

    func testDecoderRejectsMalformedPercentEscapes() {
        for input in ["%", "%A", "%GG", "abc%2Z"] {
            XCTAssertThrowsError(try ActionKitProcessor.decodeURLComponent(input), input)
        }
    }

    func testDecoderRejectsInvalidUTF8() {
        for input in ["%FF", "%C0%AF", "%E4%B8"] {
            XCTAssertThrowsError(try ActionKitProcessor.decodeURLComponent(input), input)
        }
    }

    func testTicketExtractionDecodesOnceAndPreservesPlus() throws {
        XCTAssertEqual(try ActionKitProcessor.extractTicket(from: "weixin://dl/business/?t=a%2Fb+c%2520"), "a/b+c%20")
    }

    func testTicketBuildAndExtractRoundTrip() throws {
        let ticket = "票据+a/b&c=d%20🙂"
        let scheme = try ActionKitProcessor.buildWeChatScheme(ticket: ticket)
        XCTAssertTrue(scheme.hasPrefix("weixin://dl/business/?t="))
        XCTAssertTrue(scheme.contains("%26"))
        XCTAssertEqual(try ActionKitProcessor.extractTicket(from: scheme), ticket)
    }

    func testTicketExtractionAllowsUnrelatedQueryParameters() throws {
        XCTAssertEqual(try ActionKitProcessor.extractTicket(from: "weixin://dl/business/?foo=bar&t=actual&source=test"), "actual")
    }

    func testTicketExtractionRejectsMissingAndEmptyTicket() {
        for input in ["weixin://dl/business/", "weixin://dl/business/?foo=t", "weixin://dl/business/?t", "weixin://dl/business/?t="] {
            XCTAssertThrowsError(try ActionKitProcessor.extractTicket(from: input), input)
        }
    }

    func testTicketExtractionRejectsDuplicateTicketEvenIfValuesMatch() {
        for input in ["weixin://dl/business/?t=one&t=two", "weixin://dl/business/?t=same&t=same"] {
            XCTAssertThrowsError(try ActionKitProcessor.extractTicket(from: input), input)
        }
    }

    func testTicketExtractionRejectsWrongSchemeHostAndPath() {
        for input in ["https://dl/business/?t=a", "weixin://evil/business/?t=a", "weixin://dl/other/?t=a", "not a URL"] {
            XCTAssertThrowsError(try ActionKitProcessor.extractTicket(from: input), input)
        }
    }

    func testTicketExtractionRejectsInvalidEscapes() {
        XCTAssertThrowsError(try ActionKitProcessor.extractTicket(from: "weixin://dl/business/?t=%GG"))
        XCTAssertThrowsError(try ActionKitProcessor.extractTicket(from: "weixin://dl/business/?t=%FF"))
    }

    func testTicketBuilderRejectsEmptyTicket() {
        XCTAssertThrowsError(try ActionKitProcessor.buildWeChatScheme(ticket: ""))
    }

    func testHTMLExtractsJavaScriptAssignment() throws {
        let html = #"<html><script>var url_scheme = 'weixin://dl/business/?t=abc';</script></html>"#
        XCTAssertEqual(try ActionKitProcessor.extractWeChatScheme(from: html), "weixin://dl/business/?t=abc")
    }

    func testHTMLExtractsJSONAndEscapedSlashes() throws {
        let html = #"<script>var config = {"url_scheme":"weixin:\/\/dl\/business\/?t=abc"};</script>"#
        XCTAssertEqual(try ActionKitProcessor.extractWeChatScheme(from: html), "weixin://dl/business/?t=abc")
    }

    func testHTMLExtractsUnicodeEscapes() throws {
        let html = #"<script>url_scheme = "weixin\u003a\u002f\u002fdl\u002fbusiness\u002f?t=abc";</script>"#
        XCTAssertEqual(try ActionKitProcessor.extractWeChatScheme(from: html), "weixin://dl/business/?t=abc")
    }

    func testHTMLDecodesEntitiesInAttribute() throws {
        let html = #"<div data-config="{&quot;url_scheme&quot;:&quot;weixin://dl/business/?t=abc&amp;source=web&quot;}"></div>"#
        XCTAssertEqual(try ActionKitProcessor.extractWeChatScheme(from: html), "weixin://dl/business/?t=abc&source=web")
    }

    func testHTMLRejectsMissingOrUnsupportedScheme() {
        XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: "<html>没有链接</html>"))
        XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: #"<script>url_scheme = "https://example.com/?t=abc"</script>"#))
    }

    func testHTMLRejectsAmbiguousSchemes() {
        let html = #"<script>url_scheme = "weixin://dl/business/?t=first"; url_scheme = "weixin://dl/business/?t=second";</script>"#
        XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: html))
    }

    func testHTMLAllowsRepeatedIdenticalScheme() throws {
        let html = #"<script>url_scheme = "weixin://dl/business/?t=abc"; url_scheme = 'weixin://dl/business/?t=abc';</script>"#
        XCTAssertEqual(try ActionKitProcessor.extractWeChatScheme(from: html), "weixin://dl/business/?t=abc")
    }

    func testHTMLDoesNotExecuteJavaScriptExpressions() {
        XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: #"<script>url_scheme = decodeURIComponent("weixin%3A%2F%2Fdl%2Fbusiness%2F%3Ft%3Dabc");</script>"#))
    }

    func testHTMLRejectsLiteralPrefixesOfDynamicExpressions() {
        for expression in [
            #""weixin://dl/business/?t=abc" + suffix"#,
            #""weixin://dl/business/?t=abc".replace("abc", ticket)"#,
            #""weixin://dl/business/?t=abc" /* comment */ + suffix"#
        ] {
            XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: "<script>url_scheme = \(expression);</script>"))
        }
        XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: #"#url_scheme = "weixin://dl/business/?t=abc";"#))
    }

    func testHTMLDecodesHexAndSurrogatePairEscapes() throws {
        let html = #"url_scheme = "weixin\x3a//dl/business/?t=\uD83D\uDE42";"#
        XCTAssertEqual(try ActionKitProcessor.extractTicket(from: ActionKitProcessor.extractWeChatScheme(from: html)), "🙂")
    }

    func testHTMLRejectsUnpairedSurrogateAndInvalidHexEscapes() {
        for escapedTicket in [#"\uD83D"#, #"\uDE42"#, #"\uD83D\u0041"#, #"\xZZ"#, #"\u12"#] {
            XCTAssertThrowsError(try ActionKitProcessor.extractWeChatScheme(from: "url_scheme = \"weixin://dl/business/?t=\(escapedTicket)\";"))
        }
    }

    func testAlipayRetainsEmptyQuerySeparators() throws {
        let params = try parameters(alipayObject("alipays://platformapi/startapp?&appId=123&&"))
        XCTAssertEqual(params.count, 4)
        XCTAssertEqual(params.map { $0["name"] as? String }, ["", "appId", "", ""])
        XCTAssertTrue(params[0]["value"] is NSNull)
    }

    func testAlipayParametersAreDecodedOnce() throws {
        let value = try alipayObject("alipays://platformapi/startapp?appId=2021000000000000&page=pages%2Fhome&name=%E4%B8%AD%E6%96%87&encoded=%2526")
        XCTAssertEqual(value["scheme"] as? String, "alipays")
        XCTAssertEqual(value["host"] as? String, "platformapi")
        let params = try parameters(value)
        XCTAssertEqual(params.map { $0["name"] as? String }, ["appId", "page", "name", "encoded"])
        XCTAssertEqual(params.map { $0["value"] as? String }, ["2021000000000000", "pages/home", "中文", "%26"])
    }

    func testAlipayDuplicateAndEmptyParametersRemainDistinguishable() throws {
        let params = try parameters(alipayObject("alipays://platformapi/startapp?tag=first&tag=second&empty=&flag"))
        XCTAssertEqual(params.count, 4)
        XCTAssertEqual(params[0]["value"] as? String, "first")
        XCTAssertEqual(params[1]["value"] as? String, "second")
        XCTAssertEqual(params[2]["value"] as? String, "")
        XCTAssertNil(params[3]["value"] as? String)
    }

    func testAlipayKeepsNestedQueryAsSingleParameter() throws {
        let params = try parameters(alipayObject("alipays://platformapi/startapp?query=a%3D1%26b%3Dtwo%2520words&plus=a+b"))
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params[0]["value"] as? String, "a=1&b=two%20words")
        XCTAssertEqual(params[1]["value"] as? String, "a+b")
    }

    func testAlipayRejectsMalformedURLAndPercentEncoding() {
        for input in ["", "not a URL", "alipays://platformapi/startapp?name=%ZZ", "alipays://platformapi/startapp?name=%FF"] {
            XCTAssertThrowsError(try ActionKitProcessor.parseAlipayURL(input), input)
        }
    }

    func testAlipaySeparatesFragmentFromQuery() throws {
        let value = try alipayObject("alipays://platformapi/startapp?appId=123#details")
        XCTAssertEqual(value["fragment"] as? String, "details")
        XCTAssertEqual(try parameters(value).first?["value"] as? String, "123")
    }

    private func alipayObject(_ url: String) throws -> [String: Any] {
        let output = try ActionKitProcessor.parseAlipayURL(url)
        let data = try XCTUnwrap(output.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func parameters(_ object: [String: Any]) throws -> [[String: Any]] {
        try XCTUnwrap(object["parameters"] as? [[String: Any]])
    }
}
