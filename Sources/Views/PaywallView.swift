import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    let manager = SubscriptionManager.shared
    @State private var selectedPlan = "annual"
    @State private var showFeatures = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.yellow.opacity(0.2), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                    Circle()
                        .stroke(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                        .frame(width: 100, height: 100)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .orange.opacity(0.4), radius: 12)
                }

                VStack(spacing: 6) {
                    Text("Unlock ClipStack Pro")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Supercharge your clipboard with AI\nand unlimited power")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 32)

            Divider()
                .padding(.vertical, 16)

            // Features
            ScrollView {
                VStack(spacing: 10) {
                    FeatureRow(icon: "infinity", title: "Unlimited History", subtitle: "Save every clip forever", gradient: [.blue, .cyan])
                    FeatureRow(icon: "brain.head.profile.fill", title: "AI Categorize", subtitle: "Auto-organize your clips", gradient: [.purple, .pink])
                    FeatureRow(icon: "sparkle.magnifyingglass", title: "Smart Search", subtitle: "Find anything with AI", gradient: [.indigo, .blue])
                    FeatureRow(icon: "square.stack.fill", title: "Paste Stack", subtitle: "Queue multiple pastes", gradient: [.orange, .yellow])
                    FeatureRow(icon: "arrow.up.arrow.down", title: "Export / Import", subtitle: "JSON, CSV, Markdown", gradient: [.green, .mint])
                    FeatureRow(icon: "paintbrush.pointed.fill", title: "Custom Themes", subtitle: "Dark, Light, Neon", gradient: [.pink, .red])
                }
                .padding(.horizontal, 24)
            }

            Divider()
                .padding(.top, 16)

            // Pricing
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    PriceCard(
                        title: "Monthly",
                        price: "$2.99",
                        period: "/month",
                        isSelected: selectedPlan == "monthly"
                    ) {
                        withAnimation(.spring(response: 0.3)) { selectedPlan = "monthly" }
                    }

                    PriceCard(
                        title: "Annual",
                        price: "$24.99",
                        period: "/year",
                        badge: "Save 30%",
                        isSelected: selectedPlan == "annual"
                    ) {
                        withAnimation(.spring(response: 0.3)) { selectedPlan = "annual" }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            // Subscribe button
            VStack(spacing: 12) {
                Button(action: { manager.subscribe(); dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start 7-Day Free Trial")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .indigo.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(.plain)

                Button(action: { manager.subscribe(); dismiss() }) {
                    Text("Subscribe Now — \(selectedPlan == "monthly" ? "$2.99/month" : "$24.99/year")")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.indigo)
                }
                .buttonStyle(.plain)

                Text("Cancel anytime. No questions asked.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 680)
        .background(
            LinearGradient(colors: [Color(nsColor: .windowBackgroundColor)], startPoint: .top, endPoint: .bottom)
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct PriceCard: View {
    let title: String
    let price: String
    let period: String
    var badge: String? = nil
    let isSelected: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(period)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.indigo.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.indigo : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: isSelected ? .indigo.opacity(0.2) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
