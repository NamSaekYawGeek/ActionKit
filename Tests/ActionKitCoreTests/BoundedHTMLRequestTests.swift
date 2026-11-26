import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ActionKitCore

/// URLProtocol keeps these checks independent of network availability and Tencent's pages.
final class BoundedHTMLRequestTests: XCTestCase {
    private let limit = 2 * 1_024 * 1_024

    func testSuccessfulResponseAccumulatesChunksInOrder() async throws {
        let result = try await loadStub { stub in
            stub.respond(status: 200, headers: ["Content-Type": "text/html; charset=utf-8"])
            stub.send(Data("<html>".utf8))
            stub.send(Data("中文</html>".utf8))
            stub.complete()
        }
        XCTAssertEqual(String(data: result, encoding: .utf8), "<html>中文</html>")
    }

    func testExactlyTwoMiBIsAccepted() async throws {
        let payload = Data(repeating: 65, count: limit)
        let result = try await loadStub { stub in
            stub.respond(status: 200, headers: ["Content-Type": "text/html", "Content-Length": String(payload.count)])
            stub.send(payload)
            stub.complete()
        }
        XCTAssertEqual(result, payload)
    }

    func testUnknownLengthResponseIsRejectedAsSoonAsItExceedsLimit() async {
        let half = Data(repeating: 65, count: limit / 2)
        do {
            _ = try await loadStub { stub in
                // Deliberately omit Content-Length: the streaming limit must still apply.
                stub.respond(status: 200, headers: ["Content-Type": "text/html"])
                stub.send(half)
                stub.send(half)
                stub.send(Data([66]))
                stub.complete()
            }
            XCTFail("An oversized streamed response must fail")
        } catch ActionKitError.responseTooLarge {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOversizedDeclaredLengthIsRejectedWithoutReceivingBody() async {
        do {
            _ = try await loadStub { stub in
                stub.respond(status: 200, headers: ["Content-Type": "text/html", "Content-Length": String(self.limit + 1)])
                // No body/completion: rejecting the response must resume the continuation.
            }
            XCTFail("An oversized declared length must fail")
        } catch ActionKitError.responseTooLarge {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHTTPFailurePreservesStatusCode() async {
        do {
            _ = try await loadStub { stub in
                stub.respond(status: 429, headers: ["Content-Type": "text/html"])
            }
            XCTFail("HTTP failure must not return a successful body")
        } catch ActionKitError.httpStatus(let status) {
            XCTAssertEqual(status, 429)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNonHTMLResponseIsRejected() async {
        do {
            _ = try await loadStub { stub in
                stub.respond(status: 200, headers: ["Content-Type": "image/png"])
            }
            XCTFail("Binary response must fail before reading a body")
        } catch ActionKitError.invalidHTML {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransportFailureBecomesLocalizedNetworkError() async {
        do {
            _ = try await loadStub { stub in
                stub.client?.urlProtocol(stub, didFailWithError: URLError(.timedOut))
            }
            XCTFail("Transport failure must propagate")
        } catch ActionKitError.network(let message) {
            XCTAssertTrue(message.contains("超时"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationStopsRequestAndThrowsCancellationError() async {
        let started = expectation(description: "Stub request started")
        let stopped = expectation(description: "Underlying request stopped")
        let url = StubHTMLURLProtocol.register(handler: { _ in
            started.fulfill()
            // Keep the request pending until cancellation.
        }, onStop: { stopped.fulfill() })
        defer { StubHTMLURLProtocol.unregister(url) }
        let loader = BoundedHTMLRequest(configuration: stubConfiguration())
        let operation = Task { try await loader.load(url) }
        await fulfillment(of: [started], timeout: 5)
        operation.cancel()
        do {
            _ = try await operation.value
            XCTFail("Cancelled task must not return success")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        await fulfillment(of: [stopped], timeout: 5)
    }

    func testAlreadyCancelledTaskDoesNotHang() async {
        let url = StubHTMLURLProtocol.register(handler: { _ in })
        defer { StubHTMLURLProtocol.unregister(url) }
        let loader = BoundedHTMLRequest(configuration: stubConfiguration())
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await loader.load(url)
        }
        do {
            _ = try await operation.value
            XCTFail("Already cancelled task must fail")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func stubConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubHTMLURLProtocol.self]
        return configuration
    }

    private func loadStub(handler: @escaping (StubHTMLURLProtocol) -> Void) async throws -> Data {
        let url = StubHTMLURLProtocol.register(handler: handler)
        defer { StubHTMLURLProtocol.unregister(url) }
        return try await BoundedHTMLRequest(configuration: stubConfiguration()).load(url)
    }
}

/// Each test owns a unique URL, so parallel tests cannot overwrite each other's stub.
private final class StubHTMLURLProtocol: URLProtocol {
    private struct Registration {
        let handler: (StubHTMLURLProtocol) -> Void
        let onStop: (() -> Void)?
    }

    private static let registryLock = NSLock()
    private static var registry: [URL: Registration] = [:]

    static func register(handler: @escaping (StubHTMLURLProtocol) -> Void, onStop: (() -> Void)? = nil) -> URL {
        let url = URL(string: "https://wxmpurl.cn/unit-test/\(UUID().uuidString)")!
        registryLock.lock()
        registry[url] = Registration(handler: handler, onStop: onStop)
        registryLock.unlock()
        return url
    }

    static func unregister(_ url: URL) {
        registryLock.lock()
        registry.removeValue(forKey: url)
        registryLock.unlock()
    }

    private static func registration(for url: URL?) -> Registration? {
        guard let url else { return nil }
        registryLock.lock()
        defer { registryLock.unlock() }
        return registry[url]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        registration(for: request.url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let registration = Self.registration(for: request.url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        registration.handler(self)
    }

    override func stopLoading() {
        Self.registration(for: request.url)?.onStop?()
    }

    func respond(status: Int, headers: [String: String]) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    func send(_ data: Data) { client?.urlProtocol(self, didLoad: data) }
    func complete() { client?.urlProtocolDidFinishLoading(self) }
}
