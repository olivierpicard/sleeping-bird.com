import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var selectedPlan: Store.Plan = .yearly
    @State private var showNothingToRestore = false
    @Environment(\.dismiss) private var dismiss

    private let userId = UniqueIdentityStore().get()

    private var selectedProduct: Product? { store.product(for: selectedPlan) }

    /// The primary CTA copy: the free-trial promise only when the user is still
    /// eligible for the intro offer, otherwise a neutral "Subscribe" (StoreKit
    /// charges immediately once the trial has been consumed).
    private var ctaLabel: LocalizedStringKey {
        store.isEligibleForIntroOffer(selectedPlan)
            ? "paywall.cta.free_trial" : "paywall.cta.subscribe"
    }

    private var yearlyDiscount: String? {
        guard let yearly = store.product(for: .yearly),
            let monthly = store.product(for: .monthly)
        else { return nil }
        let monthlyYear = monthly.price * Decimal(12)
        guard monthlyYear > 0 else { return nil }
        let percent = ((monthlyYear - yearly.price) / monthlyYear) * 100
        let rounded = NSDecimalNumber(decimal: percent).intValue
        guard rounded > 0 else { return nil }
        return "-\(rounded) %"
    }

    private var footerText: String {
        guard let product = selectedProduct else {
            return String(localized: "paywall.footer.cancel_anytime")
        }
        let unit =
            selectedPlan == .yearly
            ? String(localized: "paywall.unit.year")
            : String(localized: "paywall.unit.month")
        return String(
            localized:
                "paywall.footer.price_unit \(product.displayPrice) \(unit)"
        )
    }

    private func contactSupport() {
        guard let url = SupportMailLink(anonymousID: userId).url else { return }
        openURL(url)
    }

    private func restore() async {
        // StoreKit determines the actual unlock and surfaces any user-facing
        // error via store.lastError. Identity stays aligned via the shared,
        // iCloud-synced UUID used as both the RevenueCat appUserID and PostHog
        // distinct_id, so there is nothing to reconcile here on restore.
        // A failed sync surfaces via store.lastError; a successful sync that
        // found no entitlement gets a gentle "nothing to restore" alert.
        guard await store.restore() else { return }
        if store.isPremium {
            dismiss()
        } else {
            showNothingToRestore = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Premium")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 24)

                    // Plan picker
                    HStack(spacing: 12) {
                        PlanCard(
                            emoji: "🤓",
                            title: "Yearly",
                            price: store.product(for: .yearly)?.displayPrice,
                            discount: yearlyDiscount,
                            isSelected: selectedPlan == .yearly
                        ) { selectedPlan = .yearly }

                        PlanCard(
                            emoji: "🤏",
                            title: "Monthly",
                            price: store.product(for: .monthly)?.displayPrice,
                            discount: nil,
                            isSelected: selectedPlan == .monthly
                        ) { selectedPlan = .monthly }
                    }
                    .padding()
                    .padding(.bottom, 15)

                    // Feature rows
                    VStack(spacing: 12) {
                        FeatureRow(
                            icon: "mic",
                            iconColor: .paywallAccent,
                            iconBackground: Color(
                                red: 0.99,
                                green: 0.82,
                                blue: 0.80
                            ),
                            title: "Unlimited Voice Interaction",
                            description:
                                "Create metrics and log entries just by speaking"
                        )

                        FeatureRow(
                            icon: "arrow.2.circlepath",
                            iconColor: Color(
                                red: 0.45,
                                green: 0.65,
                                blue: 0.90
                            ),
                            iconBackground: Color(
                                red: 0.75,
                                green: 0.87,
                                blue: 0.97
                            ),
                            title: "Unlimited Metrics",
                            description: "Track as many metrics as you want"
                        )
                        FeatureRow(
                            icon: "chart.pie",
                            iconColor: Color(
                                red: 0.60,
                                green: 0.45,
                                blue: 0.85
                            ),
                            iconBackground: Color(
                                red: 0.86,
                                green: 0.80,
                                blue: 0.97
                            ),
                            title: "Advanced Charts",
                            description:
                                "Unlock calendar, gauge and aggregate visualizations"
                        )
                        FeatureRow(
                            icon: "lock.shield",
                            iconColor: Color(
                                red: 0.20,
                                green: 0.55,
                                blue: 0.20
                            ),
                            iconBackground: Color(
                                red: 0.78,
                                green: 0.95,
                                blue: 0.70
                            ),
                            title: "No Ads, Full Privacy",
                            description: "Your data stays private, always"
                        )
                        FeatureRow(
                            icon: "number",
                            iconColor: Color(
                                red: 0.45,
                                green: 0.65,
                                blue: 0.90
                            ),
                            iconBackground: Color(
                                red: 0.75,
                                green: 0.87,
                                blue: 0.97
                            ),
                            title: "Aggregation",
                            description:
                                "Aggregate your data to have a better overview"
                        )
                        FeatureRow(
                            icon: "bolt.fill",
                            iconColor: Color(
                                red: 0.90,
                                green: 0.55,
                                blue: 0.20
                            ),
                            iconBackground: Color(
                                red: 0.99,
                                green: 0.87,
                                blue: 0.70
                            ),
                            title: "Priority Support",
                            description: "Get fast help whenever you need it"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Utility buttons
                    VStack(spacing: 12) {
                        PaywallActionButton(
                            isLoading: store.restoreInProgress,
                            isDisabled: store.restoreInProgress
                                || store.purchaseInProgress,
                            background: .paywallDarkButton,
                            accessibilityLabel: "Restore Purchases",
                            action: { Task { await restore() } }
                        ) {
                            Label(
                                "Restore Purchases",
                                systemImage: "arrow.counterclockwise"
                            )
                            .font(.headline)
                            .foregroundStyle(.white)
                        }

                        Button(action: contactSupport) {
                            Label("Contact Support", systemImage: "envelope")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            Color.primary.opacity(0.2),
                                            lineWidth: 1.5
                                        )
                                )
                        }

                        VStack(spacing: 4) {
                            Text(userId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)

                            Button(action: {
                                UIPasteboard.general.string = userId
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }
            }

            Divider()

            VStack(spacing: 12) {
                PaywallActionButton(
                    isLoading: store.purchaseInProgress,
                    isDisabled: selectedProduct == nil
                        || store.purchaseInProgress || store.restoreInProgress,
                    background: .paywallAccent,
                    accessibilityLabel: ctaLabel,
                    action: {
                        guard let product = selectedProduct else { return }
                        Task {
                            if await store.purchase(product) { dismiss() }
                        }
                    }
                ) {
                    Label(ctaLabel, systemImage: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Text(footerText)
                    .font(.callout)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .background(Color(.systemBackground))

        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
        .trackScreen("Paywall")
        .task {
            // Retry if the launch-time load failed, so the paywall shows live
            // prices instead of stale placeholders. Resolve eligibility too if it
            // never ran (no products at launch), so the CTA settles on its final
            // label once products arrive.
            if store.products.isEmpty { await store.loadProducts() }
            if !store.hasResolvedIntroEligibility {
                await store.refreshIntroEligibility()
            }
        }
        .alert(
            "store.error.title",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            ),
            presenting: store.lastError
        ) { _ in
            Button("store.error.dismiss", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "")
        }
        .alert(
            "paywall.restore.empty.title",
            isPresented: $showNothingToRestore
        ) {
            Button("store.error.dismiss", role: .cancel) {}
        } message: {
            Text("paywall.restore.empty.message")
        }
    }
}

/// The shared full-width action button used for both the primary CTA and the
/// "Restore Purchases" row: a 54pt rounded bar that swaps its label for a
/// spinner while loading and greys out when disabled, keeping its VoiceOver
/// name in both states.
private struct PaywallActionButton<Content: View>: View {
    let isLoading: Bool
    let isDisabled: Bool
    let background: Color
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    content()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isDisabled ? Color(.systemGray3) : background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel(accessibilityLabel)
        }
        .disabled(isDisabled)
    }
}

extension Color {
    /// The paywall's brand accent (warm red), used for the primary CTA.
    fileprivate static let paywallAccent = Color(
        red: 0.90,
        green: 0.38,
        blue: 0.32
    )

    /// The dark neutral fill for secondary actions like "Restore Purchases".
    fileprivate static let paywallDarkButton = Color(
        red: 0.20,
        green: 0.20,
        blue: 0.20
    )
}

private struct PlanCard: View {
    let emoji: String
    let title: LocalizedStringKey
    let price: String?
    let discount: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(emoji)
                        .font(.title)
                        .padding(10)

                    Spacer()

                    if let discount {
                        Text(discount)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                Color(red: 0.20, green: 0.55, blue: 0.20)
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color(red: 0.78, green: 0.95, blue: 0.70)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Spacer().frame(height: 20)

                HStack(spacing: 6) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(
                                Color(red: 0.40, green: 0.75, blue: 0.35)
                            )
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                // Wider stand-in so the redacted bar reads as a price while
                // products load, instead of a thin dash.
                Text(price ?? "$00.00")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .redacted(reason: price == nil ? .placeholder : [])
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? Color.primary : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: LocalizedStringKey
    var badge: String? = nil
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBackground)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    @Previewable @State var showSheet = true

    NavigationStack {}
        .sheet(isPresented: $showSheet) {
            PaywallView()
                .environment(Store())
        }
        .presentationDetents([.large])
        .environment(\.locale, Locale(identifier: "en"))
}
