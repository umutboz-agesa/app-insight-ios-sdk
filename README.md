# AppInsight iOS SDK

Real-time insight delivery and screen tracking SDK for iOS apps. Zero dependencies, Swift 5.7+, iOS 15+.

---

## Requirements

- iOS 15+
- Swift 5.7+
- Xcode 14+

---

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies**

```
https://github.com/umutboz-agesa/app-insight-ios-sdk
```

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/umutboz-agesa/app-insight-ios-sdk", from: "1.0.0")
]
```

---

## Quick Start

### 1. Initialize the SDK

Call `initialize` once at app launch — typically in `AppDelegate` or the `@main` App struct.

```swift
import AppInsightSDK

@main
struct MyApp: App {
    init() {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        AppInsight.shared.initialize(
            apiKey: "ak_your_api_key",
            deviceId: deviceId
        )
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### 2. Track Screens

Three options — from zero-config to fully manual.

---

#### Option A — `AIBaseViewController` (recommended, zero config)

Inherit from `AIBaseViewController`. Screen name is automatically derived from the class name by stripping the `ViewController` / `Controller` suffix.

```swift
// HomeViewController → "Home"
class HomeViewController: AIBaseViewController { }

// CheckoutViewController → "Checkout"
class CheckoutViewController: AIBaseViewController { }

// Override to use a custom name:
class UserProfileViewController: AIBaseViewController {
    override var aiScreenName: String { "Profile" }
}
```

No `viewDidAppear` / `viewDidDisappear` overrides needed.

---

#### Option B — `screenDidAppear(for:)` (without base class)

Use this when you can't change the inheritance chain.

```swift
class HomeViewController: SomeOtherBaseViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppInsight.shared.screenDidAppear(for: self)   // → "Home"
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AppInsight.shared.screenDidDisappear(for: self)
    }
}
```

---

#### Option C — Manual name (explicit)

```swift
AppInsight.shared.screenDidAppear("CustomScreenName")
AppInsight.shared.screenDidDisappear("CustomScreenName")
```

---

**SwiftUI:**

```swift
struct HomeView: View {
    var body: some View {
        Text("Home")
            .trackScreen("Home")
    }
}
```

### 3. Handle Insights

Set `onInsight` to receive real-time messages pushed from the portal when a funnel completes.

```swift
AppInsight.shared.onInsight = { insight in
    print("Insight received: \(insight.title)")

    switch insight.display?.style {
    case "banner":
        showBanner(title: insight.title, body: insight.body ?? "")
    case "modal":
        showModal(insight: insight)
    default:
        break
    }

    // Handle action
    if insight.action?.type == "deeplink", let url = insight.action?.url {
        if let deeplink = URL(string: url) {
            UIApplication.shared.open(deeplink)
        }
    }

    // Custom data attached in the portal
    if let promoCode = insight.data["code"] as? String {
        applyPromoCode(promoCode)
    }
}
```

### 4. Handle Data Pushes

`onDataPush` delivers arbitrary key-value payloads defined in the portal.

```swift
AppInsight.shared.onDataPush = { event, data in
    switch event {
    case "promo_banner":
        let imageUrl = data["image"] as? String ?? ""
        showPromoBanner(imageUrl: imageUrl)
    case "config_update":
        updateRemoteConfig(data)
    default:
        break
    }
}
```

---

## Environments

Use the `environment` parameter to point the SDK at different backends.

```swift
// Local development (default) — ws://localhost:3001/sdk
AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id)

// Test environment
AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id, environment: .test)

// Pre-production
AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id, environment: .prep)

// Production
AppInsight.shared.initialize(apiKey: "ak_...", deviceId: id, environment: .prod)

// Custom URL
AppInsight.shared.initialize(
    apiKey: "ak_...",
    deviceId: id,
    environment: .custom(URL(string: "wss://my.server.com/sdk")!)
)
```

| Case | URL |
|------|-----|
| `.local` | `ws://localhost:3001/sdk` |
| `.test` | `wss://test-ws.appinsight.io/sdk` |
| `.prep` | `wss://prep-ws.appinsight.io/sdk` |
| `.prod` | `wss://ws.appinsight.io/sdk` |
| `.custom(url)` | Your URL |

---

## Complete Example

```swift
import UIKit
import AppInsightSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        AppInsight.shared.initialize(
            apiKey: "ak_your_api_key",
            deviceId: deviceId,
            environment: .prod
        )

        AppInsight.shared.onInsight = { insight in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .appInsightReceived,
                    object: insight
                )
            }
        }

        AppInsight.shared.onDataPush = { event, data in
            print("Data push — event: \(event), data: \(data)")
        }

        return true
    }
}

extension Notification.Name {
    static let appInsightReceived = Notification.Name("appInsightReceived")
}
```

---

## API Reference

### `AppInsight`

| Method / Property | Description |
|---|---|
| `initialize(apiKey:deviceId:environment:)` | Starts SDK and opens WebSocket connection |
| `screenDidAppear(_ name:)` | Reports screen appearance |
| `screenDidDisappear(_ name:)` | Reports screen disappearance and duration |
| `disconnect()` | Closes connection and stops tracking |
| `onInsight` | Callback fired on `insight_push` (main thread) |
| `onDataPush` | Callback fired on `data_push` (main thread) |
| `environment` | Currently active environment (read-only after init) |

### `InsightMessage`

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique insight identifier |
| `title` | `String` | Insight title |
| `body` | `String?` | Insight body text |
| `data` | `[String: Any]` | Custom key-value payload |
| `targetScreen` | `String?` | Screen the insight targets |
| `display` | `InsightDisplay?` | Style (`banner`, `modal`, `toast`) and duration |
| `action` | `InsightAction?` | Action type (`deeplink`, `url`, `dismiss`) and URL |

---

## Security

Bundle ID is automatically read from `Bundle.main.bundleIdentifier` at connection time — you do not need to provide it. The backend validates it against the registered app, so spoofing requires a matching provisioning profile.

---

## License

MIT
