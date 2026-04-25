import UIKit

/// SDK default banner — üstten kayarak gelir, title + body + kapat + aksiyon butonu.
/// Özelleştirmek için kendi `InsightPresenting` implementasyonunu yaz.
public final class InsightBannerView: UIView {

    private let insightId: String
    private let onAction: (() -> Void)?
    private let onPermanentDismiss: (() -> Void)?
    private let onUserClose: (() -> Void)?

    public init(
        insight: InsightMessage,
        onAction: (() -> Void)? = nil,
        onPermanentDismiss: (() -> Void)? = nil,
        onUserClose: (() -> Void)? = nil
    ) {
        self.insightId = insight.id
        self.onAction = onAction
        self.onPermanentDismiss = onPermanentDismiss
        self.onUserClose = onUserClose
        super.init(frame: .zero)
        build(insight: insight)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(insight: InsightMessage) {
        backgroundColor = .systemBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // — title row —
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .top
        titleRow.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let closeBtn = closeButton()
        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(closeBtn)
        stack.addArrangedSubview(titleRow)

        // — body —
        if let body = insight.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 13)
            bodyLabel.textColor = .secondaryLabel
            bodyLabel.numberOfLines = 3
            stack.addArrangedSubview(bodyLabel)
        }

        // — action link —
        if let action = insight.action, action.type != "dismiss" {
            let btn = UIButton(type: .system)
            btn.setTitle(action.type == "deeplink" ? "Detayı Gör →" : "Aç →", for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.contentHorizontalAlignment = .leading
            btn.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        // — permanent dismiss — (separator + belirgin buton)
        if onPermanentDismiss != nil {
            let separator = UIView()
            separator.backgroundColor = UIColor.separator
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            stack.addArrangedSubview(separator)

            let dismissRow = UIStackView()
            dismissRow.axis = .horizontal
            dismissRow.alignment = .center
            dismissRow.spacing = 6

            let icon = UIImageView(image: UIImage(systemName: "bell.slash"))
            icon.tintColor = .systemOrange
            icon.contentMode = .scaleAspectFit
            icon.widthAnchor.constraint(equalToConstant: 14).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 14).isActive = true

            let btn = UIButton(type: .system)
            btn.setTitle("Bir daha gösterme", for: .normal)
            btn.setTitleColor(.label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.contentHorizontalAlignment = .leading
            btn.addTarget(self, action: #selector(handlePermanentDismiss), for: .touchUpInside)
            btn.setContentHuggingPriority(.defaultLow, for: .horizontal)

            dismissRow.addArrangedSubview(icon)
            dismissRow.addArrangedSubview(btn)
            stack.addArrangedSubview(dismissRow)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    private func closeButton() -> UIButton {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        btn.setImage(img, for: .normal)
        btn.tintColor = .tertiaryLabel
        btn.addTarget(self, action: #selector(selfDismiss), for: .touchUpInside)
        btn.setContentHuggingPriority(.required, for: .horizontal)
        return btn
    }

    @objc private func selfDismiss() {
        onUserClose?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }

    @objc private func handleAction() {
        onAction?()
        selfDismiss()
    }

    @objc private func handlePermanentDismiss() {
        onPermanentDismiss?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }
}
