import Foundation
import UIKit

/// Ana giriş noktası. `AppInsight.shared` üzerinden erişilir.
public final class AppInsight {

    // MARK: - Singleton

    public static let shared = AppInsight()
    private init() {}

    // MARK: - Public callbacks

    /// Bir insight push alındığında çağrılır (main thread).
    public var onInsight: ((InsightMessage) -> Void)?

    /// Bir data push alındığında çağrılır (main thread).
    public var onDataPush: ((_ event: String, _ data: [String: Any]) -> Void)?

    // MARK: - Private state

    private var wsManager: WebSocketManager?
    private let tracker = ScreenTracker()
    private let lock = NSLock()

    private var apiKey: String = ""
    private var deviceId: String = ""
    private var sessionId: String = UUID().uuidString
    private var isInitialized = false
    private var pendingEvents: [OutboundMessage] = []
    private(set) var environment: AppInsightEnvironment = .local

    // MARK: - Initialize

    public func initialize(
        apiKey: String,
        deviceId: String,
        environment: AppInsightEnvironment = .local
    ) {
        self.apiKey      = apiKey
        self.deviceId    = deviceId
        self.environment = environment
        self.sessionId   = UUID().uuidString
        self.pendingEvents = []

        AILogger.info("AppInsight initializing — env: \(environment), session: \(sessionId)")

        let manager = WebSocketManager(url: environment.wsURL)
        manager.delegate = self
        wsManager = manager
        manager.connect()
    }

    /// Bağlantıyı kapatır ve tracking'i durdurur.
    public func disconnect() {
        wsManager?.disconnect()
        wsManager = nil
        isInitialized = false
        pendingEvents = []
        AILogger.info("AppInsight disconnected")
    }

    // MARK: - Screen tracking

    /// Ekran görünür olduğunda çağrılır.
    public func screenDidAppear(_ name: String) {
        let ts = tracker.appeared(name)
        enqueue(.screenEvent(ScreenEventPayload(
            apiKey:     apiKey,
            deviceId:   deviceId,
            sessionId:  sessionId,
            screen:     name,
            event:      "appeared",
            ts:         ts,
            durationMs: nil
        )))
    }

    /// Ekran kapandığında çağrılır.
    public func screenDidDisappear(_ name: String) {
        guard let (ts, durationMs) = tracker.disappeared(name) else { return }
        enqueue(.screenEvent(ScreenEventPayload(
            apiKey:     apiKey,
            deviceId:   deviceId,
            sessionId:  sessionId,
            screen:     name,
            event:      "disappeared",
            ts:         ts,
            durationMs: durationMs
        )))
    }

    // MARK: - Private helpers

    // Buffers the event until init_ok, then sends immediately after
    private func enqueue(_ message: OutboundMessage) {
        lock.lock()
        defer { lock.unlock() }
        if isInitialized {
            wsManager?.send(message)
        } else {
            pendingEvents.append(message)
        }
    }

    private func flushPending() {
        lock.lock()
        let events = pendingEvents
        pendingEvents = []
        lock.unlock()

        guard !events.isEmpty else { return }
        AILogger.info("Flushing \(events.count) buffered events")
        events.forEach { wsManager?.send($0) }
    }

    private func sendInit() {
        let bundleId   = Bundle.main.bundleIdentifier ?? ""
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let osVersion  = UIDevice.current.systemVersion
        let model      = Self.deviceModel()

        AILogger.info("sdk_init — bundle: \(bundleId), version: \(appVersion), os: \(osVersion), model: \(model)")

        wsManager?.send(.sdkInit(SdkInitPayload(
            apiKey:     apiKey,
            deviceId:   deviceId,
            sessionId:  sessionId,
            platform:   "ios",
            bundleId:   bundleId,
            appVersion: appVersion,
            osVersion:  osVersion,
            model:      model
        )))
    }

    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        return mirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
    }
}

// MARK: - WebSocketManagerDelegate

extension AppInsight: WebSocketManagerDelegate {

    func webSocketDidConnect() {
        AILogger.info("WS connected → sending sdk_init")
        sendInit()
    }

    func webSocketDidDisconnect() {
        isInitialized = false
    }

    func webSocketDidReceive(_ message: InboundMessage) {
        switch message {

        case .initOk(let appId, let sessionId):
            AILogger.info("init_ok — app: \(appId), session: \(sessionId)")
            isInitialized = true
            flushPending()

        case .initError(let code, let msg):
            AILogger.error("init_error [\(code)]: \(msg) — tracking disabled")
            isInitialized = false
            pendingEvents = []
            wsManager?.disconnect()
            wsManager = nil

        case .configUpdate(_, let screens):
            AILogger.info("config_update — \(screens.count) screens")

        case .insightPush(let insight):
            AILogger.info("insight_push: \(insight.title)")
            onInsight?(insight)

        case .dataPush(let event, let data):
            AILogger.info("data_push: \(event)")
            onDataPush?(event, data)

        case .unknown:
            break
        }
    }
}
