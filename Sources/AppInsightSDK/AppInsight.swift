import Foundation
import UIKit

/// Ana giriş noktası. `AppInsight.shared` üzerinden erişilir.
public final class AppInsight {

    // MARK: - Singleton

    public static let shared = AppInsight()
    private init() {}

    // MARK: - Public API

    /// Insight UI sunucusu. Default: `DefaultInsightPresenter` (UIKit banner/modal/toast).
    /// SwiftUI için: `AppInsight.shared.presenter = InsightStore.shared`
    public var presenter: InsightPresenting = DefaultInsightPresenter()

    /// Kullanıcı insight aksiyonuna tıkladığında çağrılır (deeplink, url routing).
    public var onInsightAction: ((InsightMessage) -> Void)?

    /// Bir data push alındığında çağrılır (main thread).
    public var onDataPush: ((_ event: String, _ data: [String: Any]) -> Void)?

    /// true yapınca tüm WS ve banner adımları konsola yazılır.
    public var isDebug: Bool = false {
        didSet { AppInsightLogger.isDebug = isDebug }
    }

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

    // Screen guard + dwell (main thread only)
    private var currentScreen: String? = nil
    private var dwellTimers: [String: [DispatchWorkItem]] = [:]

    // Insights waiting for the right screen (main thread only)
    private var cachedInsights: [InsightMessage] = []

    /// SDK'nın dwell event göndereceği süreler (ms). Default: 3s, 10s, 30s, 60s.
    /// Örn: `AppInsight.shared.dwellThresholds = [5_000, 15_000]`
    public var dwellThresholds: [Int] = [3_000, 10_000, 30_000, 60_000]

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

        AppInsightLogger.info("AppInsight initializing — env: \(environment), session: \(sessionId), debug: \(isDebug)")

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
        AppInsightLogger.info("AppInsight disconnected")
    }

    // MARK: - Opt-out (permanent dismiss)

    /// Cihazda bu insight'ı kalıcı olarak gizler ve sunucuya bildirir.
    /// `InsightBannerView` / `InsightModalView` içinden otomatik çağrılır.
    public func permanentlyDismiss(insightId: String) {
        UserDefaults.standard.set(true, forKey: "insight_optout_\(insightId)")
        AppInsightLogger.info("insight optout (local) — \(insightId)")
        enqueue(.insightOptout(InsightOptoutPayload(
            apiKey:    apiKey,
            deviceId:  deviceId,
            insightId: insightId
        )))
    }

    /// Kullanıcı aksiyonunu sunucuya bildirir (auto_closed, user_closed, action_clicked).
    func recordAction(insightId: String, action: String) {
        AppInsightLogger.info("insight_action — \(action): \(insightId)")
        enqueue(.insightAction(InsightActionPayload(
            apiKey:    apiKey,
            deviceId:  deviceId,
            insightId: insightId,
            action:    action
        )))
    }

    func isOptedOut(insightId: String) -> Bool {
        UserDefaults.standard.bool(forKey: "insight_optout_\(insightId)")
    }

    // MARK: - Screen tracking

    /// Ekran görünür olduğunda çağrılır. (Main thread)
    public func screenDidAppear(_ name: String) {
        currentScreen = name
        showCachedInsights(for: name)
        scheduleDwellTimers(for: name)
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

    /// Ekran kapandığında çağrılır. (Main thread)
    public func screenDidDisappear(_ name: String) {
        cancelDwellTimers(for: name)
        if currentScreen == name { currentScreen = nil }
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

    // MARK: - Dwell timers

    private func scheduleDwellTimers(for screen: String) {
        cancelDwellTimers(for: screen)
        let items: [DispatchWorkItem] = dwellThresholds.map { ms in
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.currentScreen == screen else { return }
                self.sendDwellEvent(screen: screen, durationMs: ms)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms), execute: item)
            return item
        }
        dwellTimers[screen] = items
    }

    private func cancelDwellTimers(for screen: String) {
        dwellTimers[screen]?.forEach { $0.cancel() }
        dwellTimers.removeValue(forKey: screen)
    }

    private func sendDwellEvent(screen: String, durationMs: Int) {
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        AppInsightLogger.info("dwell — \(screen), \(durationMs / 1000)s")
        enqueue(.screenEvent(ScreenEventPayload(
            apiKey:     apiKey,
            deviceId:   deviceId,
            sessionId:  sessionId,
            screen:     screen,
            event:      "dwell",
            ts:         ts,
            durationMs: durationMs
        )))
    }

    // Shows all cached insights whose targetScreen matches the given screen (or have no targetScreen).
    // Must be called on main thread.
    private func showCachedInsights(for screen: String) {
        let matches = cachedInsights.filter { $0.targetScreen == nil || $0.targetScreen == screen }
        guard !matches.isEmpty else { return }
        cachedInsights.removeAll { $0.targetScreen == nil || $0.targetScreen == screen }
        for insight in matches {
            guard !isOptedOut(insightId: insight.id) else { continue }
            AppInsightLogger.info("Showing cached insight \(insight.id) — screen: '\(screen)'")
            presenter.present(insight, onAction: onInsightAction)
        }
    }

    private func flushPending() {
        lock.lock()
        let events = pendingEvents
        pendingEvents = []
        lock.unlock()

        guard !events.isEmpty else { return }
        AppInsightLogger.info("Flushing \(events.count) buffered events")
        events.forEach { wsManager?.send($0) }
    }

    private func sendInit() {
        let bundleId   = Bundle.main.bundleIdentifier ?? ""
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let osVersion  = UIDevice.current.systemVersion
        let model      = Self.deviceModel()

        AppInsightLogger.info("sdk_init — bundle: \(bundleId), version: \(appVersion), os: \(osVersion), model: \(model)")

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
        AppInsightLogger.info("WS connected → sending sdk_init")
        sendInit()
    }

    func webSocketDidDisconnect() {
        isInitialized = false
    }

    func webSocketDidReceive(_ message: InboundMessage) {
        switch message {

        case .initOk(let appId, let sessionId):
            AppInsightLogger.info("init_ok — app: \(appId), session: \(sessionId)")
            isInitialized = true
            flushPending()

        case .initError(let code, let msg):
            AppInsightLogger.error("init_error [\(code)]: \(msg) — tracking disabled")
            isInitialized = false
            pendingEvents = []
            wsManager?.disconnect()
            wsManager = nil

        case .configUpdate(_, let screens):
            AppInsightLogger.info("config_update — \(screens.count) screens")

        case .pendingInsights(let list):
            AppInsightLogger.info("pending_insights received — count: \(list.count)")
            DispatchQueue.main.async {
                for insight in list {
                    guard !self.isOptedOut(insightId: insight.id) else { continue }
                    if let target = insight.targetScreen, target != self.currentScreen {
                        AppInsightLogger.info("pending insight CACHED — waiting for '\(target)' (current: '\(self.currentScreen ?? "nil")')")
                        self.cachedInsights.append(insight)
                    } else {
                        AppInsightLogger.info("pending insight → showing immediately (no targetScreen or already on screen)")
                        self.presenter.present(insight, onAction: self.onInsightAction)
                    }
                }
            }

        case .insightPush(let insight):
            AppInsightLogger.info("insight_push RECEIVED — id: \(insight.id), title: \(insight.title)")
            AppInsightLogger.debug("insight_push detail — targetScreen: \(insight.targetScreen ?? "none"), display: \(insight.display?.style ?? "banner"), duration: \(insight.display?.durationMs.map { "\($0)ms" } ?? "nil")")
            DispatchQueue.main.async {
                AppInsightLogger.debug("insight_push on main thread — currentScreen: \(self.currentScreen ?? "nil")")
                if self.isOptedOut(insightId: insight.id) {
                    AppInsightLogger.info("insight_push DISCARDED — opted out: \(insight.id)")
                    return
                }
                if let target = insight.targetScreen, target != self.currentScreen {
                    AppInsightLogger.info("insight_push CACHED — waiting for '\(target)' (current: '\(self.currentScreen ?? "nil")')")
                    self.cachedInsights.append(insight)
                    return
                }
                AppInsightLogger.info("insight_push → calling presenter.present()")
                self.presenter.present(insight, onAction: self.onInsightAction)
            }

        case .dataPush(let event, let data):
            AppInsightLogger.info("data_push: \(event)")
            onDataPush?(event, data)

        case .unknown:
            break
        }
    }
}
