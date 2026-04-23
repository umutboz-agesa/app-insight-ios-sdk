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
    private let maxReconnectAttempts = 5

    init(url: URL) {
        self.url = url
    }

    // MARK: - Connect / Disconnect

    func connect() {
        isIntentionalClose = false
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session?.webSocketTask(with: url)
        task?.resume()
        // listen() is called in didOpenWithProtocol — not here — to avoid
        // -1005 errors that occur when receive() is called before the handshake completes
    }

    func disconnect() {
        isIntentionalClose = true
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
            if let error { AILogger.error("WS send failed: \(error)") }
        }
    }

    // MARK: - Listen loop

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleRaw(message)
                self.listen()
            case .failure(let error):
                AILogger.error("WS receive error: \(error)")
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
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.task?.sendPing { error in
                if let error { AILogger.error("Ping failed: \(error)") }
            }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        stopPing()
        task = nil
        DispatchQueue.main.async { self.delegate?.webSocketDidDisconnect() }

        guard !isIntentionalClose, reconnectAttempts < maxReconnectAttempts else { return }

        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1
        AILogger.info("Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))")

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
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
        AILogger.info("WS connected")
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
        AILogger.info("WS closed: \(closeCode.rawValue)")
        handleDisconnect()
    }
}
