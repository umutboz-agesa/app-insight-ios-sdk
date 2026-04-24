import UIKit

/// SDK default toast — altta çıkan küçük pill. Sadece title gösterir.
public final class InsightToastView: UIView {

    public init(insight: InsightMessage) {
        super.init(frame: .zero)
        build(insight: insight)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(insight: InsightMessage) {
        backgroundColor = UIColor.label
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .systemBackground
        titleLabel.numberOfLines = 2
        stack.addArrangedSubview(titleLabel)

        if let body = insight.body, !body.isEmpty {
            let sep = UIView()
            sep.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.25)
            sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
            sep.heightAnchor.constraint(equalToConstant: 14).isActive = true
            stack.addArrangedSubview(sep)

            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 13)
            bodyLabel.textColor = UIColor.systemBackground.withAlphaComponent(0.7)
            bodyLabel.numberOfLines = 1
            stack.addArrangedSubview(bodyLabel)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
        ])
    }
}
