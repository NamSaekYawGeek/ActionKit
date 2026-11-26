import Foundation
import XCTest
@testable import ActionKitCore

final class WeChatLinkFetcherTests: XCTestCase {
    func testInputUpgradesHTTPAndDropsFragment() throws {
        let url = try WeChatLinkFetcher.validatedInput("  http://wxmpurl.cn/example?t=123#section\n")
        XCTAssertEqual(url.absoluteString, "https://wxmpurl.cn/example?t=123")
    }

    func testInputAllowsHTTPSAndSubdomain() throws {
        XCTAssertEqual(try WeChatLinkFetcher.validatedInput("https://a.wxmpurl.cn/test").host, "a.wxmpurl.cn")
        XCTAssertEqual(try WeChatLinkFetcher.validatedInput("http://wxmpurl.cn:80/test").absoluteString, "https://wxmpurl.cn/test")
        XCTAssertEqual(try WeChatLinkFetcher.validatedInput("https://wxmpurl.cn:443/test").absoluteString, "https://wxmpurl.cn/test")
    }

    func testInputRejectsOtherHostsCredentialsAndPorts() {
        for input in [
            "https://wxmpurl.cn.evil.example/a", "https://notwxmpurl.cn/a",
            "https://mp.weixin.qq.com/a", "https://user@wxmpurl.cn/a",
            "https://user:password@wxmpurl.cn/a", "https://wxmpurl.cn:8080/a",
            "https://wxmpurl.cn:80/a", "ftp://wxmpurl.cn/a", "file:///wxmpurl.cn/a",
            "wxmpurl.cn/a", "", "   "
        ] {
            XCTAssertThrowsError(try WeChatLinkFetcher.validatedInput(input), input)
        }
    }

    func testInputRejectsMalformedEscapesAndEmbeddedWhitespace() {
        for input in ["https://wxmpurl.cn/%", "https://wxmpurl.cn/%GG", "https://wxmpurl.cn/a b", "https://wxmpurl.cn/a\nb"] {
            XCTAssertThrowsError(try WeChatLinkFetcher.validatedInput(input), input)
        }
    }

    func testRedirectAllowsOnlyHTTPSHostsInAllowlist() throws {
        for input in ["https://wxmpurl.cn/a", "https://a.wxmpurl.cn/a", "https://mp.weixin.qq.com/a", "https://mp.weixin.qq.com:443/a"] {
            XCTAssertTrue(WeChatLinkFetcher.isAllowedRedirect(try XCTUnwrap(URL(string: input))), input)
        }
    }

    func testRedirectRejectsHTTPAndLookalikeHosts() throws {
        for input in [
            "http://wxmpurl.cn/a", "http://mp.weixin.qq.com/a", "https://wxmpurl.cn.evil.example/a",
            "https://notwxmpurl.cn/a", "https://evil.mp.weixin.qq.com/a", "https://mp.weixin.qq.com.evil.example/a",
            "https://weixin.qq.com/a", "https://user@mp.weixin.qq.com/a", "https://wxmpurl.cn:8443/a",
            "weixin://dl/business/?t=abc", "file:///tmp/test"
        ] {
            XCTAssertFalse(WeChatLinkFetcher.isAllowedRedirect(try XCTUnwrap(URL(string: input))), input)
        }
    }
}
