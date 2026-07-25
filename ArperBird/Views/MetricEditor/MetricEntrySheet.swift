//
//  MetricEntrySheet.swift
//  ArperBird
//
//  Created by Olivier Picard on 25/07/2026.
//

import SwiftUI

/// Wraps a metric's editor with the date row that lets an entry be backdated.
///
/// See [decision 0009](../../../docs/decisions/0009-backdated-entries.md). The
/// editors themselves stay unaware of dates: this view owns the chosen day and
/// `MetricInputFactory` stamps it onto the `DataPoint`.
///
/// The wheel *expands the sheet* rather than replacing its body, and that isn't
/// cosmetic — every editor keeps its in-progress value in its own `@State`
/// (`_StepperEditor.value`), so swapping the editor out of the view tree while
/// picking a day would silently reset whatever the user had dialled in.
struct MetricEntrySheet: View {
    let metric: Metric
    let onAdd: (DataPoint) -> Void

    /// The day the entry defaults to — "today" unless the caller seeded it
    /// from an already-selected day, e.g. a tapped calendar cell in
    /// `MetricDetailView`.
    private let initialDate: Date

    @Environment(\.colorScheme) private var colorScheme

    /// Whole days before today. `0` is today — the default, and the path almost
    /// every entry takes.
    @State private var daysBack: Int
    @State private var isPickingDay = false
    @State private var detent: PresentationDetent

    /// How far back the drum reaches. A year covers backfilling without turning
    /// the wheel into an endless spin.
    private static let maxDaysBack = 365
    private static let rowHeight: CGFloat = 56
    private static let topPadding: CGFloat = 30
    private static let wheelHeight: CGFloat = 180

    /// Drum labels, built once per presentation: the text depends on today's
    /// date, and formatting 366 of them on every re-render would be wasteful.
    private let dayLabels: [String]

    init(metric: Metric, initialDate: Date = Date(), onAdd: @escaping (DataPoint) -> Void) {
        self.metric = metric
        self.initialDate = initialDate
        self.onAdd = onAdd
        self.dayLabels = (0...Self.maxDaysBack).map(Self.dayLabel(daysBack:))
        _daysBack = State(initialValue: Self.daysBack(for: initialDate))
        _detent = State(initialValue: .height(Self.collapsedHeight(for: metric)))
    }

    private var mainColor: Color { metric.displayColor(in: colorScheme) }

    var body: some View {
        if metric.config.picksItsOwnDate {
            // `.datetime` metrics already choose an arbitrary date *and* time as
            // their value, so a day row above would be a second, conflicting
            // date control.
            MetricInputFactory.make(
                from: metric,
                in: colorScheme,
                date: { initialDate },
                onAdd: onAdd
            )
            .presentationDetents([
                .height(MetricInputFactory.editorHeight(for: metric))
            ])
        } else {
            datedEditor
        }
    }

    private var datedEditor: some View {
        VStack(spacing: 0) {
            _EntryDateRow(
                daysBack: $daysBack,
                isPickingDay: $isPickingDay,
                maxDaysBack: Self.maxDaysBack,
                label: dayLabels[daysBack],
                isAlreadyLogged: selectedDayHasEntry,
                mainColor: mainColor
            )
            .frame(height: Self.rowHeight)
            .padding(.top, Self.topPadding)

            if isPickingDay {
                dayWheel
            }

//            Divider()
//                .padding(.horizontal)

            MetricInputFactory.make(
                from: metric,
                in: colorScheme,
                date: { stampedDate },
                onAdd: onAdd
            )
        }
        .animation(.snappy, value: isPickingDay)
        .presentationDetents(detents, selection: $detent)
        .onChange(of: isPickingDay) { _, expanded in
            detent = .height(
                expanded
                    ? Self.expandedHeight(for: metric)
                    : Self.collapsedHeight(for: metric)
            )
        }
    }

    /// One drum of days, oldest at the top and today at the bottom — so "no
    /// future" is a physical end to the wheel rather than a rule to enforce.
    /// A stock `DatePicker(.wheel)` was the alternative, but its day/month/year
    /// drums can express invalid dates and make "yesterday" a three-drum job.
    private var dayWheel: some View {
        Picker("", selection: $daysBack) {
            ForEach((0...Self.maxDaysBack).reversed(), id: \.self) { offset in
                Text(dayLabels[offset]).tag(offset)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(height: Self.wheelHeight)
        .padding(.horizontal)
    }

    // MARK: - Dates

    /// Today keeps the real clock time, exactly as before this screen existed.
    /// A backdated day is stamped at **noon**: midnight sits on the day
    /// boundary, where a timezone or DST shift can slide the point into the
    /// neighbouring day and onto the wrong chart bar.
    private var stampedDate: Date {
        guard daysBack > 0 else { return Date() }
        let day = Self.day(daysBack: daysBack)
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day)
            ?? day
    }

    private var selectedDayHasEntry: Bool {
        let day = Self.day(daysBack: daysBack)
        return metric.data.contains {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
    }

    private static func day(daysBack: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
    }

    /// Inverse of `day(daysBack:)`: how many whole days before today `date`
    /// falls on, clamped to the wheel's range. A future date (shouldn't
    /// happen, but the calendar can't rule it out) clamps to today.
    private static func daysBack(for date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: date)
        let offset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        return min(max(offset, 0), maxDaysBack)
    }

    /// Shortest text that still identifies the day: words for the two most
    /// common cases, a weekday for the rest of the week, and a year only once
    /// it stops being the current one.
    private static func dayLabel(daysBack: Int) -> String {
        switch daysBack {
        case 0: return String(localized: "metric_entry.date.today")
        case 1: return String(localized: "metric_entry.date.yesterday")
        default: break
        }
        let day = self.day(daysBack: daysBack)
        if daysBack < 7 {
            return day.formatted(
                .dateTime.weekday(.abbreviated).day().month(.abbreviated)
            )
        }
        let calendar = Calendar.current
        if calendar.isDate(day, equalTo: Date(), toGranularity: .year) {
            return day.formatted(.dateTime.day().month(.abbreviated))
        }
        return day.formatted(.dateTime.day().month(.abbreviated).year())
    }

    // MARK: - Detents

    private var detents: Set<PresentationDetent> {
        var detents: Set<PresentationDetent> = [
            .height(Self.collapsedHeight(for: metric)),
            .height(Self.expandedHeight(for: metric)),
        ]
        if MetricInputFactory.allowsMediumDetent(for: metric) {
            detents.insert(.medium)
        }
        return detents
    }

    private static func collapsedHeight(for metric: Metric) -> CGFloat {
        MetricInputFactory.editorHeight(for: metric) + rowHeight + topPadding
    }

    private static func expandedHeight(for metric: Metric) -> CGFloat {
        collapsedHeight(for: metric) + wheelHeight
    }
}

// MARK: - Date row

/// `◂  Today  ▸` — steps a day at a time, and opens the wheel when the label
/// itself is tapped.
private struct _EntryDateRow: View {
    @Binding var daysBack: Int
    @Binding var isPickingDay: Bool
    let maxDaysBack: Int
    let label: String
    let isAlreadyLogged: Bool
    let mainColor: Color

    var body: some View {
        HStack(spacing: 4) {
            stepButton(
                "metric_entry.date.previous_day",
                systemImage: "chevron.left",
                enabled: daysBack < maxDaysBack
            ) {
                daysBack += 1
            }

            Button(action: { isPickingDay.toggle() }) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    if isAlreadyLogged {
                        Circle()
                            .fill(mainColor)
                            .frame(width: 5, height: 5)
                    }
                    Image(systemName: isPickingDay ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            stepButton(
                "metric_entry.date.next_day",
                systemImage: "chevron.right",
                enabled: daysBack > 0
            ) {
                daysBack -= 1
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: daysBack)
        .sensoryFeedback(.selection, trigger: daysBack)
        // One control to VoiceOver, adjustable by swiping up/down, rather than
        // three separate buttons to hunt through.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("metric_entry.date.accessibility_label"))
        .accessibilityValue(
            isAlreadyLogged
                ? "\(label), \(String(localized: "metric_entry.date.already_logged"))"
                : label
        )
        .accessibilityHint(Text("metric_entry.date.accessibility_hint"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where daysBack > 0: daysBack -= 1
            case .decrement where daysBack < maxDaysBack: daysBack += 1
            default: break
            }
        }
        .accessibilityAction { isPickingDay.toggle() }
    }

    private func stepButton(
        _ label: LocalizedStringKey,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? mainColor : .secondary)
                .frame(width: 44, height: 44)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .contentShape(.rect)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

// MARK: - Config helpers

extension MetricConfig {
    /// `.datetime`'s value *is* a date, so it needs no day row bolted on top.
    fileprivate var picksItsOwnDate: Bool {
        if case .datetime = self { return true }
        return false
    }
}

// MARK: - Previews

/// Stepper-sized number metric with two weeks of history, so the "already
/// logged" dot has something to mark.
private func previewMetric(_ schema: MetricSchema) -> Metric {
    Metric(from: schema, data: Metric.fakeData(for: schema.config))
}

#Preview("Number — stepper") {
    @Previewable @State var isPresented = true
    Text(verbatim: "")
        .sheet(isPresented: $isPresented) {
            MetricEntrySheet(
                metric: previewMetric(
                    .Fake.number(
                        title: "Water",
                        emoji: "💧",
                        unit: "glasses",
                        min: 0,
                        max: 10,
                        granularity: 1,
                        goal: 8
                    )
                ),
                onAdd: { _ in }
            )
        }
}

#Preview("Binary") {
    @Previewable @State var isPresented = true
    Text(verbatim: "")
        .sheet(isPresented: $isPresented) {
            MetricEntrySheet(
                metric: previewMetric(.Fake.binary()),
                onAdd: { _ in }
            )
        }
}

#Preview("Datetime — no date row") {
    @Previewable @State var isPresented = true
    Text(verbatim: "")
        .sheet(isPresented: $isPresented) {
            MetricEntrySheet(
                metric: previewMetric(.Fake.datetime()),
                onAdd: { _ in }
            )
        }
}
