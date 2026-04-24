import UIKit

/// SDK default banner — üstten kayarak gelir, title + body + kapat + aksiyon butonu.
/// Özelleştirmek için kendi `InsightPresenting` implementasyonunu yaz.
public final class InsightBannerView: UIView {

    private let onAction: (() -> Void)?

    public init(insight: InsightMessage, onAction: (() -> Void)? = nil) {
        self.onAction = onAction
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
        stack.spacing = 4
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
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }

    @objc private func handleAction() {
        onAction?()
        selfDismiss()
    }
}
