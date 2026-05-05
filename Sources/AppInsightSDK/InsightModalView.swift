import UIKit

public final class InsightModalView: UIView {

    private let onAction:           (() -> Void)?
    private let onDismiss:          (() -> Void)?
    private let onPermanentDismiss: (() -> Void)?

    public init(
        insight: InsightMessage,
        onAction:           (() -> Void)? = nil,
        onDismiss:          (() -> Void)? = nil,
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

        // ── Close row ─────────────────────────────────────────────────────
        let closeRow = UIStackView()
        closeRow.axis = .horizontal
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        var closeCfg = UIButton.Configuration.plain()
        closeCfg.image = UIImage(systemName: "xmark.circle.fill",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
        closeCfg.baseForegroundColor = .quaternaryLabel
        closeCfg.contentInsets = .zero
        let closeBtn = UIButton(configuration: closeCfg)
        closeBtn.addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        closeRow.addArrangedSubview(spacer)
        closeRow.addArrangedSubview(closeBtn)
        stack.addArrangedSubview(closeRow)

        // ── Title ──────────────────────────────────────────────────────────
        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        // ── Body ───────────────────────────────────────────────────────────
        if let body = insight.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 15)
            bodyLabel.textColor = .secondaryLabel
            bodyLabel.numberOfLines = 0
            stack.addArrangedSubview(bodyLabel)
        }

        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last ?? closeRow)

        // ── Primary action button ──────────────────────────────────────────
        let hasAction = insight.action != nil && insight.action?.type != "dismiss"
        if let action = insight.action, hasAction {
            let label: String
            switch action.type {
            case "redirect":  label = "Sayfaya Git →"
            case "deeplink":  label = "Devam Et"
            case "return_to": label = "İşleme Dön"
            case "set_value": label = (action.suggestedValue?.isEmpty == false) ? "Öneri Uygula" : "Değer Gir"
            default:          label = "Aç"
            }

            var cfg = UIButton.Configuration.filled()
            cfg.title = label
            cfg.baseForegroundColor = .white
            cfg.baseBackgroundColor = .systemIndigo
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs; a.font = UIFont.systemFont(ofSize: 16, weight: .semibold); return a
            }
            cfg.cornerStyle = .large
            let btn = UIButton(configuration: cfg)
            btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
            btn.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        // ── Secondary close (her zaman görünür) ───────────────────────────
        var closeLinkCfg = UIButton.Configuration.plain()
        closeLinkCfg.title = "Kapat"
        closeLinkCfg.baseForegroundColor = .secondaryLabel
        closeLinkCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = UIFont.systemFont(ofSize: 15, weight: .medium); return a
        }
        let closeLink = UIButton(configuration: closeLinkCfg)
        closeLink.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        stack.addArrangedSubview(closeLink)

        // ── Permanent dismiss ──────────────────────────────────────────────
        if onPermanentDismiss != nil {
            let sep = UIView()
            sep.backgroundColor = UIColor.separator
            sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            stack.addArrangedSubview(sep)

            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 6

            let icon = UIImageView(image: UIImage(systemName: "bell.slash"))
            icon.tintColor = .systemOrange
            icon.contentMode = .scaleAspectFit
            icon.widthAnchor.constraint(equalToConstant: 14).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 14).isActive = true

            var dismissCfg = UIButton.Configuration.plain()
            dismissCfg.title = "Bir daha gösterme"
            dismissCfg.baseForegroundColor = .label
            dismissCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs; a.font = UIFont.systemFont(ofSize: 13, weight: .medium); return a
            }
            dismissCfg.contentInsets = .zero
            let dismissBtn = UIButton(configuration: dismissCfg)
            dismissBtn.contentHorizontalAlignment = .leading
            dismissBtn.setContentHuggingPriority(.defaultLow, for: .horizontal)
            dismissBtn.addTarget(self, action: #selector(handlePermanentDismiss), for: .touchUpInside)

            row.addArrangedSubview(icon)
            row.addArrangedSubview(dismissBtn)
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
    }

    @objc private func dismiss()                { onDismiss?() }
    @objc private func handleAction()           { onAction?() }
    @objc private func handlePermanentDismiss() { onPermanentDismiss?(); onDismiss?() }
}
