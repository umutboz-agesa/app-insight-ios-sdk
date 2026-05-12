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

    /// `redirect` tipli insight aksiyonları için delegate.
    /// Set edilirse banner/modal tıklandığında `appInsight(didRequestRedirectionTo:params:)` çağrılır.
    public weak var redirectionDelegate: AppInsightRedirectionDelegate?

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

    // All currently visible screens (main thread only).
    // Tracked as a set so overlapping child VCs don't evict the parent.
    private var activeScreens: Set<String> = []
    private var dwellTimers: [String: [DispatchWorkItem]] = [:]

    // Insights waiting for the right screen (main thread only)
    private var cachedInsights: [InsightMessage] = []

    // key → (UITextField weak ref, screen name) — main thread only
    private var registeredInputs: [String: InputEntry] = [:]

    /// SDK'nın dwell event göndereceği süreler (ms). Default: 3s, 10s, 30s, 60s.
    /// Örn: `AppInsight.shared.dwellThresholds = [5_000, 15_000]`
    public var dwellThresholds: [Int] = [3_000, 10_000, 30_000, 60_000]

    /// UI element kayıt namespace'i.
    /// `AppInsight.shared.member.setInput(field, key: "key")`
    public lazy var member: AppInsightMemberRegistry = AppInsightMemberRegistry(sdk: self)

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
    func recordAction(insightId: String, action: String, skipOptOut: Bool = false) {
        AppInsightLogger.info("insight_action — \(action): \(insightId)")
        if action == "action_clicked" && !skipOptOut {
            UserDefaults.standard.set(true, forKey: "insight_optout_\(insightId)")
            DispatchQueue.main.async { self.cachedInsights.removeAll { $0.id == insightId } }
        }
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
        activeScreens.insert(name)
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
        activeScreens.remove(name)
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
                guard let self, self.activeScreens.contains(screen) else { return }
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

    // Shows all cached insights whose targetScreens contains the given screen (or targetScreens is empty).
    // Must be called on main thread.
    private func showCachedInsights(for screen: String) {
        let matches = cachedInsights.filter { $0.targetScreens.isEmpty || $0.targetScreens.contains(screen) }
        guard !matches.isEmpty else { return }
        cachedInsights.removeAll { $0.targetScreens.isEmpty || $0.targetScreens.contains(screen) }
        for insight in matches {
            if insight.force {
                UserDefaults.standard.removeObject(forKey: "insight_optout_\(insight.id)")
            }
            guard !isOptedOut(insightId: insight.id) else { continue }
            AppInsightLogger.info("Showing cached insight \(insight.id) — screen: '\(screen)'")
            presenter.present(insight, onAction: actionHandler(for: insight))
        }
    }

    /// action.type'a göre doğru handler'ı döner.
    /// - "redirect" → redirectionDelegate'e yönlendir (hangi ekranda olunursa olunsun)
    /// - diğer      → onInsightAction closure'ına bırak
    private func actionHandler(for insight: InsightMessage) -> ((InsightMessage) -> Void)? {
        guard let action = insight.action else { return onInsightAction }

        switch action.type {
        case "url":
            return { msg in
                guard let urlStr = msg.action?.url, let url = URL(string: urlStr) else {
                    AppInsightLogger.error("url action: missing or invalid url — insight: \(msg.id)")
                    return
                }
                AppInsightLogger.info("url action → opening: \(urlStr)")
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            }
        case "redirect":
            return { [weak self] msg in
                guard let self else { return }
                guard let page = msg.action?.page else {
                    AppInsightLogger.error("redirect action: pageCode missing — insight: \(msg.id)")
                    return
                }
                guard let delegate = self.redirectionDelegate else {
                    AppInsightLogger.error("redirect action: redirectionDelegate is nil — set AppInsight.shared.redirectionDelegate")
                    return
                }
                AppInsightLogger.info("redirect action → page: \(page), params: \(msg.action?.params ?? [:])")
                delegate.appInsight(didRequestRedirectionTo: page, params: msg.action?.params ?? [:])
            }
        case "return_to":
            return { msg in
                guard let screen = msg.action?.screen, !screen.isEmpty else {
                    AppInsightLogger.error("return_to action: screen missing — insight: \(msg.id)")
                    return
                }
                AppInsightLogger.info("return_to action → screen: \(screen)")
                DispatchQueue.main.async { Self.popToScreen(named: screen) }
            }
        case "set_value":
            return { [weak self] msg in
                guard let self else { return }
                guard let memberKey = msg.action?.memberKey, !memberKey.isEmpty else {
                    AppInsightLogger.error("set_value action: memberKey missing — insight: \(msg.id)")
                    return
                }
                let suggested = msg.action?.suggestedValue ?? ""
                AppInsightLogger.info("set_value action → key: \(memberKey), mode: \(suggested.isEmpty ? "input_sheet" : "direct_apply"), value: \(suggested)")
                DispatchQueue.main.async {
                    if !suggested.isEmpty {
                        // "Öneri Uygula" modu: portal değeri sabit, ekrana gidip direkt set et
                        self._applySetValueNavigating(key: memberKey, value: suggested)
                    } else {
                        // "Değer Gir" modu: kullanıcı değeri input sheet'te girer, sonra ekrana gidip set et
                        guard let window = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .flatMap({ $0.windows })
                            .first(where: { $0.isKeyWindow }) else { return }
                        InsightInputSheet.present(in: window, insight: msg, memberKey: memberKey, suggestedValue: "") { value in
                            self._applySetValueNavigating(key: memberKey, value: value)
                        }
                    }
                }
            }
        default:
            return onInsightAction
        }
    }

    // MARK: - Member internals (called by AppInsightMemberRegistry)

    func _registerInput(_ textField: UITextField, key: String, screen: String) {
        DispatchQueue.main.async { self.registeredInputs[key] = InputEntry(textField: textField, screen: screen) }
        AppInsightLogger.info("member_register — key: \(key), screen: \(screen)")
        enqueue(.memberRegister(MemberRegisterPayload(
            apiKey:      apiKey,
            deviceId:    deviceId,
            key:         key,
            elementType: "input",
            screen:      screen,
            platform:    "ios"
        )))
    }

    func _applySetValue(key: String, value: String) {
        guard let entry = registeredInputs[key], let field = entry.textField else {
            AppInsightLogger.error("set_value: '\(key)' için kayıtlı input bulunamadı veya serbest bırakıldı")
            return
        }
        field.text = value
        // UIControl hedeflerini tetikle (onChange listener'ları)
        field.sendActions(for: .editingChanged)
        // UITextFieldDelegate'i de bilgilendir — delegate bu noktada validasyon / hesaplama başlatabilir
        field.delegate?.textFieldDidEndEditing?(field)
        AppInsightLogger.info("set_value applied — key: \(key), value: \(value)")
    }

    /// Gerekirse önce ekrana pop eder, ardından değeri set eder. Main thread'den çağrılmalı.
    func _applySetValueNavigating(key: String, value: String) {
        let registeredScreen = registeredInputs[key]?.screen ?? ""
        let isOnScreen = registeredScreen.isEmpty || activeScreens.contains(registeredScreen)
        if isOnScreen {
            _applySetValue(key: key, value: value)
        } else {
            AppInsightLogger.info("set_value: '\(registeredScreen)' ekranına pop ediliyor → ardından set")
            Self.popToScreen(named: registeredScreen) { [weak self] in
                self?._applySetValue(key: key, value: value)
            }
        }
    }

    func _deriveScreenName(from view: UIView) -> String {
        var responder: UIResponder? = view.next
        while let r = responder {
            if let vc = r as? UIViewController { return String(describing: type(of: vc)) }
            responder = r.next
        }
        return activeScreens.first ?? "unknown"
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

    // Aktif navigation controller'ı bulup hedef ekrana pop eder.
    // UINavigationController → direkt; TabBar → seçili tab'ın nav'ı; Presented → presented içinde arar.
    private static func popToScreen(named screenName: String, completion: (() -> Void)? = nil) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            AppInsightLogger.error("return_to: keyWindow/rootVC bulunamadı")
            return
        }

        func findNav(_ vc: UIViewController) -> UINavigationController? {
            if let nav = vc as? UINavigationController { return nav }
            if let tab = vc as? UITabBarController,
               let selected = tab.selectedViewController { return findNav(selected) }
            if let presented = vc.presentedViewController { return findNav(presented) }
            return vc.children.compactMap { findNav($0) }.first
        }

        guard let nav = findNav(root) else {
            AppInsightLogger.error("return_to: UINavigationController bulunamadı")
            return
        }
        guard let target = nav.viewControllers.first(where: {
            String(describing: type(of: $0)) == screenName
        }) else {
            AppInsightLogger.error("return_to: '\(screenName)' stack'te yok — pop yapılamadı")
            return
        }
        AppInsightLogger.info("return_to: popToViewController → \(screenName)")
        nav.popToViewController(target, animated: true)
        if let coordinator = nav.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in completion?() }
        } else {
            completion?()
        }
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
                    if insight.force {
                        UserDefaults.standard.removeObject(forKey: "insight_optout_\(insight.id)")
                    }
                    guard !self.isOptedOut(insightId: insight.id) else { continue }
                    let targets = insight.targetScreens
                    if !targets.isEmpty, !targets.contains(where: { self.activeScreens.contains($0) }) {
                        if !self.cachedInsights.contains(where: { $0.id == insight.id }) {
                            AppInsightLogger.info("pending insight CACHED — waiting for \(targets) (active: \(self.activeScreens))")
                            self.cachedInsights.append(insight)
                        }
                    } else {
                        AppInsightLogger.info("pending insight → showing immediately (no targetScreens or already on screen)")
                        self.presenter.present(insight, onAction: self.actionHandler(for: insight))
                    }
                }
            }

        case .insightPush(let insight):
            AppInsightLogger.info("insight_push RECEIVED — id: \(insight.id), title: \(insight.title)")
            AppInsightLogger.debug("insight_push detail — targetScreens: \(insight.targetScreens), display: \(insight.display?.style ?? "banner"), duration: \(insight.display?.durationMs.map { "\($0)ms" } ?? "nil")")
            DispatchQueue.main.async {
                AppInsightLogger.info("insight_push on main thread — activeScreens: \(self.activeScreens)")
                if insight.force {
                    UserDefaults.standard.removeObject(forKey: "insight_optout_\(insight.id)")
                }
                if self.isOptedOut(insightId: insight.id) {
                    AppInsightLogger.info("insight_push DISCARDED — opted out: \(insight.id)")
                    return
                }
                let targets = insight.targetScreens
                if !targets.isEmpty, !targets.contains(where: { self.activeScreens.contains($0) }) {
                    if !self.cachedInsights.contains(where: { $0.id == insight.id }) {
                        AppInsightLogger.info("insight_push CACHED — waiting for \(targets) (active: \(self.activeScreens))")
                        self.cachedInsights.append(insight)
                    } else {
                        AppInsightLogger.info("insight_push SKIPPED — already cached: \(insight.id)")
                    }
                    return
                }
                AppInsightLogger.info("insight_push → calling presenter.present()")
                self.presenter.present(insight, onAction: self.actionHandler(for: insight))
            }

        case .forceClearOptout(let insightIds):
            AppInsightLogger.info("force_clear_optout — \(insightIds.count) insight(s) cleared")
            for id in insightIds {
                UserDefaults.standard.removeObject(forKey: "insight_optout_\(id)")
            }
            // Also remove any cached insights for these IDs so they can be re-shown
            DispatchQueue.main.async {
                self.cachedInsights.removeAll { insightIds.contains($0.id) }
            }

        case .dataPush(let event, let data):
            AppInsightLogger.info("data_push: \(event)")
            onDataPush?(event, data)

        case .unknown:
            break
        }
    }
}

// MARK: - InputEntry (weak ref wrapper)

private struct InputEntry {
    weak var textField: UITextField?
    let screen: String
}
