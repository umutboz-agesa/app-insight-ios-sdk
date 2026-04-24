import Combine

/// SwiftUI uygulamaları için insight köprüsü.
/// `AppInsight.shared.presenter = InsightStore.shared` set edip
/// root view'a `.insightOverlay()` ekle.
@available(iOS 13.0, *)
public final class InsightStore: ObservableObject, InsightPresenting {

    public static let shared = InsightStore()
    private init() {}

    @Published public internal(set) var pending: InsightMessage? = nil
    public var onAction: ((InsightMessage) -> Void)?

    public func present(_ insight: InsightMessage, onAction: ((InsightMessage) -> Void)?) {
        self.onAction = onAction
        DispatchQueue.main.async { self.pending = insight }
    }

    public func dismiss() {
        DispatchQueue.main.async { self.pending = nil }
    }
}
