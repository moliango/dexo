import Foundation
import Network
import os.log

private let logger = Logger(subsystem: "com.eilgnaw.dexo", category: "DoHProtocol")

/// A URLProtocol that intercepts HTTPS requests and routes them through
/// DNS-over-HTTPS resolved IPs using NWConnection with correct TLS SNI.
/// Falls back to system DNS transparently on any connection failure.
final class DoHURLProtocol: URLProtocol, @unchecked Sendable {
    private var connection: NWConnection?
    private var fallbackSession: URLSession?
    private var fallbackTask: URLSessionDataTask?
    private var didFinish = false
    private var didFallback = false
    private let queue = DispatchQueue(label: "com.eilgnaw.dexo.doh-protocol")

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: "DoHHandled", in: request) == nil,
              AppSettings.shared.dohEnabled,
              request.url?.scheme == "https",
              let host = request.url?.host,
              !host.allSatisfy({ $0.isNumber || $0 == "." || $0 == ":" }) else {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Task {
            guard let ip = await DoHResolver.shared.resolve(host) else {
                self.fallbackToSystem()
                return
            }
            let port = UInt16(url.port ?? 443)
            logger.info("[DoHProtocol] connecting \(host) → \(ip):\(port)")
            self.connectAndSend(ip: ip, port: port, hostname: host)
        }
    }

    override func stopLoading() {
        didFinish = true
        connection?.cancel()
        connection = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        fallbackSession?.invalidateAndCancel()
        fallbackSession = nil
    }

    // MARK: - Fallback to system DNS

    private func fallbackToSystem() {
        guard !didFinish, !didFallback else { return }
        didFallback = true

        let host = request.url?.host ?? "?"
        logger.info("[DoHProtocol] falling back to system DNS for \(host)")

        connection?.cancel()
        connection = nil

        let mutable = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "DoHHandled", in: mutable)

        let session = URLSession(configuration: .ephemeral)
        self.fallbackSession = session

        let task = session.dataTask(with: mutable as URLRequest) { [weak self] data, response, error in
            guard let self, !self.didFinish else { return }
            if let error {
                logger.error("[DoHProtocol] fallback failed for \(host): \(error.localizedDescription)")
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response {
                logger.info("[DoHProtocol] fallback succeeded for \(host), bytes: \(data?.count ?? 0)")
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data, !data.isEmpty {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        self.fallbackTask = task
        task.resume()
    }

    // MARK: - NWConnection

    private func connectAndSend(ip: String, port: UInt16, hostname: String) {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, hostname)

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 10
        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(rawValue: port)!
        )

        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self, !self.didFinish else { return }
            switch state {
            case .ready:
                self.sendHTTPRequest(over: conn, hostname: hostname)
            case .waiting(let error):
                logger.warning("[DoHProtocol] connection waiting: \(error.localizedDescription), falling back")
                self.fallbackToSystem()
            case .failed(let error):
                logger.warning("[DoHProtocol] connection failed: \(error.localizedDescription), falling back")
                self.fallbackToSystem()
            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    private func sendHTTPRequest(over conn: NWConnection, hostname: String) {
        guard let url = request.url else { return }

        var path = url.path.isEmpty ? "/" : url.path
        if let query = url.query {
            path += "?\(query)"
        }

        let method = request.httpMethod ?? "GET"
        var headerString = "\(method) \(path) HTTP/1.1\r\n"
        headerString += "Host: \(hostname)\r\n"

        // Skip headers that we set ourselves or that cause compressed responses
        let skipHeaders: Set<String> = ["host", "accept-encoding", "connection"]
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers where !skipHeaders.contains(key.lowercased()) {
                headerString += "\(key): \(value)\r\n"
            }
        }
        // Force uncompressed response — we handle raw bytes, no automatic decompression
        headerString += "Accept-Encoding: identity\r\n"

        let body = request.httpBody ?? Data()
        if !body.isEmpty {
            headerString += "Content-Length: \(body.count)\r\n"
        }
        headerString += "Connection: close\r\n"
        headerString += "\r\n"

        var requestData = Data(headerString.utf8)
        requestData.append(body)

        conn.send(content: requestData, completion: .contentProcessed { [weak self] error in
            guard let self, !self.didFinish else { return }
            if let error {
                logger.warning("[DoHProtocol] send failed: \(error.localizedDescription), falling back")
                self.fallbackToSystem()
                return
            }
            self.receiveResponse(from: conn, hostname: hostname)
        })
    }

    // MARK: - Receive & Parse

    private func receiveResponse(from conn: NWConnection, hostname: String) {
        let context = ReceiveContext()
        receiveLoop(conn: conn, context: context, hostname: hostname)
    }

    private class ReceiveContext {
        var buffer = Data()
        var headersParsed = false
        var isChunked = false
        /// nil = unknown length (read until close), non-nil = bytes remaining
        var contentRemaining: Int?
        /// Buffer for chunked body (decoded after all chunks arrive)
        var chunkedBuffer = Data()
    }

    private func receiveLoop(conn: NWConnection, context: ReceiveContext, hostname: String) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self, !self.didFinish else { return }

            if let content, !content.isEmpty {
                if context.headersParsed {
                    if context.isChunked {
                        context.chunkedBuffer.append(content)
                    } else {
                        self.client?.urlProtocol(self, didLoad: content)
                        if let rem = context.contentRemaining {
                            context.contentRemaining = rem - content.count
                        }
                    }
                } else {
                    context.buffer.append(content)
                }
            }

            // Try to parse headers if not yet done
            if !context.headersParsed {
                if let range = context.buffer.range(of: Data("\r\n\r\n".utf8)) {
                    let headerData = context.buffer[context.buffer.startIndex..<range.lowerBound]
                    let bodyData = Data(context.buffer[range.upperBound...])

                    if let (statusCode, headers) = self.parseHeaders(headerData) {
                        let url = self.request.url!
                        let response = HTTPURLResponse(
                            url: URL(string: "https://\(hostname)\(url.path)\(url.query.map { "?\($0)" } ?? "")") ?? url,
                            statusCode: statusCode,
                            httpVersion: "HTTP/1.1",
                            headerFields: headers
                        )!
                        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

                        context.headersParsed = true
                        context.buffer = Data()

                        let te = headers["Transfer-Encoding"] ?? headers["transfer-encoding"] ?? ""
                        if te.lowercased().contains("chunked") {
                            context.isChunked = true
                            context.chunkedBuffer = bodyData
                        } else if let cl = headers["Content-Length"] ?? headers["content-length"],
                                  let contentLength = Int(cl) {
                            if !bodyData.isEmpty {
                                self.client?.urlProtocol(self, didLoad: bodyData)
                            }
                            context.contentRemaining = contentLength - bodyData.count
                        } else {
                            if !bodyData.isEmpty {
                                self.client?.urlProtocol(self, didLoad: bodyData)
                            }
                        }

                        logger.info("[DoHProtocol] response \(statusCode) for \(hostname), chunked: \(context.isChunked)")
                    }
                }
            }

            // Check completion
            if let error {
                if context.headersParsed {
                    if context.isChunked {
                        let decoded = Self.decodeChunked(context.chunkedBuffer)
                        if !decoded.isEmpty {
                            self.client?.urlProtocol(self, didLoad: decoded)
                        }
                    }
                    self.client?.urlProtocolDidFinishLoading(self)
                } else {
                    logger.warning("[DoHProtocol] receive error before headers: \(error.localizedDescription), falling back")
                    self.fallbackToSystem()
                }
                conn.cancel()
                return
            }

            if let rem = context.contentRemaining, context.headersParsed, rem <= 0 {
                self.client?.urlProtocolDidFinishLoading(self)
                conn.cancel()
                return
            }

            if isComplete {
                if context.headersParsed {
                    if context.isChunked {
                        let decoded = Self.decodeChunked(context.chunkedBuffer)
                        if !decoded.isEmpty {
                            self.client?.urlProtocol(self, didLoad: decoded)
                        }
                    }
                    self.client?.urlProtocolDidFinishLoading(self)
                } else {
                    self.fallbackToSystem()
                }
                conn.cancel()
                return
            }

            self.receiveLoop(conn: conn, context: context, hostname: hostname)
        }
    }

    // MARK: - Chunked Decoding

    private static func decodeChunked(_ data: Data) -> Data {
        var result = Data()
        var offset = data.startIndex
        let crlf = Data("\r\n".utf8)

        while offset < data.endIndex {
            guard let crlfRange = data[offset...].range(of: crlf) else { break }
            let sizeStr = String(data: data[offset..<crlfRange.lowerBound], encoding: .ascii)?
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: ";").first ?? ""
            guard let chunkSize = Int(sizeStr, radix: 16), chunkSize > 0 else { break }

            let dataStart = crlfRange.upperBound
            let dataEnd = data.index(dataStart, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            result.append(data[dataStart..<dataEnd])

            let nextOffset = data.index(dataEnd, offsetBy: 2, limitedBy: data.endIndex) ?? data.endIndex
            offset = nextOffset
        }

        return result
    }

    // MARK: - Header Parsing

    private func parseHeaders(_ data: Data) -> (statusCode: Int, headers: [String: String])? {
        guard let headerString = String(data: data, encoding: .utf8) else { return nil }
        let lines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { return nil }

        let parts = statusLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2, let statusCode = Int(parts[1]) else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        return (statusCode, headers)
    }
}
