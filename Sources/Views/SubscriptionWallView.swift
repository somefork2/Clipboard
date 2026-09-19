import SwiftUI

/// Shown in place of the app once the trial or the subscription has ended.
///
/// CopyWell stops recording and stops handing clips back, but it does not
/// delete anything: the history stays on disk and reappears the moment a
/// subscription is active. Saying so here is not sentiment — someone who fears
/// their clips are gone asks for a refund instead of subscribing.
struct SubscriptionWallView: View {
    @Environment(SubscriptionManager.self) private var subscriptions

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                Image(systemName: "lock")
                    .font(.system(size: 42))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("Subscribe to carry on using CopyWell. Nothing has been deleted — your history comes back the moment a subscription is active.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 420)
                }

                VStack(spacing: 10) {
                    Button("See CopyWell Pro") { subscriptions.showingPaywall = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                    Button("Restore Purchases") {
                        Task { await subscriptions.restorePurchases() }
                    }
                    .buttonStyle(.link)
                    .disabled(subscriptions.purchaseInFlight)
                }

                if let error = subscriptions.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                Label("Nothing new is recorded while CopyWell is locked.", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var title: String {
        subscriptions.hasEverSubscribed
            ? String(localized: "Your subscription has ended.")
            : String(localized: "Your free trial has ended.")
    }
}

/// Puts the wall over whatever the app would otherwise show.
struct SubscriptionGate<Content: View>: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @ViewBuilder let content: () -> Content

    var body: some View {
        if subscriptions.hasFullAccess {
            content()
        } else {
            SubscriptionWallView()
        }
    }
}
