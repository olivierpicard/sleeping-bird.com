//
//  TermsAndPrivacyView.swift
//  ArperBird
//
//  Created by Olivier Picard on 29/05/2026.
//

import SwiftUI

/// Scrollable legal document presenting the app's Terms of Service and
/// Privacy Policy. Designed to be shown as a sheet from onboarding or settings.
struct TermsAndPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Which document to scroll to first when presented.
    var initialSection: Section = .terms

    enum Section: Hashable {
        case terms
        case privacy
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        header

                        termsSection
                            .id(Section.terms)

                        Divider()

                        privacySection
                            .id(Section.privacy)

                        footer
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onAppear {
                    if initialSection != .terms {
                        proxy.scrollTo(initialSection, anchor: .top)
                    }
                }
            }
            .navigationTitle("Terms & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Done", systemImage: "xmark")
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arper Bird")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(brandGradient)

            Text("Last updated \(Self.lastUpdated)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf4 / 255),
                    Color(red: 0xa1 / 255, green: 0xb7 / 255, blue: 0xf6 / 255),
                ]
                : [
                    Color(red: 0x64 / 255, green: 0x6c / 255, blue: 0xf6 / 255),
                    Color(red: 0xc2 / 255, green: 0x5d / 255, blue: 0xdd / 255),
                ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: Terms

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Terms of Service", systemImage: "doc.text")

            paragraph(
                "By using Arper Bird you agree to these terms. The app lets you describe metrics you want to track, interprets your description with AI, and renders charts to help you visualize your personal data."
            )

            subsection(
                "Acceptable use",
                "You are responsible for the content you create. Don't use the app to store unlawful material or to infringe the rights of others."
            )

            subsection(
                "Your content",
                "The metrics and data points you record belong to you. We don't claim ownership over anything you track."
            )

            subsection(
                "Free and Premium",
                "Arper Bird is free to use for your first tracker. Creating more trackers requires Premium, which unlocks unlimited trackers."
            )

            subsection(
                "Subscriptions and free trial",
                "Premium is an auto-renewing subscription billed through your App Store account. New subscribers start with a 1-week free trial: unless you cancel at least 24 hours before it ends, it turns into a paid subscription at the price shown at checkout, and renews each period until you cancel. You can view, change, or cancel it anytime in your device's App Store settings."
            )

            subsection(
                "Disclaimer",
                "Arper Bird is provided \u{201C}as is.\u{201D} It is not a medical, financial, or professional advice tool. Decisions you make based on your tracked data are your own."
            )
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Privacy Policy", systemImage: "lock.shield")

            paragraph(
                "We designed Arper Bird to keep your data private. Your metrics live on your device — we don't run accounts or upload your tracked data to our own servers. Here's what leaves your device, and to whom."
            )

            subsection(
                "Data stored on your device",
                "The values you record, your metric names, and your descriptions are stored locally on your device using Apple's on-device database. They never leave your device, and we never receive a copy of them."
            )

            subsection(
                "AI interpretation (Google Firebase / Gemini)",
                "When you describe what you want to track, that text is sent to Google's Gemini model via Firebase AI, which turns it into a tracker: a name, emoji, format, unit, and suggested options. Only what you type and the tracker settings you're editing are sent — never the values you log. AI suggestions aren't perfect and may occasionally misread you, so everything it proposes stays editable before you save."
            )

            subsection(
                "Subscriptions (RevenueCat & App Store)",
                "If you subscribe, your purchase is processed by Apple's App Store and validated through RevenueCat. They handle billing; we don't see your payment details."
            )

            subsection(
                "Analytics & crash reports (PostHog)",
                "We use PostHog, hosted in the EU, to understand how the app is used and to receive crash reports so we can fix bugs. This covers how you move through the app — which suggestions you tap, how far you get while creating a tracker, which defaults you change — and the shape of the trackers you create: their type, chart, units, and any category labels you define. It never includes the values you log, your tracker names, or the text you type; where the length of what you typed is useful, only that number is sent. Events are tied to a random identifier generated on your device — not to your name, email, or Apple ID."
            )

            subsection(
                "Your anonymous identifier",
                "To keep analytics and subscriptions consistent across reinstalls, we store a random identifier in your device's Keychain. It contains no personal information and is never linked to your real identity."
            )

            subsection(
                "What we don't do",
                "We don't sell your data, and we don't use your tracked metrics for advertising."
            )

            subsection(
                "Contact",
                "Questions about your privacy? Reach us at \(SupportMailLink.address)."
            )
        }
    }

    // MARK: Footer

    private var footer: some View {
        Text("Thanks for trusting us with your data.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }

    // MARK: Building blocks

    private func sectionTitle(_ title: LocalizedStringKey, systemImage: String)
        -> some View
    {
        Label(title, systemImage: systemImage)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
    }

    private func subsection(_ title: LocalizedStringKey, _ body: LocalizedStringKey)
        -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            paragraph(body)
        }
    }

    private func paragraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static let lastUpdated: String = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(
            from: Date(timeIntervalSince1970: 1_785_024_000)
        )  // 2026-07-26
    }()
}

#Preview {
    TermsAndPrivacyView()
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Privacy first") {
    TermsAndPrivacyView(initialSection: .privacy)
}

#Preview("Dark") {
    TermsAndPrivacyView()
        .preferredColorScheme(.dark)
}
