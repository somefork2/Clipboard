import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss; let manager = SubscriptionManager.shared
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack { Spacer(); Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary) }.buttonStyle(.plain) }
                Image(systemName: "crown.fill").font(.system(size: 56)).foregroundStyle(LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: .orange.opacity(0.4), radius: 20)
                Text("Unlock ClipStack Pro").font(.system(size: 26, weight: .bold))
                Text("Supercharge your clipboard with AI and unlimited power").font(.system(size: 14)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }.padding(.top, 24).padding(.horizontal, 32)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    FeatureRow(icon: "infinity", title: "Unlimited History", subtitle: "Save every clip forever")
                    FeatureRow(icon: "brain.head.profile", title: "AI Categorize", subtitle: "Auto-organize your clips")
                    FeatureRow(icon: "sparkle.magnifyingglass", title: "Smart Search", subtitle: "Find anything with AI")
                    FeatureRow(icon: "rectangle.stack", title: "Paste Stack", subtitle: "Queue multiple pastes")
                    FeatureRow(icon: "arrow.up.arrow.down", title: "Export / Import", subtitle: "JSON, CSV, Markdown")
                    FeatureRow(icon: "paintpalette.fill", title: "Custom Themes", subtitle: "Dark, Light, Neon")
                }.padding(20)
            }

            Divider()

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    PriceCard(title: "Monthly", price: "$2.99", period: "/month", isSelected: false)
                    PriceCard(title: "Annual", price: "$24.99", period: "/year", badge: "Save 30%", isSelected: true)
                }
            }.padding(.horizontal, 32).padding(.vertical, 16)

            VStack(spacing: 12) {
                Button(action: { manager.subscribe(); dismiss() }) { Text("Start 7-Day Free Trial").font(.system(size: 16, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
                Button(action: { manager.subscribe(); dismiss() }) { Text("Subscribe Now — $2.99/month").font(.system(size: 14, weight: .medium)).foregroundColor(.blue) }.buttonStyle(.plain)
                Text("Cancel anytime. No questions asked.").font(.system(size: 11)).foregroundColor(.secondary)
            }.padding(.horizontal, 32).padding(.bottom, 24)
        }.frame(width: 480, height: 640).background(LinearGradient(colors: [Color(nsColor: .windowBackgroundColor)], startPoint: .top, endPoint: .bottom))
    }
}

struct FeatureRow: View { let icon: String; let title: String; let subtitle: String; var body: some View { HStack(spacing: 14) { Image(systemName: icon).font(.system(size: 18)).foregroundColor(.blue).frame(width: 36, height: 36).background(Color.blue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8)); VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 14, weight: .semibold)); Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary) }; Spacer(); Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 18)) }.padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10)) } }

struct PriceCard: View { let title: String; let price: String; let period: String; var badge: String? = nil; let isSelected: Bool; var body: some View { VStack(spacing: 8) { if let badge { Text(badge).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3).background(Color.green).clipShape(Capsule()) }; Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.secondary); HStack(alignment: .firstTextBaseline, spacing: 2) { Text(price).font(.system(size: 28, weight: .bold)); Text(period).font(.system(size: 12)).foregroundColor(.secondary) } }.frame(maxWidth: .infinity).padding(.vertical, 16).background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))).overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)) } }
