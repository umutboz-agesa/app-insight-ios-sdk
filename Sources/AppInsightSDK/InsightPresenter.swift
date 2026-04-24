import UIKit

// MARK: - Protocol

/// SDK'nın insight gösterme davranışını özelleştirmek için implement et.
public protocol InsightPresenting: AnyObject {
    func present(_ insight: InsightMessage, onAction: ((InsightMessage) -> Void)?)
}

// MARK: - Default UIKit Presenter

/// SDK'nın varsayılan sunucusu. `display.style`'a göre banner / modal / toast gösterir.
public final class DefaultInsightPresenter: InsightPresenting {

    public init() {}

    public func present(_ insight: InsightMessage, onAction: ((InsightMessage) -> Void)?) {
        guard let window = keyWindow() else { return }

        switch insight.display?.style ?? "banner" {
        case "modal": presentModal(insight, in: window, onAction: onAction)
        case "toast":  presentToast(insight, in: window)
        default:       presentBanner(insight, in: window, onAction: onAction)
        }
    }

    // MARK: Banner

    private func presentBanner(_ insight: InsightMessage, in window: UIWindow, onAction: ((InsightMessage) -> Void)?) {
        let permanentDismiss = { AppInsight.shared.permanentlyDismiss(insightId: insight.id) }
        let view = InsightBannerView(
            insight: insight,
            onAction: { onAction?(insight) },
            onPermanentDismiss: permanentDismiss
        )
        window.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 12),
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16),
        ])
        animate(view, in: window, duration: insight.display?.durationMs ?? 5_000, translation: -12)
    }

    // MARK: Toast

    private func presentToast(_ insight: InsightMessage, in window: UIWindow) {
        let view = InsightToastView(insight: insight)
        window.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            view.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 24),
            view.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -24),
        ])
        animate(view, in: window, duration: insight.display?.durationMs ?? 3_000, translation: 12)
    }

    // MARK: Modal

    private func presentModal(_ insight: InsightMessage, in window: UIWindow, onAction: ((InsightMessage) -> Void)?) {
        let overlay = DimmingView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: window.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])

        let dismiss = { UIView.animate(withDuration: 0.25, animations: { overlay.alpha = 0 }) { _ in overlay.removeFromSuperview() } }
        overlay.onTap = dismiss  // backdrop tap → dismiss

        let permanentDismiss = { AppInsight.shared.permanentlyDismiss(insightId: insight.id) }
        let card = InsightModalView(
            insight: insight,
            onAction: { onAction?(insight); dismiss() },
            onDismiss: dismiss,
            onPermanentDismiss: permanentDismiss
        )
        overlay.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),
        ])

        overlay.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
            overlay.alpha = 1
            card.transform = .identity
        }
    }

    // MARK: Shared animation

    private func animate(_ view: UIView, in window: UIWindow, duration: Int, translation: CGFloat) {
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: translation)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            view.alpha = 1; view.transform = .identity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration) / 1000) {
            UIView.animate(withDuration: 0.25, animations: { view.alpha = 0 }) { _ in view.removeFromSuperview() }
        }
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

/// Overlay view — sadece doğrudan kendisine dokunulduğunda dismiss eder (card'a değil).
private final class DimmingView: UIView {
    var onTap: (() -> Void)?
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first, touch.view === self else { return }
        onTap?()
    }
}
