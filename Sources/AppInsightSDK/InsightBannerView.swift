import UIKit

public final class InsightBannerView: UIView {

    private let insightId: String
    private let onAction: (() -> Void)?
    private let onPermanentDismiss: (() -> Void)?
    private let onUserClose: (() -> Void)?

    private let durationMs: Int
    private var remainingMs: Int
    private var countdownTimer: Timer?
    private let progressView = UIProgressView(progressViewStyle: .default)

    public init(
        insight: InsightMessage,
        onAction: (() -> Void)? = nil,
        onPermanentDismiss: (() -> Void)? = nil,
        onUserClose: (() -> Void)? = nil
    ) {
        self.insightId          = insight.id
        self.onAction           = onAction
        self.onPermanentDismiss = onPermanentDismiss
        self.onUserClose        = onUserClose
        self.durationMs         = insight.display?.durationMs ?? 5_000
        self.remainingMs        = insight.display?.durationMs ?? 5_000
        super.init(frame: .zero)
        build(insight: insight)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func build(insight: InsightMessage) {
        backgroundColor = .systemBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 6)

        // ── Sol aksan şeridi ──────────────────────────────────────────────────
        let accent = UIView()
        accent.backgroundColor = UIColor.systemIndigo
        accent.layer.cornerRadius = 2
        accent.layer.cornerCurve = .continuous
        accent.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accent)
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            accent.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            accent.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            accent.widthAnchor.constraint(equalToConstant: 4),
        ])

        // ── Content stack ──────────────────────────────────────────────────────
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // title row: [title] [✕]
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 6

        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let closeBtn = makeCloseButton()

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(closeBtn)
        stack.addArrangedSubview(titleRow)

        // body
        if let body = insight.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 13)
            bodyLabel.textColor = .secondaryLabel
            bodyLabel.numberOfLines = 3
            stack.addArrangedSubview(bodyLabel)
        }

        // action pill butonu
        if let action = insight.action, action.type != "dismiss" {
            let label: String
            switch action.type {
            case "redirect":  label = "Sayfaya Git"
            case "deeplink":  label = "Detayı Gör"
            case "return_to": label = "İşleme Dön"
            case "set_value": label = (action.suggestedValue?.isEmpty == false) ? "Öneri Uygula" : "Değer Gir"
            default:          label = "Aç"
            }

            var config = UIButton.Configuration.filled()
            config.title = label
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor.systemIndigo
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                return a
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.cornerStyle = .medium

            let btn = UIButton(configuration: config)
            btn.addTarget(self, action: #selector(handleAction), for: .touchUpInside)

            let btnWrapper = UIView()
            btnWrapper.translatesAutoresizingMaskIntoConstraints = false
            btn.translatesAutoresizingMaskIntoConstraints = false
            btnWrapper.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: btnWrapper.leadingAnchor),
                btn.topAnchor.constraint(equalTo: btnWrapper.topAnchor),
                btn.bottomAnchor.constraint(equalTo: btnWrapper.bottomAnchor),
            ])

            stack.addArrangedSubview(btnWrapper)
            stack.setCustomSpacing(10, after: stack.arrangedSubviews.last ?? titleRow)
        }

        // "Bir daha gösterme"
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

            var cfg = UIButton.Configuration.plain()
            cfg.title = "Bir daha gösterme"
            cfg.baseForegroundColor = .label
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs; a.font = UIFont.systemFont(ofSize: 13, weight: .medium); return a
            }
            cfg.contentInsets = .zero
            let dismissBtn = UIButton(configuration: cfg)
            dismissBtn.contentHorizontalAlignment = .leading
            dismissBtn.setContentHuggingPriority(.defaultLow, for: .horizontal)
            dismissBtn.addTarget(self, action: #selector(handlePermanentDismiss), for: .touchUpInside)

            row.addArrangedSubview(icon)
            row.addArrangedSubview(dismissBtn)
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        // ── Progress bar ───────────────────────────────────────────────────────
        progressView.setProgress(1.0, animated: false)
        progressView.progressTintColor = UIColor.systemIndigo.withAlphaComponent(0.75)
        progressView.trackTintColor    = UIColor.systemIndigo.withAlphaComponent(0.12)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            progressView.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    // MARK: - Lifecycle

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            startCountdown()
        } else {
            stopCountdown()
        }
    }

    // MARK: - Countdown (sadece progress bar)

    private func startCountdown() {
        countdownTimer?.invalidate()
        let totalMs = Float(durationMs)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remainingMs = max(0, self.remainingMs - 100)
            self.progressView.setProgress(Float(self.remainingMs) / totalMs, animated: true)
            if self.remainingMs == 0 { self.countdownTimer?.invalidate() }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Buttons

    private func makeCloseButton() -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        config.baseForegroundColor = .tertiaryLabel
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 0)
        let btn = UIButton(configuration: config)
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.addTarget(self, action: #selector(selfDismiss), for: .touchUpInside)
        return btn
    }

    @objc private func selfDismiss() {
        stopCountdown()
        onUserClose?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }

    @objc private func handleAction() {
        onAction?()
        dismissSilently()
    }

    private func dismissSilently() {
        stopCountdown()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }

    @objc private func handlePermanentDismiss() {
        stopCountdown()
        onPermanentDismiss?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }
}
