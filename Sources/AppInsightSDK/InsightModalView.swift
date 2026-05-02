import UIKit

/// SDK default modal — ortalanmış kart, karartılmış arka plan, büyük aksiyon butonu.
public final class InsightModalView: UIView {

    private let onAction:          (() -> Void)?
    private let onDismiss:         (() -> Void)?
    private let onPermanentDismiss: (() -> Void)?

    public init(
        insight: InsightMessage,
        onAction:          (() -> Void)? = nil,
        onDismiss:         (() -> Void)? = nil,
        onPermanentDismiss: (() -> Void)? = nil
    ) {
        self.onAction           = onAction
        self.onDismiss          = onDismiss
        self.onPermanentDismiss = onPermanentDismiss
        super.init(frame: .zero)
        build(insight: insight)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(insight: InsightMessage) {
        backgroundColor = .systemBackground
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // — close row —
        let closeRow = UIStackView()
        closeRow.axis = .horizontal
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let closeBtn = UIButton(type: .system)
        let img = UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
        closeBtn.setImage(img, for: .normal)
        closeBtn.tintColor = .quaternaryLabel
        closeBtn.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        closeRow.addArrangedSubview(spacer)
        closeRow.addArrangedSubview(closeBtn)
        stack.addArrangedSubview(closeRow)

        // — title —
        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        // — body —
        if let body = insight.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 15)
            bodyLabel.textColor = .secondaryLabel
            bodyLabel.numberOfLines = 0
            stack.addArrangedSubview(bodyLabel)
        }

        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last ?? closeRow)

        let hasAction = insight.action != nil && insight.action?.type != "dismiss"

        // — primary action button —
        if let action = insight.action, hasAction {
            let btn = UIButton(type: .system)
            let label: String
            switch action.type {
            case "redirect":   label = "Sayfaya Git →"
            case "deeplink":   label = "Devam Et"
            case "return_to":  label = "İşleme Dön"
            case "set_value":  label = (action.suggestedValue?.isEmpty == false) ? "Öneri Uygula" : "Değer Gir"
            default:           label = "Aç"
            }
            btn.setTitle(label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            btn.backgroundColor = .systemIndigo
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 13
            btn.layer.cornerCurve = .continuous
            btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
            btn.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        // — kapat link — sadece aksiyon yoksa göster
        if !hasAction {
            let closeLink = UIButton(type: .system)
            closeLink.setTitle("Kapat", for: .normal)
            closeLink.setTitleColor(.secondaryLabel, for: .normal)
            closeLink.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
            closeLink.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
            stack.addArrangedSubview(closeLink)
        }

        // — permanent dismiss — sola hizalı, belirgin
        if onPermanentDismiss != nil {
            let btn = UIButton(type: .system)
            btn.setTitle("Bir daha gösterme", for: .normal)
            btn.setTitleColor(.systemRed.withAlphaComponent(0.7), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.contentHorizontalAlignment = .leading
            btn.addTarget(self, action: #selector(handlePermanentDismiss), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
    }

    @objc private func dismiss()               { onDismiss?() }
    @objc private func handleAction()          { onAction?() }
    @objc private func handlePermanentDismiss() { onPermanentDismiss?(); onDismiss?() }
}
