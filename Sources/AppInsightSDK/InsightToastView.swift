import UIKit

public final class InsightToastView: UIView {

    private let onAction:    (() -> Void)?
    private let onUserClose: (() -> Void)?

    public init(
        insight: InsightMessage,
        onAction:    (() -> Void)? = nil,
        onUserClose: (() -> Void)? = nil
    ) {
        self.onAction    = onAction
        self.onUserClose = onUserClose
        super.init(frame: .zero)
        build(insight: insight)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(insight: InsightMessage) {
        backgroundColor = UIColor.label
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let outerStack = UIStackView()
        outerStack.axis = .horizontal
        outerStack.alignment = .center
        outerStack.spacing = 10
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        // ── Text content ───────────────────────────────────────────────────
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .systemBackground
        titleLabel.numberOfLines = 2
        textStack.addArrangedSubview(titleLabel)

        if let body = insight.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 12)
            bodyLabel.textColor = UIColor.systemBackground.withAlphaComponent(0.65)
            bodyLabel.numberOfLines = 1
            textStack.addArrangedSubview(bodyLabel)
        }

        outerStack.addArrangedSubview(textStack)

        // ── Action chip (opsiyonel) ────────────────────────────────────────
        if let action = insight.action, action.type != "dismiss" {
            let sep = UIView()
            sep.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.2)
            sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
            sep.heightAnchor.constraint(equalToConstant: 20).isActive = true
            outerStack.addArrangedSubview(sep)

            let label: String
            switch action.type {
            case "redirect":  label = "Git →"
            case "return_to": label = "Dön"
            case "set_value": label = (action.suggestedValue?.isEmpty == false) ? "Uygula" : "Gir"
            default:          label = "Aç"
            }

            var cfg = UIButton.Configuration.filled()
            cfg.title = label
            cfg.baseForegroundColor = UIColor.label
            cfg.baseBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.15)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs; a.font = UIFont.systemFont(ofSize: 12, weight: .semibold); return a
            }
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
            cfg.cornerStyle = .capsule
            let actionBtn = UIButton(configuration: cfg)
            actionBtn.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
            outerStack.addArrangedSubview(actionBtn)
        }

        // ── Close button ───────────────────────────────────────────────────
        var closeCfg = UIButton.Configuration.plain()
        closeCfg.image = UIImage(systemName: "xmark",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium))
        closeCfg.baseForegroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        closeCfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 0)
        let closeBtn = UIButton(configuration: closeCfg)
        closeBtn.setContentHuggingPriority(.required, for: .horizontal)
        closeBtn.addTarget(self, action: #selector(selfDismiss), for: .touchUpInside)
        outerStack.addArrangedSubview(closeBtn)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
    }

    @objc private func handleAction() {
        onAction?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }

    @objc private func selfDismiss() {
        onUserClose?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }
}
