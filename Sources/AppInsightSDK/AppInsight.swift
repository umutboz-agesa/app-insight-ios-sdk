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

    private var apiKey: String = ""
    private var deviceId: String = ""
    private var sessionId: String = UUID().uuidString
    private var isInitialized = false

    // MARK: - Initialize

    /// SDK'yı başlatır ve backend'e bağlanır.
    /// - Parameters:
    ///   - apiKey: Portal'den alınan API anahtarı.
    ///   - deviceId: Cihazın stabil kimliği. Önerilen: `UIDevice.current.identifierForVendor`.
    ///   - serverURL: WebSocket sunucu adresi. Default: `ws://localhost:3001/sdk`.
    public func initialize(
        apiKey: String,
        deviceId: String,
        serverURL: URL = URL(string: "ws://localhost:3001/sdk")!
    ) {
        self.apiKey   = apiKey
        self.deviceId = deviceId
        self.sessionId = UUID().uuidString

        let manager = WebSocketManager(url: serverURL)
        manager.delegate = self
        wsManager = manager
        manager.connect()

        AILogger.info("AppInsight initializing — session: \(sessionId)")
    }

    /// Bağlantıyı kapatır ve tracking'i durdurur.
    public func disconnect() {
        wsManager?.disconnect()
        wsManager = nil
        isInitialized = false
        AILogger.info("AppInsight disconnected")
    }

    // MARK: - Screen tracking

    /// Ekran görünür olduğunda çağrılır.
    public func screenDidAppear(_ name: String) {
        guard isInitialized else { return }
        let ts = tracker.appeared(name)
        send(.screenEvent(ScreenEventPayload(
            apiKey:    apiKey,
            deviceId:  deviceId,
            sessionId: sessionId,
            screen:    name,
            event:     "appeared",
            ts:        ts,
            durationMs: nil
        )))
    }

    /// Ekran kapandığında çağrılır.
    public func screenDidDisappear(_ name: String) {
        guard isInitialized else { return }
        guard let (ts, durationMs) = tracker.disappeared(name) else { return }
        send(.screenEvent(ScreenEventPayload(
            apiKey:    apiKey,
            deviceId:  deviceId,
            sessionId: sessionId,
            screen:    name,
            event:     "disappeared",
            ts:        ts,
            durationMs: durationMs
        )))
    }

    // MARK: - Helpers

    private func send(_ message: OutboundMessage) {
        wsManager?.send(message)
    }

    private func sendInit() {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let osVersion = UIDevice.current.systemVersion
        let model = Self.deviceModel()

        send(.sdkInit(SdkInitPayload(
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
        let identifier = mirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - WebSocketManagerDelegate

extension AppInsight: WebSocketManagerDelegate {

    func webSocketDidConnect() {
        AILogger.info("WS connected — sending sdk_init")
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

        case .initError(let code, let msg):
            AILogger.error("init_error [\(code)]: \(msg) — tracking disabled")
            isInitialized = false
            wsManager?.disconnect()
            wsManager = nil

        case .configUpdate(let config, let screens):
            AILogger.info("config_update — \(screens.count) screens")
            _ = config   // ileride kullanılabilir

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
