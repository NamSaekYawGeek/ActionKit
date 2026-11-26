import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A fresh, memory-only session per request; never executes webpage JavaScript.
public struct WeChatLinkFetcher: Sendable {
    public init() {}

    public func fetchScheme(from input: String) async throws -> String {
        let url = try Self.validatedInput(input)
        let data = try await BoundedHTMLRequest().load(url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ActionKitError.unsupportedEncoding
        }
        try Task.checkCancellation()
        return try ActionKitProcessor.extractWeChatScheme(from: html)
    }

    static func validatedInput(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ActionKitError.emptyInput }
        guard !text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }) else {
            throw ActionKitError.invalidURL
        }
        _ = try ActionKitProcessor.decodeURLComponent(text)
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(),
              isShortLinkHost(host), components.user == nil, components.password == nil,
              components.port == nil || components.port == 443 || (scheme == "http" && components.port == 80) else {
            throw ActionKitError.invalidURL
        }
        // Upgrade shared HTTP links; never make a cleartext network request.
        components.scheme = "https"
        components.port = nil
        components.fragment = nil
        guard let url = components.url else { throw ActionKitError.invalidURL }
        return url
    }

    static func isShortLinkHost(_ host: String) -> Bool {
        host == "wxmpurl.cn" || host.hasSuffix(".wxmpurl.cn")
    }

    static func isAllowedRedirect(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == "https", let host = c.host?.lowercased(),
              c.user == nil, c.password == nil, c.port == nil || c.port == 443 else { return false }
        return isShortLinkHost(host) || host == "mp.weixin.qq.com"
    }
}

/// Delegate-based streaming keeps the 2 MiB limit effective before all bytes arrive.
/// Every mutable field is protected by `lock`; continuations resume exactly once.
final class BoundedHTMLRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var finished = false
    private var buffer = Data()
    private var redirects = 0
    private let maximumBytes = 2 * 1_024 * 1_024
    private let suppliedConfiguration: URLSessionConfiguration?

    /// Internal configuration injection enables deterministic URLProtocol tests.
    init(configuration: URLSessionConfiguration? = nil) {
        self.suppliedConfiguration = configuration
        super.init()
    }

    func load(_ url: URL) async throws -> Data {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if finished {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                let configuration = suppliedConfiguration ?? URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 15
                configuration.timeoutIntervalForResource = 30
                configuration.urlCache = nil
                configuration.httpCookieStorage = nil
                configuration.httpShouldSetCookies = false
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                var request = URLRequest(url: url)
                request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
                let task = session.dataTask(with: request)
                self.task = task
                lock.unlock()
                task.resume()
            }
        }, onCancel: {
            self.finish(.failure(CancellationError()))
        })
    }

    private func finish(_ result: Result<Data, Error>) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = self.continuation
        let session = self.session
        self.continuation = nil
        self.session = nil
        task = nil
        buffer.removeAll()
        lock.unlock()
        session?.invalidateAndCancel()
        continuation?.resume(with: result)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, WeChatLinkFetcher.isAllowedRedirect(url) else {
            completionHandler(nil)
            finish(.failure(ActionKitError.redirectNotAllowed))
            return
        }
        lock.lock()
        redirects += 1
        let tooMany = redirects > 5
        let alreadyFinished = finished
        lock.unlock()
        if tooMany || alreadyFinished {
            completionHandler(nil)
            if tooMany { finish(.failure(ActionKitError.tooManyRedirects)) }
        } else {
            completionHandler(request)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(ActionKitError.invalidHTML))
            return
        }
        guard (200...299).contains(http.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(ActionKitError.httpStatus(http.statusCode)))
            return
        }
        if response.expectedContentLength > Int64(maximumBytes) {
            completionHandler(.cancel)
            finish(.failure(ActionKitError.responseTooLarge))
            return
        }
        if let mime = response.mimeType?.lowercased(),
           !["text/html", "application/xhtml+xml", "text/plain"].contains(mime) {
            completionHandler(.cancel)
            finish(.failure(ActionKitError.invalidHTML))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        guard buffer.count + data.count <= maximumBytes else {
            lock.unlock()
            finish(.failure(ActionKitError.responseTooLarge))
            return
        }
        buffer.append(data)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as? URLError {
            let message: String
            switch error.code {
            case .timedOut: message = "请求超时，请检查网络后重试。"
            case .notConnectedToInternet, .networkConnectionLost: message = "网络不可用或连接已断开。"
            case .cancelled: finish(.failure(CancellationError())); return
            default: message = "网页请求失败（网络错误 \(error.errorCode)）。"
            }
            finish(.failure(ActionKitError.network(message)))
        } else if error != nil {
            finish(.failure(ActionKitError.network("网页请求失败，请稍后重试。")))
        } else {
            lock.lock()
            let result = buffer
            lock.unlock()
            finish(.success(result))
        }
    }
}
