import RevenueCat
import RevenueCatUI
import SwiftUI

/// Shown where a Pro feature would be. Opens the RevenueCat paywall from whichever sheet it lives in.
struct ProUpsellView: View {
    var message = "Get a summary of every conversation, with key points and follow-ups."
    @State private var showingPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("TranslateCat Pro", systemImage: "crown.fill")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(CatTheme.accent)
            Text(message)
                .foregroundStyle(CatTheme.ink)
            Button("Unlock Pro", systemImage: "sparkles") {
                showingPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingPaywall) {
            ProPaywall()
        }
    }
}

/// The RevenueCat paywall for the current offering, closing itself once Pro is unlocked.
struct ProPaywall: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { info in
                if info.entitlements[SubscriptionModel.entitlementID]?.isActive == true { dismiss() }
            }
            .onRestoreCompleted { info in
                if info.entitlements[SubscriptionModel.entitlementID]?.isActive == true { dismiss() }
            }
    }
}
