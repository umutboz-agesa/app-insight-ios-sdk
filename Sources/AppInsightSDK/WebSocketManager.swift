import Foundation

protocol WebSocketManagerDelegate: AnyObject {
    func webSocketDidReceive(_ message: InboundMessage)
    func webSocketDidConnect()
    func webSocketDidDisconnect()
}

final class WebSocketManager: NSObject {

    weak var delegate: WebSocketManagerDelegate?

    private let url: URL
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?

    private var isIntentionalClose = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    init(url: URL) {
        self.url = url
    }

    // MARK: - Connect / Disconnect

    func connect() {
        AppInsightLogger.info("WS connecting to \(url)")
        isIntentionalClose = false
        teardown()  // her zaman temiz başla

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false  // sunucu kapalıysa beklemek yerine hemen hata ver
        // timeoutIntervalForRequest: server'dan veri bekleme süresi — WebSocket için 0 (sınırsız)
        // 10s gibi kısa değer: init_ok+config_update sonrası sunucu sessiz kalınca bağlantıyı keser
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        // Explicit HTTP/1.1 upgrade headers — prevents URLSessionWebSocketTask from
        // attempting HTTP/2 WebSocket (RFC 8441) which Node.js ws does not support
        config.httpAdditionalHeaders = [
            "Upgrade": "websocket",
            "Connection": "Upgrade",
        ]
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15  // sadece ilk handshake için
        task = session?.webSocketTask(with: request)
        task?.resume()
        // listen() is called in didOpenWithProtocol — not before — to avoid
        // -1005 errors that occur when receive() is called before handshake completes
    }

    func disconnect() {
        isIntentionalClose = true
        teardown()
    }

    private func teardown() {
        stopPing()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - Send

    func send(_ message: OutboundMessage) {
        guard let data = message.toJSON() else { return }
        let wsMessage = URLSessionWebSocketTask.Message.data(data)
        task?.send(wsMessage) { error in
            if let error { AppInsightLogger.error("WS send failed: \(error)") }
        }
    }

    // MARK: - Listen loop

    private func listen() {
        guard let currentSession = session else { return }
        task?.receive { [weak self] result in
            // Guard against stale sessions — teardown() during connect() invalidates the old
            // session asynchronously; its pending receive closure must not trigger reconnect.
            guard let self, currentSession === self.session else { return }
            switch result {
            case .success(let message):
                self.handleRaw(message)
                self.listen()
            case .failure(let error):
                AppInsightLogger.error("WS receive error: \(error)")
                self.handleDisconnect()
            }
        }
    }

    private func handleRaw(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .data(let d):   data = d
        case .string(let s): data = s.data(using: .utf8)
        @unknown default:    data = nil
        }
        guard let data else { return }
        let parsed = InboundMessage.parse(from: data)
        DispatchQueue.main.async {
            self.delegate?.webSocketDidReceive(parsed)
        }
    }

    // MARK: - Ping / Pong

    private func startPing() {
        DispatchQueue.main.async {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.task?.sendPing { error in
                    if let error { AppInsightLogger.error("Ping failed: \(error)") }
                }
            }
        }
    }

    private func stopPing() {
        DispatchQueue.main.async {
            self.pingTimer?.invalidate()
            self.pingTimer = nil
        }
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        teardown()
        DispatchQueue.main.async { self.delegate?.webSocketDidDisconnect() }

        guard !isIntentionalClose else { return }

        let delay: Double
        if reconnectAttempts < maxReconnectAttempts {
            delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
            reconnectAttempts += 1
        } else {
            // maxReconnectAttempts aşıldı, 60s'de bir passive retry
            delay = 60.0
        }

        AppInsightLogger.info("Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))")
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.isIntentionalClose else { return }
            self.connect()
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard session === self.session else {
            AppInsightLogger.debug("WS didOpen — ignoring stale session")
            return
        }
        AppInsightLogger.info("WS connected ✓")
        reconnectAttempts = 0
        startPing()
        listen()
        DispatchQueue.main.async { self.delegate?.webSocketDidConnect() }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        guard session === self.session else { return }
        AppInsightLogger.info("WS closed: \(closeCode.rawValue)")
        handleDisconnect()
    }

    // Called when connection attempt fails (backend down, timeout, etc.)
    // Guard against stale sessions: teardown() invalidates the old session asynchronously,
    // so its didCompleteWithError fires after the new session is active — must be ignored.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard session === self.session else {
            AppInsightLogger.debug("WS didComplete — ignoring stale session")
            return
        }
        if let error {
            AppInsightLogger.error("WS task failed: \(error.localizedDescription)")
            handleDisconnect()
        }
    }
}
