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

#### Option A — `InsightBaseViewController` (recommended, zero config)

Inherit from `InsightBaseViewController`. Screen name is automatically derived from the class name by stripping the `ViewController` / `Controller` suffix.

```swift
// HomeViewController → "Home"
class HomeViewController: InsightBaseViewController { }

// CheckoutViewController → "Checkout"
class CheckoutViewController: InsightBaseViewController { }

// Override to use a custom name:
class UserProfileViewController: InsightBaseViewController {
    override var screenName: String { "Profile" }
}
```

No `viewDidAppear` / `viewDidDisappear` overrides needed.

---

#### Option B — `screenDidAppear(for:)` (without base class)

Use this when you can't change the inheritance chain. The `screenName` property on `UIViewController` derives the name automatically.

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

// Or access the derived name directly:
// self.screenName  →  "Home"
```

---

#### Option C — Manual name (explicit)

```swift
AppInsight.shared.screenDidAppear("CustomScreenName")
AppInsight.shared.screenDidDisappear("CustomScreenName")
```

---

**SwiftUI:**

SwiftUI'da her ekran ayrı bir `UIViewController` değildir — hepsi tek bir
`UIHostingController` içinde render edilir. Bu yüzden UIKit'teki
"sınıf adından otomatik türet" yaklaşımının doğrudan karşılığı yoktur;
ekran adı tip üzerinden verilir.

---

#### Option A — `InsightBaseView` (önerilen)

`InsightBaseViewController`'ın SwiftUI karşılığı. Ekran başına yapılacak tek iş
`View` yerine bu protokole conform etmek ve `body`'yi `screenBody` olarak
adlandırmak. Tracking, ekran adı ve arka plan davranışı hazır gelir.

```swift
struct HomeView: InsightBaseView {
    var screenBody: some View {
        VStack { Text("Home") }
    }
}
// → ekran adı "HomeView"
```

Adı özelleştirmek istersen (UIKit'teki `override var screenName` gibi):

```swift
struct HomeView: InsightBaseView {
    var screenName: String { "Ana Sayfa" }
    var screenBody: some View { ... }
}
```

**Uygulama tarafında kendi base'ini tanımlamak** — UIKit projelerindeki
`BaseViewController` kalıbının birebir karşılığı. Ara protokol tanımlarsan
ekranların SDK'yı hiç bilmez, sadece kendi base'ine conform olur:

```swift
// Uygulamada bir kez:
protocol BaseView: InsightBaseView {}

// Her ekran:
struct HomeView: BaseView {
    var screenBody: some View { ... }
}
```

Ortak davranış (tema, arka plan, safe area, ortak toolbar) eklemek istersen
`BaseView` extension'ında `screenBody`'yi sarmalayabilirsin.

---

#### Option B — `.trackScreen(_:)` modifier

Protokole geçmek istemediğin tek tük ekranlar için:

```swift
struct HomeView: View {
    var body: some View {
        Text("Home")
            .trackScreen("Home")
    }
}
```

> `InsightBaseView` de arka planda bunu kullanır — davranış aynıdır.

---

**Ekran adı kuralı:** verdiğin ad, portaldeki funnel step'inin `screen` alanıyla
birebir aynı olmalıdır.

**Arka plan davranışı:** SwiftUI uygulama arka plana alınırken `onDisappear`
çağırmaz. SDK bunu `scenePhase` üzerinden ele alır: arka plana geçişte
`disappeared`, öne dönüşte `appeared` gönderilir. `.inactive` (bildirim merkezi,
sistem alert'i) geçici kabul edilip yok sayılır.

**Bilinen sınırlar:**

- `TabView` — SwiftUI ekranda olmayan tab'ları önceden render edebilir; bu
  durumda görünmeyen tab için `appeared` düşebilir.
- `.sheet` / `.fullScreenCover` — altta kalan ekran `onDisappear` almaz, iki
  ekran aynı anda aktif görünür. Dwell süreleri buna göre okunmalıdır.

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
| `screenDidAppear(_ name:)` | Reports screen appearance with explicit name |
| `screenDidAppear(for:)` | Reports screen appearance, derives name from controller |
| `screenDidDisappear(_ name:)` | Reports screen disappearance and duration |
| `screenDidDisappear(for:)` | Reports screen disappearance, derives name from controller |
| `disconnect()` | Closes connection and stops tracking |
| `onInsight` | Callback fired on `insight_push` (main thread) |
| `onDataPush` | Callback fired on `data_push` (main thread) |
| `environment` | Currently active environment (read-only after init) |

### `InsightBaseViewController`

| Member | Description |
|---|---|
| `var screenName: String` | Auto-derived from class name — override to customize |

### `UIViewController` extension

| Member | Description |
|---|---|
| `var screenName: String` | Raw class name — no suffix stripping (since v1.1.4) |

### `InsightBaseView` (SwiftUI)

| Member | Description |
|---|---|
| `var screenName: String` | Auto-derived from the struct type name — override to customize |
| `var screenBody: some View` | Screen content — written instead of `body` |

### `View` extension (SwiftUI)

| Member | Description |
|---|---|
| `.trackScreen(_ name:)` | Tracks appear/disappear, incl. background transitions via `scenePhase` |

### `InsightMessage`

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique insight identifier |
| `title` | `String` | Insight title |
| `body` | `String?` | Insight body text |
| `data` | `[String: Any]` | Custom key-value payload |
| `targetScreens` | `[String]` | Screens the insight targets |
| `display` | `InsightDisplay?` | Style (`banner`, `modal`, `toast`) and duration |
| `action` | `InsightAction?` | Action type (`deeplink`, `url`, `dismiss`) and URL |

---

## Security

Bundle ID is automatically read from `Bundle.main.bundleIdentifier` at connection time — you do not need to provide it. The backend validates it against the registered app, so spoofing requires a matching provisioning profile.

---

## License

MIT
