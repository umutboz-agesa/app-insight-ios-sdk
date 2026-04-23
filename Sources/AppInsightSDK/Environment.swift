import Foundation

/// Backend ortam tanımı.
///
/// ```swift
/// // Varsayılan — localhost geliştirme
/// AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id)
///
/// // Belirli bir ortam
/// AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id, environment: .prod)
///
/// // Özel URL
/// AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id, environment: .custom(URL(string: "wss://my.server.com/sdk")!))
/// ```
public enum AppInsightEnvironment {
    /// Yerel geliştirme — `ws://localhost:3001/sdk`
    case local
    /// Test ortamı — `wss://test-ws.appinsight.io/sdk`
    case test
    /// Ön-prodüksiyon — `wss://prep-ws.appinsight.io/sdk`
    case prep
    /// Prodüksiyon — `wss://ws.appinsight.io/sdk`
    case prod
    /// Özel WebSocket URL'si
    case custom(URL)

    public var wsURL: URL {
        switch self {
        case .local:         return URL(string: "ws://localhost:3001/sdk")!
        case .test:          return URL(string: "wss://test-ws.appinsight.io/sdk")!
        case .prep:          return URL(string: "wss://prep-ws.appinsight.io/sdk")!
        case .prod:          return URL(string: "wss://ws.appinsight.io/sdk")!
        case .custom(let u): return u
        }
    }

    /// `wss://` kullanan ortamlar TLS gerektirir.
    public var isTLS: Bool {
        wsURL.scheme == "wss"
    }
}
