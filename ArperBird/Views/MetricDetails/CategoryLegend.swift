//
//  CategoryLegend.swift
//  ArperBird
//
//  The interactive legend beneath a category calendar: one chip per choice,
//  each carrying that choice's stable color. Tapping a chip toggles whether the
//  choice is shown in the calendar's pies. This view is *controlled* — it owns
//  no visibility state. The active set flows in and toggle intents flow out, so
//  the calendar and the legend read the same source of truth (held by the
//  enclosing detail view) and can never disagree about what's shown.
//
//  Pair with the category `CalendarScrollView` / `DayPieFill`, which paint the
//  same colors for the same active choices.
//

import SwiftUI

struct CategoryLegend: View {
    struct Item: Identifiable {
        /// The choice label — also its stable identity and toggle key.
        let label: String
        /// The choice's fixed color, matching its wedge in the calendar.
        let color: Color
        var id: String { label }
    }

    /// Every choice, in stable list order. Colors never re-map on toggle.
    let items: [Item]
    /// Labels currently shown in the calendar. Chips outside this set read dimmed.
    let active: Set<String>
    /// Fired when a chip is tapped; the owner applies the toggle to its state.
    let onToggle: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHOWING \(active.count) OF \(items.count)")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.tertiary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    LegendChip(
                        label: item.label,
                        dot: item.color,
                        isActive: active.contains(item.label)
                    ) {
                        onToggle(item.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A tappable labeled choice. Full brightness when active, dimmed when not. The
/// dot always shows the choice's stable color, so color memory holds as the user
/// toggles others.
private struct LegendChip: View {
    let label: String
    let dot: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dot)
                    .overlay(
                        Circle()
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                    )
                    .frame(width: 14, height: 14)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
            .opacity(isActive ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isActive ? "Shown" : "Hidden")
        .accessibilityHint("Toggles whether this choice appears in the calendar")
    }
}

#Preview {
    struct Demo: View {
        private let labels = [
            "Work", "Sleep", "Exercise", "Reading",
            "Social", "Chores", "Meditation",
        ]
        private var items: [CategoryLegend.Item] {
            let colors = CategoryPalette.colors(for: labels)
            return labels.map { .init(label: $0, color: colors[$0] ?? .gray) }
        }
        @State private var active: Set<String> = ["Work", "Sleep", "Exercise"]

        var body: some View {
            CategoryLegend(items: items, active: active) { label in
                active.formSymmetricDifference([label])
            }
            .padding()
        }
    }
    return Demo()
}
