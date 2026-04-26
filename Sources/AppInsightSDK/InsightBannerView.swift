import UIKit

/// SDK default banner — üstten kayarak gelir.
/// Özelleştirmek için kendi `InsightPresenting` implementasyonunu yaz.
public final class InsightBannerView: UIView {

    private let insightId: String
    private let onAction: (() -> Void)?
    private let onPermanentDismiss: (() -> Void)?
    private let onUserClose: (() -> Void)?

    private let durationMs: Int
    private var remainingSeconds: Int
    private var countdownTimer: Timer?
    private let countdownLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)

    public init(
        insight: InsightMessage,
        onAction: (() -> Void)? = nil,
        onPermanentDismiss: (() -> Void)? = nil,
        onUserClose: (() -> Void)? = nil
    ) {
        self.insightId         = insight.id
        self.onAction          = onAction
        self.onPermanentDismiss = onPermanentDismiss
        self.onUserClose       = onUserClose
        self.durationMs        = insight.display?.durationMs ?? 5_000
        self.remainingSeconds  = Int(ceil(Double(durationMs) / 1000))
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
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        // ── Content stack ──────────────────────────────────────────────────────
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // title row: [title] [countdown] [✕]
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 6

        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        countdownLabel.textColor = .secondaryLabel
        countdownLabel.text = "\(remainingSeconds)s"
        countdownLabel.textAlignment = .right
        countdownLabel.setContentHuggingPriority(.required, for: .horizontal)
        countdownLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let closeBtn = makeCloseButton()

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(countdownLabel)
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

        // action link
        if let action = insight.action, action.type != "dismiss" {
            let btn = UIButton(type: .system)
            let label: String
            switch action.type {
            case "redirect": label = "Sayfaya Git →"
            case "deeplink": label = "Detayı Gör →"
            default:         label = "Aç →"
            }
            btn.setTitle(label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.contentHorizontalAlignment = .leading
            btn.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        // tüm banner kartına tap gesture — action butonuyla aynı davranış
        if let action = insight.action, action.type != "dismiss" {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleAction))
            addGestureRecognizer(tap)
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

            let btn = UIButton(type: .system)
            btn.setTitle("Bir daha gösterme", for: .normal)
            btn.setTitleColor(.label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.contentHorizontalAlignment = .leading
            btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
            btn.addTarget(self, action: #selector(handlePermanentDismiss), for: .touchUpInside)

            row.addArrangedSubview(icon)
            row.addArrangedSubview(btn)
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        // ── Progress bar (UIProgressView) ──────────────────────────────────────
        progressView.setProgress(1.0, animated: false)
        progressView.progressTintColor = UIColor.systemIndigo.withAlphaComponent(0.55)
        progressView.trackTintColor    = UIColor.systemIndigo.withAlphaComponent(0.10)
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
            AppInsightLogger.info("InsightBannerView added to window — starting countdown (\(remainingSeconds)s)")
            startCountdown()
        } else {
            AppInsightLogger.debug("InsightBannerView removed from superview")
            stopCountdown()
        }
    }

    // MARK: - Countdown + progress (Timer, saniyede bir)

    private func startCountdown() {
        countdownTimer?.invalidate()
        let totalSeconds = Float(durationMs) / 1000
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remainingSeconds -= 1
            let s = max(0, self.remainingSeconds)
            self.countdownLabel.text = "\(s)s"
            if s <= 2 { self.countdownLabel.textColor = .systemOrange }
            // UIProgressView.setProgress(animated:true) kendi 0.25s animasyonu ile günceller
            self.progressView.setProgress(Float(s) / totalSeconds, animated: true)
            if s == 0 { self.countdownTimer?.invalidate() }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Button handlers

    private func makeCloseButton() -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        btn.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        btn.tintColor = .tertiaryLabel
        btn.addTarget(self, action: #selector(selfDismiss), for: .touchUpInside)
        btn.setContentHuggingPriority(.required, for: .horizontal)
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
        selfDismiss()
    }

    @objc private func handlePermanentDismiss() {
        stopCountdown()
        onPermanentDismiss?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }
}
