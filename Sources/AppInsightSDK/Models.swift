import Foundation

// MARK: - Public types

public struct InsightMessage {
    public let id: String
    public let title: String
    public let body: String?
    public let data: [String: Any]
    public let targetScreens: [String]
    public let display: InsightDisplay?
    public let action: InsightAction?
    /// Backend'den "opt-out'u görmezden gel, göster" talimatı
    public let force: Bool
}

public struct InsightDisplay {
    public let style: String       // "banner" | "modal" | "toast"
    public let durationMs: Int?
}

public struct InsightAction {
    public let type: String        // "deeplink" | "url" | "dismiss" | "redirect" | "return_to" | "set_value"
    public let url: String?
    /// Redirect aksiyonu için sayfa kodu (RedirectionPageModel raw value)
    public let page: Int?
    /// return_to aksiyonu için hedef ekran adı (VC class name)
    public let screen: String?
    /// set_value aksiyonu için SDK üye anahtarı (setInput ile register edilen key)
    public let memberKey: String?   // JSON key: "member_key"
    /// set_value aksiyonu için önerilen değer (input alanına pre-fill edilir)
    public let suggestedValue: String?  // JSON key: "suggested_value"
    /// Redirect aksiyonu için opsiyonel parametreler (ör: contractCode, campaignId)
    public let params: [String: Any]
}

// MARK: - Internal WS message types

enum OutboundMessage {
    case sdkInit(SdkInitPayload)
    case screenEvent(ScreenEventPayload)
    case insightOptout(InsightOptoutPayload)
    case insightAction(InsightActionPayload)
    case memberRegister(MemberRegisterPayload)

    func toJSON() -> Data? {
        switch self {
        case .sdkInit(let p):         return try? JSONSerialization.data(withJSONObject: p.dict)
        case .screenEvent(let p):     return try? JSONSerialization.data(withJSONObject: p.dict)
        case .insightOptout(let p):   return try? JSONSerialization.data(withJSONObject: p.dict)
        case .insightAction(let p):   return try? JSONSerialization.data(withJSONObject: p.dict)
        case .memberRegister(let p):  return try? JSONSerialization.data(withJSONObject: p.dict)
        }
    }
}

struct SdkInitPayload {
    let apiKey: String
    let deviceId: String
    let sessionId: String
    let platform: String
    let bundleId: String
    let appVersion: String
    let osVersion: String
    let model: String

    var dict: [String: Any] {
        [
            "type":       "sdk_init",
            "api_key":    apiKey,
            "session_id": sessionId,
            "bundle_id":  bundleId,
            "device": [
                "id":          deviceId,
                "platform":    platform,
                "app_version": appVersion,
                "os_version":  osVersion,
                "model":       model,
            ] as [String: Any],
        ]
    }
}

struct ScreenEventPayload {
    let apiKey: String
    let deviceId: String
    let sessionId: String
    let screen: String
    let event: String          // "appeared" | "disappeared"
    let ts: Int64
    let durationMs: Int?

    var dict: [String: Any] {
        var payload: [String: Any] = [
            "screen": screen,
            "event":  event,
            "ts":     ts,
            "props":  [:] as [String: Any],
        ]
        if let d = durationMs { payload["duration_ms"] = d }

        return [
            "type":       "screen_event",
            "api_key":    apiKey,
            "device_id":  deviceId,
            "session_id": sessionId,
            "payload":    payload,
        ]
    }
}

struct InsightOptoutPayload {
    let apiKey: String
    let deviceId: String
    let insightId: String

    var dict: [String: Any] {
        [
            "type":       "insight_optout",
            "api_key":    apiKey,
            "device_id":  deviceId,
            "insight_id": insightId,
        ]
    }
}

struct InsightActionPayload {
    let apiKey: String
    let deviceId: String
    let insightId: String
    // "auto_closed" | "user_closed" | "action_clicked"
    let action: String

    var dict: [String: Any] {
        [
            "type":       "insight_action",
            "api_key":    apiKey,
            "device_id":  deviceId,
            "insight_id": insightId,
            "action":     action,
        ]
    }
}

struct MemberRegisterPayload {
    let apiKey: String
    let deviceId: String
    let key: String
    let elementType: String
    let screen: String
    let platform: String

    var dict: [String: Any] {
        [
            "type":         "member_register",
            "api_key":      apiKey,
            "device_id":    deviceId,
            "key":          key,
            "element_type": elementType,
            "screen":       screen,
            "platform":     platform,
        ]
    }
}

// MARK: - Inbound message parsing

enum InboundMessage {
    case initOk(appId: String, sessionId: String)
    case initError(code: String, message: String)
    case configUpdate(config: [String: Any], screens: [[String: Any]])
    case insightPush(InsightMessage)
    case pendingInsights([InsightMessage])
    case forceClearOptout(insightIds: [String])
    case dataPush(event: String, data: [String: Any])
    case unknown
}

extension InboundMessage {
    static func parse(from data: Data) -> InboundMessage {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else { return .unknown }

        switch type {
        case "init_ok":
            let appId = json["app_id"] as? String ?? ""
            let sessionId = json["session_id"] as? String ?? ""
            return .initOk(appId: appId, sessionId: sessionId)

        case "init_error":
            let code = json["code"] as? String ?? "INTERNAL"
            let message = json["message"] as? String ?? ""
            return .initError(code: code, message: message)

        case "config_update":
            let config = json["config"] as? [String: Any] ?? [:]
            let screens = json["screens"] as? [[String: Any]] ?? []
            return .configUpdate(config: config, screens: screens)

        case "insight_push":
            return .insightPush(parseInsight(from: json))

        case "pending_insights":
            let list = json["insights"] as? [[String: Any]] ?? []
            return .pendingInsights(list.map { parseInsight(from: $0) })

        case "force_clear_optout":
            let ids = json["insight_ids"] as? [String] ?? []
            return .forceClearOptout(insightIds: ids)

        case "data_push":
            let event = json["event"] as? String ?? ""
            let data = json["data"] as? [String: Any] ?? [:]
            return .dataPush(event: event, data: data)

        default:
            return .unknown
        }
    }
}

private func parseInsight(from json: [String: Any]) -> InsightMessage {
    let display: InsightDisplay? = {
        guard let d = json["display"] as? [String: Any] else { return nil }
        return InsightDisplay(
            style: d["style"] as? String ?? "banner",
            durationMs: d["duration_ms"] as? Int
        )
    }()
    let action: InsightAction? = {
        guard let a = json["action"] as? [String: Any] else { return nil }
        return InsightAction(
            type:           a["type"] as? String ?? "dismiss",
            url:            a["url"] as? String,
            page:           a["page"] as? Int,
            screen:         a["screen"] as? String,
            memberKey:      a["member_key"] as? String,
            suggestedValue: a["suggested_value"] as? String,
            params:         a["params"] as? [String: Any] ?? [:]
        )
    }()
    return InsightMessage(
        id:           json["insight_id"] as? String ?? "",
        title:        json["title"] as? String ?? "",
        body:         json["body"] as? String,
        data:         json["data"] as? [String: Any] ?? [:],
        targetScreens: (json["target_screens"] as? [String])
                        ?? (json["target_screen"] as? String).map { [$0] }
                        ?? [],
        display:      display,
        action:       action,
        force:        json["force"] as? Bool ?? false
    )
}
