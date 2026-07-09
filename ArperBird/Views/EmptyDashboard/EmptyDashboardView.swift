//
//  EmptyDashboardView.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import SwiftUI

/// The empty-state dashboard, redesigned to the "minimal" direction in
/// [decision 0006]: a soft glyph, a centered gradient headline, the field as the
/// primary CTA, and the kept suggestion chips — all over the sunrise background
/// that `ContentView` supplies (kept shared, not applied here).
///
/// Every entry point routes through `onAddMetric`: the field CTA opens the
/// creation flow from scratch (`nil`) so a tap lands straight in typing, and a
/// chip opens it seeded with that pick. The chips read as fillable examples of
/// what to type — a "Try one:" label names them, and a tight sub-block binds the
/// field → label → chips by proximity.
///
/// Layout knobs live in `Tuning`; every piece is its own `@ViewBuilder`.
struct EmptyDashboardView: View {
    /// Opens the creation flow — seeded with the tapped suggestion, or from
    /// scratch (`nil`) via the field CTA.
    let onAddMetric: (TrackerSuggestion?) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var promptIndex = 0

    /// All the spacings / sizes / copy in one place so the layout can be dialed
    /// in without hunting through the view tree.
    private enum Tuning {
        static let outerSpacing: CGFloat = 24
        static let glyphDash: [CGFloat] = [5, 5]
        static let chipRows = 3

        static let subcopy = "Type it in plain words — we'll build the tracker for you."
        static let glyph = "📈"

        // Connective copy above the chips.
        static let examplesLabel = "Try one:"

        /// Spacing inside the tight sub-block (field → label → chips) so
        /// proximity binds them together.
        static let tightGroupSpacing: CGFloat = 20

        // Chip sizing — smaller than `BadgesStackView`'s defaults so the chips
        // read as lightweight examples, not primary buttons.
        static let chipFont: Font = .footnote
        static let chipInnerPadding: Double = 5
        static let chipCornerRadius: Double = 12
    }

    /// The curated suggestion chips — the same source `TrackerIntentView` samples
    /// from. Shown in full (not a clipped few) so the field's range of ideas reads.
    private let suggestions = TrackerSuggestion.defaults

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .trackScreen("EmptyDashboard")
    }

    // MARK: - Layout

    private var content: some View {
        // Headline/glyph keep the full outer rhythm, but the field, label, and
        // chips collapse into one tight sub-block: the label names the chips as
        // examples while the small spacing binds them to the field by
        // proximity — no container box.
        VStack(spacing: Tuning.outerSpacing) {
            Spacer()
            softGlyph
            headline
            subcopy
            VStack(spacing: Tuning.tightGroupSpacing) {
                inputFieldCTA
                labeledBadges(Tuning.examplesLabel)
            }
            Spacer()
        }
    }

    // MARK: - Blocks

    /// The two-line gradient headline.
    private var headline: some View {
        VStack(spacing: 0) {
            Text("What do you")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("want to track?")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(headlineGradient)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var subcopy: some View {
        Text(Tuning.subcopy)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// THE primary CTA: a field-shaped button. Answers "what happens on tap?"
    /// (I'll type) — and it mirrors the intent screen's field, down to the
    /// rotating "Track …" examples (kept in sync via
    /// `TrackerIntentView.examplePrompts`), while keeping the `sparkles` glyph.
    /// It stays a launcher, not a real input: a tap opens the creation flow from
    /// scratch, which auto-focuses its field, so the keyboard is up and the real
    /// typing happens in one place.
    private var inputFieldCTA: some View {
        Button(action: { onAddMetric(nil) }) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("Track")
                    Text(TrackerIntentView.examplePrompts[promptIndex])
                        .id(promptIndex)
                        .transition(
                            reduceMotion ? .opacity : .push(from: .bottom)
                        )
                }
                .foregroundStyle(Color(.placeholderText))
                .clipped()
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.snappy) {
                    promptIndex =
                        (promptIndex + 1) % TrackerIntentView.examplePrompts.count
                }
            }
        }
    }

    /// A connective label + the kept chips, stacked. The label is what ties the
    /// chips to the field ("these are things you could type").
    private func labeledBadges(_ label: String) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            badges
        }
    }

    /// The kept chips. A tap seeds the creation flow with that suggestion.
    private var badges: some View {
        BadgesStackView(
            badges: suggestions.map(\.chipText),
            innerPadding: Tuning.chipInnerPadding,
            borderThickness: 0.5,
            cornerRadius: Tuning.chipCornerRadius,
            alignment: .center,
            maxRows: Tuning.chipRows,
            onTap: { index in onAddMetric(suggestions[index]) }
        )
        .font(Tuning.chipFont)
    }

    /// A single soft glyph in a dashed frame — no data claim.
    private var softGlyph: some View {
        Text(Tuning.glyph)
            .font(.system(size: 44))
            .frame(width: 96, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        Color.secondary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1, dash: Tuning.glyphDash)
                    )
            )
    }

    // MARK: - Styling helpers

    private var headlineGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf4 / 255),
                   Color(red: 0xa1 / 255, green: 0xb7 / 255, blue: 0xf6 / 255)]
                : [Color(red: 0x64 / 255, green: 0x6c / 255, blue: 0xf6 / 255),
                   Color(red: 0xc2 / 255, green: 0x5d / 255, blue: 0xdd / 255)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    EmptyDashboardView(onAddMetric: { _ in })
        .background { EmptyDashboardBackground() }
        .environment(\.locale, Locale(identifier: "en_US"))
}
