import SwiftUI

// MARK: - View Modifier

@available(iOS 14.0, *)
struct InsightOverlayModifier: ViewModifier {
    @ObservedObject private var store = InsightStore.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let insight = store.pending {
                InsightOverlayView(insight: insight) {
                    store.onAction?(insight)
                } onDismiss: {
                    store.dismiss()
                } onPermanentDismiss: {
                    store.permanentDismiss()
                }
                .transition(.move(edge: displayEdge(for: insight)).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.pending?.id)
    }

    private func displayEdge(for insight: InsightMessage) -> Edge {
        switch insight.display?.style ?? "banner" {
        case "toast": return .bottom
        default:      return .top
        }
    }
}

@available(iOS 14.0, *)
public extension View {
    /// SwiftUI uygulamalarında root view'a ekle. Insight gelince otomatik gösterir.
    ///
    ///     // App struct:
    ///     AppInsight.shared.presenter = InsightStore.shared
    ///
    ///     // Root view:
    ///     ContentView().insightOverlay()
    func insightOverlay() -> some View {
        modifier(InsightOverlayModifier())
    }
}

// MARK: - Overlay dispatcher

@available(iOS 14.0, *)
struct InsightOverlayView: View {
    let insight: InsightMessage
    let onAction: () -> Void
    let onDismiss: () -> Void
    let onPermanentDismiss: () -> Void

    var body: some View {
        switch insight.display?.style ?? "banner" {
        case "modal": InsightModalSwiftUI(insight: insight, onAction: onAction, onDismiss: onDismiss, onPermanentDismiss: onPermanentDismiss)
        case "toast":  InsightToastSwiftUI(insight: insight, onDismiss: onDismiss)
        default:       InsightBannerSwiftUI(insight: insight, onAction: onAction, onDismiss: onDismiss, onPermanentDismiss: onPermanentDismiss)
        }
    }
}

// MARK: - Banner

@available(iOS 14.0, *)
struct InsightBannerSwiftUI: View {
    let insight: InsightMessage
    let onAction: () -> Void
    let onDismiss: () -> Void
    let onPermanentDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            if let body = insight.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let action = insight.action, action.type != "dismiss" {
                Button(action: { onAction(); onDismiss() }) {
                    Text(action.type == "deeplink" ? "Detayı Gör →" : action.type == "url" ? "Güncelle →" : "Aç →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }

            Button(action: { onPermanentDismiss() }) {
                Text("Bir daha gösterme")
                    .font(.system(size: 12))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .onAppear { autoDismiss() }
    }

    private func autoDismiss() {
        let ms = insight.display?.durationMs ?? 5_000
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(ms) / 1000) { onDismiss() }
    }
}

// MARK: - Toast

@available(iOS 14.0, *)
struct InsightToastSwiftUI: View {
    let insight: InsightMessage
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                if let body = insight.body, !body.isEmpty {
                    Divider()
                        .frame(height: 14)
                        .background(Color.white.opacity(0.3))
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color(UIColor.label))
            .clipShape(Capsule())
            .padding(.bottom, 24)
        }
        .onAppear { autoDismiss() }
    }

    private func autoDismiss() {
        let ms = insight.display?.durationMs ?? 3_000
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(ms) / 1000) { onDismiss() }
    }
}

// MARK: - Modal

@available(iOS 14.0, *)
struct InsightModalSwiftUI: View {
    let insight: InsightMessage
    let onAction: () -> Void
    let onDismiss: () -> Void
    let onPermanentDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(UIColor.quaternaryLabel))
                    }
                }

                Text(insight.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let body = insight.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer().frame(height: 8)

                if let action = insight.action, action.type != "dismiss" {
                    Button(action: { onAction(); onDismiss() }) {
                        Text(action.type == "deeplink" ? "Devam Et" : action.type == "url" ? "Güncelle" : "Aç")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }

                Button(action: onDismiss) {
                    Text("Kapat")
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                }

                Button(action: { onPermanentDismiss() }) {
                    Text("Bir daha gösterme")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
