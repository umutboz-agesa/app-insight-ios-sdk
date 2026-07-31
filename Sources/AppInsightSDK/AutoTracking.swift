import UIKit
import SwiftUI

// MARK: - Screen name derivation

extension AppInsight {
    /// Sınıf adını olduğu gibi döndürür — herhangi bir suffix temizleme yapılmaz.
    public static func screenName(from type: AnyClass) -> String {
        String(describing: type)
    }
}

extension UIViewController {
    /// Sınıf adından otomatik türetilen ekran adı.
    public var screenName: String {
        AppInsight.screenName(from: type(of: self))
    }
}

// MARK: - Base view controller

/// Ekran geçişlerini otomatik izleyen base controller.
///
/// ```swift
/// // Yalnızca miras al — başka bir şey gerekmez.
/// class HomeViewController: InsightBaseViewController { ... }
///
/// // Adı özelleştirmek istersen override et:
/// class HomeViewController: InsightBaseViewController {
///     override var screenName: String { "Ana Sayfa" }
/// }
/// ```
open class InsightBaseViewController: UIViewController {

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppInsight.shared.screenDidAppear(screenName)
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AppInsight.shared.screenDidDisappear(screenName)
    }
}

// MARK: - AppInsight convenience overloads

extension AppInsight {

    /// Controller referansından otomatik isim türeterek ekran görünümünü izler.
    ///
    /// ```swift
    /// // InsightBaseViewController'dan türemek istemiyorsan:
    /// override func viewDidAppear(_ animated: Bool) {
    ///     super.viewDidAppear(animated)
    ///     AppInsight.shared.screenDidAppear(for: self)
    /// }
    /// ```
    public func screenDidAppear(for viewController: UIViewController) {
        screenDidAppear(viewController.screenName)
    }

    /// Controller referansından otomatik isim türeterek ekran kapanışını izler.
    public func screenDidDisappear(for viewController: UIViewController) {
        screenDidDisappear(viewController.screenName)
    }
}

// MARK: - SwiftUI view modifier

private struct ScreenTrackingModifier: ViewModifier {
    let name: String

    @Environment(\.scenePhase) private var scenePhase

    /// View hierarchy'de mi (onAppear ile onDisappear arası).
    @State private var isOnScreen = false
    /// `appeared` gönderildi ve henüz `disappeared` gönderilmedi.
    @State private var isReported = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isOnScreen = true
                report(appeared: true)
            }
            .onDisappear {
                isOnScreen = false
                report(appeared: false)
            }
            // SwiftUI arka plana alınırken onDisappear çağırmaz — ekran sonsuza dek
            // "açık" kalır, dwell timer'ları da öyle. scenePhase ile kapatıyoruz.
            .onChange(of: scenePhase) { phase in
                guard isOnScreen else { return }
                switch phase {
                case .background: report(appeared: false)
                case .active:     report(appeared: true)
                default:          break   // .inactive geçici (bildirim merkezi, sistem alert'i)
                }
            }
    }

    /// Çift `appeared` / eşleşmeyen `disappeared` göndermemek için tek kapı.
    private func report(appeared: Bool) {
        guard appeared != isReported else { return }
        isReported = appeared
        if appeared {
            AppInsight.shared.screenDidAppear(name)
        } else {
            AppInsight.shared.screenDidDisappear(name)
        }
    }
}

extension View {
    /// SwiftUI view'unu otomatik olarak izler.
    ///
    /// ```swift
    /// struct HomeView: View {
    ///     var body: some View {
    ///         Text("Home")
    ///             .trackScreen("Home")
    ///     }
    /// }
    /// ```
    public func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(name: name))
    }
}

// MARK: - SwiftUI base view

/// `InsightBaseViewController`'ın SwiftUI karşılığı.
///
/// SwiftUI'da inheritance yok; aynı etkiyi protocol + default `body` ile kuruyoruz.
/// Ekran başına yapılacak tek iş: `View` yerine buna conform et, `body`'yi
/// `screenBody` olarak adlandır. Tracking, ekran adı ve arka plan davranışı hazır gelir.
///
/// ```swift
/// struct HomeView: InsightBaseView {
///     var screenBody: some View {
///         VStack { Text("Home") }
///     }
/// }
/// // → ekran adı "HomeView"
///
/// // Adı özelleştirmek istersen (UIKit'teki `override var screenName` gibi):
/// struct HomeView: InsightBaseView {
///     var screenName: String { "Ana Sayfa" }
///     var screenBody: some View { ... }
/// }
/// ```
///
/// > Ekran adı funnel step'indeki `screen` değeriyle birebir aynı olmalıdır.
public protocol InsightBaseView: View {
    associatedtype ScreenBody: View

    /// Varsayılan: struct'ın tip adı. Override edilebilir.
    var screenName: String { get }

    /// Ekranın içeriği — normalde `body` yazacağın yer.
    @ViewBuilder var screenBody: ScreenBody { get }
}

public extension InsightBaseView {

    var screenName: String { String(describing: Self.self) }

    var body: some View {
        screenBody.trackScreen(screenName)
    }
}
