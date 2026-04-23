import UIKit
import SwiftUI

// MARK: - Screen name derivation

extension AppInsight {
    /// Sınıf adından ekran adı türetir.
    /// `HomeViewController` → `"Home"`, `CheckoutController` → `"Checkout"`
    public static func screenName(from type: AnyClass) -> String {
        var name = String(describing: type)
        for suffix in ["ViewController", "Controller", "View", "Screen"] {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name
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

    func body(content: Content) -> some View {
        content
            .onAppear    { AppInsight.shared.screenDidAppear(name) }
            .onDisappear { AppInsight.shared.screenDidDisappear(name) }
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
