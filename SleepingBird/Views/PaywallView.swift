import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var selectedPlan: Store.Plan = .yearly
    @State private var selectedSharing: Sharing = .single
    @Environment(\.dismiss) private var dismiss

    private let anonymousID = "$RCAnonymousID:0110333ef6a440c89beafb82647556f2"

    enum Sharing { case single, family }

    private var selectedProduct: Product? { store.product(for: selectedPlan) }

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
            localized: "paywall.footer.price_unit \(product.displayPrice) \(unit)"
        )
    }

    private func contactSupport() {
        guard let url = SupportMailLink(anonymousID: anonymousID).url else { return }
        openURL(url)
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
                    //                    Text("What you get")
                    //                        .font(.title2)
                    //                        .padding()

                    // Feature rows
                    VStack(spacing: 12) {
                        FeatureRow(
                            icon: "mic",
                            iconColor: Color(
                                red: 0.90,
                                green: 0.38,
                                blue: 0.32
                            ),
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
                        Button(action: { Task { await store.restore() } }) {
                            Label(
                                "Restore Purchases",
                                systemImage: "arrow.counterclockwise"
                            )
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                Color(red: 0.20, green: 0.20, blue: 0.20)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            Text(anonymousID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)

                            Button(action: {}) {
                                Text("Copy")
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
                Button(action: {
                    guard let product = selectedProduct else { return }
                    Task {
                        if await store.purchase(product) { dismiss() }
                    }
                }) {
                    Group {
                        if store.purchaseInProgress {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("paywall.cta.free_trial", systemImage: "arrow.right")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(red: 0.90, green: 0.38, blue: 0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(selectedProduct == nil || store.purchaseInProgress)

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
    }
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))

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

                Text(price ?? "—")
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

private struct SharingButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    isSelected
                        ? Color(red: 0.20, green: 0.20, blue: 0.20)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(3)
        }
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
        .environment(\.locale, Locale(identifier: "fr"))
}
