import UIKit

/// Operatörün set_value action'ı gönderdiğinde gösterilen bottom sheet.
/// Kullanıcı değeri onaylar → SDK kayıtlı UITextField'ın text'ini set eder.
enum InsightInputSheet {

    static func present(
        in window: UIWindow,
        insight: InsightMessage,
        memberKey: String,
        suggestedValue: String,
        onConfirm: @escaping (String) -> Void
    ) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: window.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])

        let sheet = buildSheet(
            overlay: overlay,
            insight: insight,
            suggestedValue: suggestedValue,
            onConfirm: onConfirm
        )
        overlay.addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
        ])

        overlay.alpha = 0
        sheet.transform = CGAffineTransform(translationX: 0, y: 400)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            overlay.alpha = 1
            sheet.transform = .identity
        }
    }

    private static func buildSheet(
        overlay: UIView,
        insight: InsightMessage,
        suggestedValue: String,
        onConfirm: @escaping (String) -> Void
    ) -> UIView {
        let sheet = UIView()
        sheet.backgroundColor = .systemBackground
        sheet.layer.cornerRadius = 24
        sheet.layer.cornerCurve = .continuous
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let dismiss = {
            UIView.animate(withDuration: 0.3, animations: {
                overlay.alpha = 0
                sheet.transform = CGAffineTransform(translationX: 0, y: sheet.bounds.height + 100)
            }) { _ in overlay.removeFromSuperview() }
        }

        // Overlay'e tıklayınca kapat
        let tapGR = ClosureTapGestureRecognizer { dismiss() }
        overlay.addGestureRecognizer(tapGR)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(stack)

        // Handle bar
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
        let spacerL = UIView(); spacerL.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let spacerR = UIView(); spacerR.setContentHuggingPriority(.defaultLow, for: .horizontal)
        handleRow.addArrangedSubview(spacerL)
        handleRow.addArrangedSubview(handle)
        handleRow.addArrangedSubview(spacerR)
        stack.addArrangedSubview(handleRow)
        stack.setCustomSpacing(16, after: handleRow)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        // Body (opsiyonel)
        if let body = insight.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 14)
            bodyLabel.textColor = .secondaryLabel
            bodyLabel.textAlignment = .center
            bodyLabel.numberOfLines = 0
            stack.addArrangedSubview(bodyLabel)
        }
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last ?? titleLabel)

        // Input field
        let textField = UITextField()
        textField.text = suggestedValue
        textField.borderStyle = .none
        textField.font = .systemFont(ofSize: 16)
        textField.textAlignment = .center
        textField.keyboardType = .decimalPad
        textField.backgroundColor = UIColor.secondarySystemBackground
        textField.layer.cornerRadius = 12
        textField.layer.cornerCurve = .continuous
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 52).isActive = true

        // İç boşluk için sarmalayıcı
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 52))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 52))
        textField.rightViewMode = .always

        stack.addArrangedSubview(textField)
        stack.setCustomSpacing(16, after: textField)

        // Onayla butonu
        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle("Onayla", for: .normal)
        confirmBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmBtn.backgroundColor = .systemIndigo
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.layer.cornerRadius = 14
        confirmBtn.layer.cornerCurve = .continuous
        confirmBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(confirmBtn)

        // İptal butonu
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("İptal", for: .normal)
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

        confirmBtn.addAction(UIAction { _ in
            let value = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            dismiss()
            onConfirm(value)
        }, for: .touchUpInside)

        cancelBtn.addAction(UIAction { _ in dismiss() }, for: .touchUpInside)

        // Klavye çıkınca sheet yukarı kaymasın — sadece text field focus
        textField.becomeFirstResponder()

        return sheet
    }
}

// MARK: - Yardımcı: closure tabanlı tap gesture

private final class ClosureTapGestureRecognizer: UITapGestureRecognizer {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handle))
    }
    @objc private func handle() { action() }
}
