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
        AppInsightLogger.debug("DefaultInsightPresenter.present() — style: \(insight.display?.style ?? "banner")")
        guard let window = keyWindow() else {
            AppInsightLogger.error("DefaultInsightPresenter: keyWindow is nil — banner cannot be shown")
            return
        }
        AppInsightLogger.debug("keyWindow found: \(window)")
        switch insight.display?.style ?? "banner" {
        case "modal": presentModal(insight, in: window, onAction: onAction)
        case "toast":  presentToast(insight, in: window, onAction: onAction)
        default:       presentBanner(insight, in: window, onAction: onAction)
        }
    }

    // MARK: Banner

    private func presentBanner(_ insight: InsightMessage, in window: UIWindow, onAction: ((InsightMessage) -> Void)?) {
        let sdk = AppInsight.shared
        let view = InsightBannerView(
            insight: insight,
            onAction: {
                let skipOptOut = insight.action?.type == "return_to" || insight.action?.type == "set_value"
                sdk.recordAction(insightId: insight.id, action: "action_clicked", skipOptOut: skipOptOut)
                onAction?(insight)
            },
            onPermanentDismiss: {
                sdk.permanentlyDismiss(insightId: insight.id)
            },
            onUserClose: {
                sdk.recordAction(insightId: insight.id, action: "user_closed")
            }
        )
        window.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 12),
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16),
        ])
        animate(view, in: window, duration: insight.display?.durationMs ?? 5_000, translation: -12) {
            sdk.recordAction(insightId: insight.id, action: "auto_closed")
        }
    }

    // MARK: Toast

    private func presentToast(_ insight: InsightMessage, in window: UIWindow, onAction: ((InsightMessage) -> Void)?) {
        let sdk = AppInsight.shared
        let view = InsightToastView(
            insight: insight,
            onAction: {
                let skipOptOut = insight.action?.type == "return_to" || insight.action?.type == "set_value"
                sdk.recordAction(insightId: insight.id, action: "action_clicked", skipOptOut: skipOptOut)
                onAction?(insight)
            },
            onUserClose: {
                sdk.recordAction(insightId: insight.id, action: "user_closed")
            }
        )
        window.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            view.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 24),
            view.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -24),
        ])
        animate(view, in: window, duration: insight.display?.durationMs ?? 3_000, translation: 12) {
            sdk.recordAction(insightId: insight.id, action: "auto_closed")
        }
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

        let sdk = AppInsight.shared
        let userClose = {
            sdk.recordAction(insightId: insight.id, action: "user_closed")
            dismiss()
        }
        overlay.onTap = userClose  // backdrop tap → user_closed

        let permanentDismiss = { sdk.permanentlyDismiss(insightId: insight.id) }
        let card = InsightModalView(
            insight: insight,
            onAction: {
                let proceed = {
                    let skipOptOut = insight.action?.type == "return_to" || insight.action?.type == "set_value"
                    sdk.recordAction(insightId: insight.id, action: "action_clicked", skipOptOut: skipOptOut)
                    UIView.animate(withDuration: 0.25, animations: { overlay.alpha = 0 }) { _ in
                        overlay.removeFromSuperview()
                        onAction?(insight)
                    }
                }
                if insight.action?.type == "redirect" {
                    Self.showLeaveConfirmation(in: overlay, onConfirm: proceed)
                } else {
                    proceed()
                }
            },
            onDismiss: userClose,
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
        card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 1.2) {
            overlay.alpha = 1
            card.transform = .identity
        }
    }

    // MARK: Shared animation

    private func animate(_ view: UIView, in window: UIWindow, duration: Int, translation: CGFloat, onAutoDismiss: (() -> Void)? = nil) {
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: translation)
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 1.2) {
            view.alpha = 1; view.transform = .identity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration) / 1000) {
            guard view.superview != nil else { return }  // already removed by user interaction
            onAutoDismiss?()
            UIView.animate(withDuration: 0.25, animations: { view.alpha = 0 }) { _ in view.removeFromSuperview() }
        }
    }

    private static func showLeaveConfirmation(in overlay: UIView, onConfirm: @escaping () -> Void) {
        let sheet = UIView()
        sheet.backgroundColor = .systemBackground
        sheet.layer.cornerRadius = 24
        sheet.layer.cornerCurve = .continuous
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(sheet)

        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(stack)

        let handle = UIView()
        handle.backgroundColor = UIColor.systemGray4
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.heightAnchor.constraint(equalToConstant: 5).isActive = true
        handle.widthAnchor.constraint(equalToConstant: 40).isActive = true

        let handleRow = UIStackView()
        handleRow.axis = .horizontal
        handleRow.alignment = .center
        handleRow.distribution = .equalCentering
        let l = UIView(); l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let r = UIView(); r.setContentHuggingPriority(.defaultLow, for: .horizontal)
        handleRow.addArrangedSubview(l)
        handleRow.addArrangedSubview(handle)
        handleRow.addArrangedSubview(r)
        stack.addArrangedSubview(handleRow)
        stack.setCustomSpacing(20, after: handleRow)

        let title = UILabel()
        title.text = "Bu sayfadan ayrılıyor musunuz?"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textAlignment = .center
        title.numberOfLines = 0
        stack.addArrangedSubview(title)

        let subtitle = UILabel()
        subtitle.text = "Sizi başka bir sayfaya yönlendireceğiz."
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        stack.addArrangedSubview(subtitle)
        stack.setCustomSpacing(24, after: subtitle)

        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle("Evet, devam et", for: .normal)
        confirmBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmBtn.backgroundColor = .systemIndigo
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.layer.cornerRadius = 14
        confirmBtn.layer.cornerCurve = .continuous
        confirmBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(confirmBtn)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Hayır, kal", for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelBtn.setTitleColor(.secondaryLabel, for: .normal)
        cancelBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(cancelBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -24),
        ])

        let hideSheet = {
            UIView.animate(withDuration: 0.25, animations: { sheet.transform = CGAffineTransform(translationX: 0, y: sheet.bounds.height + 100) }) { _ in sheet.removeFromSuperview() }
        }

        confirmBtn.addAction(UIAction { _ in
            hideSheet()
            // Üstteki presented stack'i kapat, sonra delegate'i tetikle
            if let rootVC = overlay.window?.rootViewController {
                rootVC.dismiss(animated: true) { onConfirm() }
            } else {
                onConfirm()
            }
        }, for: .touchUpInside)
        cancelBtn.addAction(UIAction { _ in hideSheet() }, for: .touchUpInside)

        sheet.transform = CGAffineTransform(translationX: 0, y: 400)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            sheet.transform = .identity
        }
    }

    private static func topmostViewController(in window: UIWindow) -> UIViewController {
        var vc = window.rootViewController ?? UIViewController()
        while let presented = vc.presentedViewController { vc = presented }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController { vc = visible }
        return vc
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
