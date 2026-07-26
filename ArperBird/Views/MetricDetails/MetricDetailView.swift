//
//  MetricDetailView.swift
//  ArperBird
//
//  Created by Olivier Picard on 03/05/2026.
//

import Charts
import PostHog
import SwiftUI

struct MetricDetailView: View {
    let metric: Metric

    @Environment(\.colorScheme) private var colorScheme

    /// The metric's color corrected for readability — the single shade the glow,
    /// chart, calendar tints, and value labels all draw from, matching the card
    /// on the dashboard and the tracker-creation reveal.
    private var tint: Color {
        metric.displayColor(in: colorScheme)
    }

    @State private var range: TimeRange = .month
    @State private var selectedDate: Date?
    @State private var bins: [ChartBin] = []
    @State private var categoryEntries: [StackedBarChartView.Entry] = []
    /// Day (start-of-day) → the choice labels logged that day, for the category
    /// calendar's pies. Recomputed alongside the other derived render state.
    @State private var categoryDayLabels: [Date: [String]] = [:]
    /// Choice labels currently shown in the category calendar. Seeded to all,
    /// then toggled by the legend. The single source of truth both the calendar
    /// and the legend read, so they can't disagree about what's shown.
    @State private var activeCategoryLabels: Set<String> = []
    /// Guards the one-time seed of `activeCategoryLabels` so a re-appear never
    /// wipes the user's toggles.
    @State private var hasSeededCategory = false
    @State private var numberFilledDays: Set<Date> = []
    /// Programmatic scroll target for the calendar — written by the chevrons to
    /// scroll to a specific month.
    @State private var displayedMonth: Date?
    /// Live position of the calendar in month units (0 = first month), updated
    /// continuously as the calendar is swiped. Single source of truth the month
    /// selector renders from, so a mid-swipe shows a mid-slide.
    @State private var monthProgress: Double = 0
    @State private var isEditing: Bool = false
    @State private var isAddingEntry: Bool = false

    /// Chart vs. calendar view for number, duration, and category metrics.
    private enum ChartMode { case chart, calendar }
    @State private var chartMode: ChartMode = .chart

    private func recomputeBins() {
        bins = MetricAggregator.bins(
            from: metric.data,
            range: range,
            method: metric.visual.aggregation.method.numeric,
            behavior: metric.config.behavior
        )
    }

    private func recomputeCategoryEntries() {
        categoryEntries = MetricAggregator.categoryEntries(
            from: metric.data,
            range: range
        )
    }

    /// Groups category entries by day into the union of their labels — the
    /// per-day choice set the calendar's pies draw from.
    private func recomputeCategoryDays() {
        let cal = Calendar.current
        var map: [Date: Set<String>] = [:]
        for point in metric.data {
            if case .category(let date, let labels) = point {
                map[cal.startOfDay(for: date), default: []].formUnion(labels)
            }
        }
        categoryDayLabels = map.mapValues { Array($0) }
    }

    /// Binary "true"/"false" days, derived live from `metric.data` (not cached
    /// `@State`) — the binary and datetime calendars are mounted unconditionally
    /// on the first render, before `.onAppear` runs, so caching these in `@State`
    /// left every cell showing its empty "no entry" ring until some later
    /// transaction (e.g. tapping a cell) forced a repaint.
    private var filledDays: Set<Date> {
        let cal = Calendar.current
        var set: Set<Date> = []
        for point in metric.data {
            if case .binary(let date, true) = point {
                set.insert(cal.startOfDay(for: date))
            }
        }
        return set
    }

    private var falseDays: Set<Date> {
        let cal = Calendar.current
        var set: Set<Date> = []
        for point in metric.data {
            if case .binary(let date, false) = point {
                set.insert(cal.startOfDay(for: date))
            }
        }
        return set
    }

    /// See `filledDays` — same live-derivation reasoning applies to the
    /// datetime calendar.
    private var datetimeFilledDays: Set<Date> {
        let cal = Calendar.current
        var set: Set<Date> = []
        for point in metric.data {
            if case .datetime(let date) = point {
                set.insert(cal.startOfDay(for: date))
            }
        }
        return set
    }

    private func recomputeNumberFilledDays() {
        let cal = Calendar.current
        var set: Set<Date> = []
        for point in metric.data {
            switch point {
            case .number(let date, _), .duration(let date, _):
                set.insert(cal.startOfDay(for: date))
            default:
                break
            }
        }
        numberFilledDays = set
    }

    private var isBinary: Bool {
        if case .binary = metric.config { return true }
        return false
    }

    private var isDatetime: Bool {
        if case .datetime = metric.config { return true }
        return false
    }

    private var isCategory: Bool {
        switch metric.config {
        case .categorySingleChoice, .categoryMultipleChoice: return true
        default: return false
        }
    }

    /// The metric's declared choice labels in stable order — the basis for both
    /// color assignment and the legend. Empty for non-category metrics.
    private var orderedCategoryChoices: [String] {
        switch metric.config {
        case .categorySingleChoice(let cfg), .categoryMultipleChoice(let cfg):
            return cfg.labels
        default:
            return []
        }
    }

    /// Stable label → color, shared identically by the calendar pies and the
    /// legend so a wedge always matches its chip.
    private var categoryColorMap: [String: Color] {
        CategoryPalette.colors(for: orderedCategoryChoices)
    }

    /// The legend's rows: every choice paired with its stable color.
    private var categoryLegendItems: [CategoryLegend.Item] {
        orderedCategoryChoices.map {
            .init(label: $0, color: categoryColorMap[$0] ?? .gray)
        }
    }

    /// Toggles a choice's visibility in the calendar. No cap — every choice is
    /// independently on/off.
    private func toggleCategory(_ label: String) {
        withAnimation(.snappy) {
            activeCategoryLabels.formSymmetricDifference([label])
        }
    }

    private var displayedCategoryBucket: Date? {
        let calendar = Calendar.current
        let dates = Array(Set(categoryEntries.map(\.date))).sorted()
        guard !dates.isEmpty else { return nil }
        if let selectedDate {
            return dates.first {
                calendar.isDate(
                    $0,
                    equalTo: selectedDate,
                    toGranularity: range.bucketComponent
                )
            } ?? dates.last
        }
        return dates.last
    }

    private var displayedCategorySummary: (label: String, count: Int)? {
        guard let bucket = displayedCategoryBucket else { return nil }
        let calendar = Calendar.current
        let inBucket = categoryEntries.filter {
            calendar.isDate(
                $0.date,
                equalTo: bucket,
                toGranularity: range.bucketComponent
            )
        }
        guard let top = inBucket.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return (top.label, Int(top.value))
    }

    private var binaryConfig: BinaryConfig? {
        if case .binary(let cfg) = metric.config { return cfg }
        return nil
    }

    private var displayedBinaryValue: Bool? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: selectedDate ?? Date())
        let entries = metric.data.compactMap { $0.binaryValue }
            .filter { cal.isDate($0.date, inSameDayAs: target) }
        return entries.max(by: { $0.date < $1.date })?.value
    }

    private var sortedEntries: [DataPoint] {
        metric.data.sorted { lhs, rhs in
            date(of: lhs) > date(of: rhs)
        }
    }

    private var displayedBin: ChartBin? {
        if let selectedDate {
            let calendar = Calendar.current
            return bins.first {
                calendar.isDate(
                    $0.date,
                    equalTo: selectedDate,
                    toGranularity: range.bucketComponent
                )
            } ?? bins.last
        }
        return bins.last
    }

    var body: some View {
        Group {
            if metric.data.isEmpty {
                emptyState
            } else {
                populatedList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingEntry = true
                } label: {
                    Label("Add entry", systemImage: "plus")
                }
                .tint(tint)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isEditing = true }) {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                    .tint(tint)
            }
        }
        .sheet(isPresented: $isEditing) {
            MetricEditSheet(metric: metric) 
        }
        .sheet(isPresented: $isAddingEntry) {
            MetricEntrySheet(metric: metric, initialDate: selectedDate ?? Date()) { point in
                try? metric.append(point)
                isAddingEntry = false
                PostHogSDK.shared.capture(
                    "entry_added",
                    properties: [
                        "via": "details",
                        "days_back": point.daysBack,
                    ]
                )
            }
            .trackScreen("AddEntry")
        }
        .onAppear {
            recomputeBins()
            recomputeNumberFilledDays()
            recomputeCategoryEntries()
            recomputeCategoryDays()
            // Seed the legend with every choice shown, once. Category metrics
            // also open on the calendar rather than the chart.
            if isCategory, !hasSeededCategory {
                activeCategoryLabels = Set(orderedCategoryChoices)
                chartMode = .calendar
                hasSeededCategory = true
            }
            // Calendar opens anchored to the latest (trailing) month.
            monthProgress = Double(max(calendarMonths.count - 1, 0))
        }
        .onChange(of: range) { _, _ in
            selectedDate = nil
            recomputeBins()
            recomputeCategoryEntries()
        }
        .onChange(of: metric.data.count) { _, _ in
            recomputeBins()
            recomputeNumberFilledDays()
            recomputeCategoryEntries()
            recomputeCategoryDays()
        }
        .trackScreen(
            "MetricDetail",
            ["chart": metric.visual.chart.rawValue]
        )
    }

    // MARK: - Populated List

    private var populatedList: some View { 
        List {
            Section {
                VStack(spacing: 24) {
                    header

                    Group {
                        if isBinary {
                            binaryCalendarSection
                                .padding(.top)
                        } else if isDatetime {
                            datetimeCalendarSection
                                .padding(.top)
                        } else if isCategory {
                            HStack(spacing: 12) {
                                if chartMode == .calendar {
                                    monthSelector
                                } else {
                                    rangePicker
                                }
                                chartModeToggle
                            }
                            if chartMode == .calendar {
                                categoryCalendarSection
                                CategoryLegend(
                                    items: categoryLegendItems,
                                    active: activeCategoryLabels,
                                    onToggle: toggleCategory
                                )
                            } else {
                                categoryChartSection
                            }
                        } else {
                            HStack(spacing: 12) {
                                if chartMode == .calendar {
                                    monthSelector
                                } else {
                                    rangePicker
                                }
                                chartModeToggle
                            }
                            if chartMode == .calendar {
                                numberCalendarSection
                            } else {
                                chartSection
                            }
                        }
                    }
                }
                .listRowInsets(
                    EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            recentEntries
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyStateSymbol: String {
        switch metric.visual.chart {
        case .line: return "chart.xyaxis.line"
        case .bar: return "chart.bar.fill"
        case .pie: return "chart.pie.fill"
        case .calendar: return "calendar"
        case .dailyGauge: return "gauge.with.dots.needle.bottom.50percent"
        }
    }

    private var emptySubtitle: AttributedString {
        var string = AttributedString(
            localized: "metric_detail.empty.subtitle"
        )
        if let range = string.range(of: "+") {
            string[range].foregroundColor = tint
            string[range].font = .body.weight(.bold)
        }
        return string
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            metricLabel
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: emptyStateSymbol)
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                VStack(spacing: 8) {
                    Text("metric_detail.empty.title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(emptySubtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var metricLabel: some View {
        HStack(spacing: 8) {
            Text(metric.emoji)
                .font(.title3)
            Text(metric.name.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(tint)
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            metricLabel

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(displayedValueText)
                    .font(
                        .system(size: 56, weight: .semibold, design: .rounded)
                    )
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: displayedValueText)

                if !displayedUnitText.isEmpty {
                    Text(displayedUnitText)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(tint)
                }
            }
            .padding(.bottom, -10)

            Text(displayedDateText)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart Mode Toggle

    private var chartModeToggle: some View {
        Picker("View", selection: $chartMode) {
            Image(systemName: "chart.bar.fill").tag(ChartMode.chart)
            Image(systemName: "calendar").tag(ChartMode.calendar)
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    // MARK: - Month Selector

    /// The months visible in the calendar, oldest → newest. Mirrors
    /// `CalendarScrollView.months` so index math stays aligned.
    private var calendarMonths: [Date] {
        let cal = Calendar.current
        var result: [Date] = []
        var cursor = calendarStartMonth
        while cursor <= calendarEndMonth {
            result.append(cursor)
            guard
                let next = cal.date(byAdding: .month, value: 1, to: cursor)
            else { break }
            cursor = next
        }
        return result
    }

    /// The settled month index (nearest whole month to the live progress).
    private var currentMonthIndex: Int {
        guard !calendarMonths.isEmpty else { return 0 }
        return min(max(Int(monthProgress.rounded()), 0), calendarMonths.count - 1)
    }

    private func monthLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year()).capitalized
    }

    /// Scrolls the calendar `value` months, clamped to range. Writing
    /// `displayedMonth` animates the calendar's `scrollPosition`; the resulting
    /// scroll feeds `monthProgress` back, so the label slides in step.
    private func stepMonth(by value: Int) {
        guard !calendarMonths.isEmpty else { return }
        let target = min(
            max(currentMonthIndex + value, 0),
            calendarMonths.count - 1
        )
        withAnimation(.snappy) { displayedMonth = calendarMonths[target] }
    }

    private var monthSelector: some View {
        HStack(spacing: 12) {
            Button(action: { stepMonth(by: -1) }) {
                Label("Previous month", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(tint)
            .disabled(currentMonthIndex <= 0)

            monthLabelStrip
                .foregroundStyle(.primary)

            Button(action: { stepMonth(by: 1) }) {
                Label("Next month", systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(tint)
            .disabled(currentMonthIndex >= calendarMonths.count - 1)
        }
        // Extra gap so the trailing chevron doesn't read as part of the
        // adjacent mode toggle.
        .padding(.trailing, 30)
    }

    /// Horizontal strip of month labels positioned by the continuous
    /// `monthProgress`. As the calendar is swiped, the current label slides out
    /// and the neighbour slides in — partially, in step with the drag.
    private var monthLabelStrip: some View {
        GeometryReader { geometry in
            let slot = geometry.size.width
            ZStack {
                ForEach(stripIndices, id: \.self) { index in
                    let distance = Double(index) - monthProgress
                    Text(monthLabel(for: calendarMonths[index]))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .frame(width: slot)
                        .offset(x: CGFloat(distance) * slot)
                        .opacity(max(0, 1 - abs(distance)))
                }
            }
            .frame(width: slot, height: geometry.size.height)
        }
        .frame(height: 22)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// The window of month indices worth rendering around the current
    /// position: the settled month and its immediate neighbours.
    private var stripIndices: [Int] {
        guard !calendarMonths.isEmpty else { return [] }
        let lower = max(Int(monthProgress.rounded(.down)) - 1, 0)
        let upper = min(
            Int(monthProgress.rounded(.up)) + 1,
            calendarMonths.count - 1
        )
        guard lower <= upper else { return [] }
        return Array(lower...upper)
    }

    // MARK: - Chart

    private var chartSection: some View {
        Chart(bins, id: \.date) { bin in
            BarMark(
                x: .value("Date", bin.date, unit: range.bucketComponent),
                y: .value("Value", bin.value)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(barGradient(for: bin))
        }
        .id(range)  // recreates chart when range changes → re-applies initialX
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: range.visibleDomainSeconds)
        .chartScrollPosition(initialX: bins.last?.date ?? Date.now)
        .chartXSelection(value: $selectedDate)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: range.desiredAxisLabels))
            { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(axisLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Category Chart

    private var categoryChartSection: some View {
        StackedBarChartView(
            entries: categoryEntries,
            range: range,
            selectedDate: $selectedDate
        )
    }

    /// Calendar view for category metrics. Each day is an equal-wedge pie of its
    /// active choices, in stable list order; a day whose choices are all filtered
    /// out falls back to the empty "no entry" outline.
    private var categoryCalendarSection: some View {
        let cal = Calendar.current
        return CalendarScrollView(
            startMonth: calendarStartMonth,
            endMonth: calendarEndMonth,
            selectedDate: $selectedDate,
            scrolledMonth: $displayedMonth,
            onMonthProgress: { monthProgress = $0 }
        ) { ctx in
            let dayLabels = categoryDayLabels[cal.startOfDay(for: ctx.date)] ?? []
            let colors = orderedCategoryChoices
                .filter {
                    dayLabels.contains($0) && activeCategoryLabels.contains($0)
                }
                .compactMap { categoryColorMap[$0] }
            CalendarDayCell(
                date: ctx.date,
                isSelected: ctx.isSelected,
                isToday: ctx.isToday,
                isFuture: ctx.isFuture,
                tint: tint,
                hasData: !colors.isEmpty
            ) {
                DayPieFillView(colors: colors)
            }
        }
    }

    // MARK: - Binary Calendar

    private var binaryCalendarSection: some View {
        let cal = Calendar.current
        let now = Date()
        let endMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
        let startMonth =
            cal.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        return CalendarScrollView(
            startMonth: startMonth,
            endMonth: endMonth,
            selectedDate: $selectedDate
        ) { ctx in
            let day = cal.startOfDay(for: ctx.date)
            let isTrue = filledDays.contains(day)
            let isFalse = falseDays.contains(day)
            CalendarDayCell(
                date: ctx.date,
                isSelected: ctx.isSelected,
                isToday: ctx.isToday,
                isFuture: ctx.isFuture,
                tint: tint,
                hasData: isTrue || isFalse
            ) {
                DaySolidFillView(
                    style: isTrue ? .filled : (isFalse ? .muted : .empty),
                    tint: tint
                )
            }
        }
    }

    // MARK: - Datetime Calendar

    private var datetimeCalendarSection: some View {
        let cal = Calendar.current
        let now = Date()
        let endMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
        let startMonth =
            cal.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        return CalendarScrollView(
            startMonth: startMonth,
            endMonth: endMonth,
            selectedDate: $selectedDate
        ) { ctx in
            let hasEvent = datetimeFilledDays.contains(
                cal.startOfDay(for: ctx.date)
            )
            CalendarDayCell(
                date: ctx.date,
                isSelected: ctx.isSelected,
                isToday: ctx.isToday,
                isFuture: ctx.isFuture,
                tint: tint,
                hasData: hasEvent
            ) {
                DaySolidFillView(style: hasEvent ? .filled : .empty, tint: tint)
            }
        }
    }

    // MARK: - Number / Duration Calendar

    /// Latest month shown by the calendar (the current month).
    private var calendarEndMonth: Date {
        let cal = Calendar.current
        let now = Date()
        return cal.dateInterval(of: .month, for: now)?.start ?? now
    }

    /// Earliest month shown by the calendar (11 months back).
    private var calendarStartMonth: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .month, value: -11, to: calendarEndMonth)
            ?? calendarEndMonth
    }

    /// Calendar view for number/duration metrics. Toggled from the chart via
    /// `chartModeToggle`. Marks each day that has at least one logged entry.
    private var numberCalendarSection: some View {
        let cal = Calendar.current
        return CalendarScrollView(
            startMonth: calendarStartMonth,
            endMonth: calendarEndMonth,
            selectedDate: $selectedDate,
            scrolledMonth: $displayedMonth,
            onMonthProgress: { monthProgress = $0 }
        ) { ctx in
            let isLogged = numberFilledDays.contains(
                cal.startOfDay(for: ctx.date)
            )
            CalendarDayCell(
                date: ctx.date,
                isSelected: ctx.isSelected,
                isToday: ctx.isToday,
                isFuture: ctx.isFuture,
                tint: tint,
                hasData: isLogged
            ) {
                DaySolidFillView(style: isLogged ? .filled : .empty, tint: tint)
            }
        }
    }

    private var displayedDatetimeCount: Int? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: selectedDate ?? Date())
        let count = metric.data.filter {
            if case .datetime(let d) = $0 {
                return cal.isDate(d, inSameDayAs: target)
            }
            return false
        }.count
        return count > 0 ? count : nil
    }

    private func barGradient(for bin: ChartBin) -> LinearGradient {
        let calendar = Calendar.current
        let isSelected =
            selectedDate.map {
                calendar.isDate(
                    bin.date,
                    equalTo: $0,
                    toGranularity: range.bucketComponent
                )
            } ?? false
        let top = tint.opacity(isSelected ? 1.0 : 0.45)
        let bottom = tint.opacity(isSelected ? 0.6 : 0.15)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Recent Entries

    private var recentEntries: some View {
        let visible = Array(sortedEntries.prefix(8))
        return Section {
            ForEach(visible.indices, id: \.self) { index in
                entryRow(for: visible[index])
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(visible[index])
                            PostHogSDK.shared.capture("entry_deleted")
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text("RECENT ENTRIES")
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
    }

    private func delete(_ point: DataPoint) {
        if let index = metric.data.firstIndex(of: point) {
            metric.data.remove(at: index)
        }
    }

    private func entryRow(for point: DataPoint) -> some View {
        let entryDate = date(of: point)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(relativeDay(for: entryDate))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(entryDate.formatted(.dateTime.year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(entryDisplayText(for: point))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
                if !isBinary, !unitText.isEmpty {
                    Text(unitText)
                        .font(.caption)
                        .foregroundStyle(tint.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Display helpers

    private var displayedValueText: String {
        if isBinary {
            guard let value = displayedBinaryValue, let cfg = binaryConfig
            else { return "—" }
            return value ? cfg.trueLabel : cfg.falseLabel
        }
        if isDatetime {
            guard let count = displayedDatetimeCount else { return "—" }
            return "\(count)"
        }
        if isCategory {
            guard let summary = displayedCategorySummary else { return "—" }
            return summary.label
        }
        guard let bin = displayedBin else { return "—" }
        return valueText(value: bin.value)
    }

    private var displayedUnitText: String {
        if isBinary { return "" }
        if isDatetime {
            guard let count = displayedDatetimeCount else { return "" }
            return count == 1 ? "event" : "events"
        }
        if isCategory {
            guard let summary = displayedCategorySummary else { return "" }
            return "×\(summary.count)"
        }
        guard displayedBin != nil else { return "" }
        return unitText
    }

    private var displayedDateText: String {
        if isBinary {
            let target = selectedDate ?? Date()
            let formatted = target.formatted(
                .dateTime.month(.abbreviated).day()
            )
            let suffix =
                (selectedDate == nil)
                ? String(localized: "metric_detail.date.today_suffix") : ""
            return formatted + suffix
        }
        if isDatetime {
            let target = selectedDate ?? Date()
            let formatted = target.formatted(
                .dateTime.month(.abbreviated).day()
            )
            let suffix =
                (selectedDate == nil)
                ? String(localized: "metric_detail.date.today_suffix") : ""
            return formatted + suffix
        }
        if isCategory {
            guard let bucket = displayedCategoryBucket else {
                return String(localized: "metric_detail.date.no_data")
            }
            let formatted = formattedBucketDate(bucket)
            let suffix =
                (selectedDate == nil)
                ? String(localized: "metric_detail.date.latest_suffix") : ""
            return formatted + suffix
        }
        guard let bin = displayedBin else {
            return String(localized: "metric_detail.date.no_data")
        }
        let formatted = formattedBucketDate(bin.date)
        let suffix =
            (selectedDate == nil)
            ? String(localized: "metric_detail.date.latest_suffix") : ""
        return formatted + suffix
    }

    private func formattedBucketDate(_ date: Date) -> String {
        switch range {
        case .month:
            return date.formatted(
                .dateTime.month(.abbreviated).day().year()
            )
        case .sixMonths:
            return String(localized: "metric_detail.date.week_of_prefix")
                + date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private var unitText: String {
        switch metric.config {
        case .number(let cfg): return cfg.unit ?? ""
        default: return ""
        }
    }

    private func entryDisplayText(for point: DataPoint) -> String {
        if case .binary(_, let flag) = point, let cfg = binaryConfig {
            return flag ? cfg.trueLabel : cfg.falseLabel
        }
        if case .category(_, let labels) = point {
            return labels.joined(separator: ", ")
        }
        if case .datetime(let d) = point {
            return d.formatted(date: .omitted, time: .shortened)
        }
        return valueText(value: numericValue(of: point))
    }

    private func valueText(value: Double) -> String {
        switch metric.config {
        case .number(let cfg):
            return cfg.granularity >= 1
                ? String(Int(value))
                : String(format: "%.1f", value)
        case .duration:
            let seconds = Int(value)
            return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        default:
            return String(format: "%.1f", value)
        }
    }

    private func numericValue(of point: DataPoint) -> Double {
        switch point {
        case .number(_, let v): return v
        case .duration(_, let t): return t
        default: return 0
        }
    }

    private func date(of point: DataPoint) -> Date { point.date }

    private func axisLabel(for date: Date) -> String {
        switch range {
        case .month:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .sixMonths:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            return date.formatted(.dateTime.month(.narrow))
        }
    }

    private func relativeDay(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "metric_detail.entry.today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "metric_detail.entry.yesterday")
        }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

// MARK: - Config helpers

extension MetricConfig {
    fileprivate var behavior: MetricBehavior {
        switch self {
        case .number(let cfg): return cfg.behavior
        case .duration(let cfg): return cfg.behavior
        default: return .snapshot
        }
    }
}

extension AggregationMethod {
    fileprivate var numeric: NumericMethod {
        if case .numerical(let m) = self { return m }
        return .latest
    }
}

#Preview {
    let schema = MetricSchema.Fake.number(
        title: "Heart Rate",
        emoji: "❤️",
        unit: "bpm"
    )
    let metric = Metric(
        from: schema,
        color: .pink,
        data: Metric.fakeData(for: schema.config, days: 365 * 5)
    )
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Duration") {
    let schema = MetricSchema.Fake.duration(title: "Sleep", emoji: "🌙")
    let metric = Metric(
        from: schema,
        color: .indigo,
        data: Metric.fakeData(for: schema.config, days: 365)
    )
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Category Single") {
    let schema = MetricSchema.Fake.categorySingle(title: "Mood", emoji: "😊")
    let metric = Metric(
        from: schema,
        color: .orange,
        data: Metric.fakeData(for: schema.config, days: 365)
    )
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Category Multiple") {
    let schema = MetricSchema.Fake.categoryMultiple(
        title: "Symptoms",
        emoji: "🤒"
    )
    let metric = Metric(
        from: schema,
        color: .purple,
        data: Metric.fakeData(for: schema.config, days: 365)
    )
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Binary") {
    let schema = MetricSchema.Fake.binary(title: "Workout Day", emoji: "💪")
    let metric = Metric(
        from: schema,
        color: .teal,
        data: Metric.fakeData(for: schema.config, days: 365)
    )
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Empty") {
    let schema = MetricSchema.Fake.categorySingle(title: "Daily Mood", emoji: "🎭")
    let metric = Metric(from: schema, color: .orange)
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Datetime") {
    let schema = MetricSchema.Fake.datetime(
        title: "Doctor Appointments",
        emoji: "🏥"
    )
    let metric = Metric(
        from: schema,
        color: .pink,
        data: Metric.fakeData(
            for: schema.config,
            days: 5
        )
    )
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Plant watered") {
    let schema = MetricSchema.Fake.binary(
        title: "Plant watered",
        emoji: "🪴",
        trueLabel: "Watered",
        falseLabel: "Skipped"
    )
    let calendar = Calendar.current
    let now = Date()
    // Watered on a regular ~3-day cadence over the last few months.
    let data: [DataPoint] = (0..<120).reversed().compactMap { offset in
        guard offset % 3 == 0 else { return nil }
        let date =
            calendar.date(byAdding: .day, value: -offset, to: now) ?? now
        return .binary(date, true)
    }
    let metric = Metric(from: schema, color: .green, data: data)
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Pages read") {
    let schema = MetricSchema.Fake.number(
        title: "Pages read",
        emoji: "📖",
        unit: "pages",
        min: 0,
        max: 120,
        granularity: 1,
        goal: 30,
        behavior: .cumulative,
        chart: .dailyGauge
    )
    // A realistic reading habit: most days 15–45 pages, a few rest days.
    let data: [DataPoint] = {
        let calendar = Calendar.current
        let now = Date()
        let restDays: Set<Int> = [0, 3, 9, 17, 24, 38, 51, 66, 79, 92]
        var points: [DataPoint] = []
        for offset in (0..<110).reversed() {
            if restDays.contains(offset) { continue }
            let date =
                calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            points.append(.number(date, Double(Int.random(in: 15...45))))
        }
        // Make today land just over the goal for a satisfying gauge.
        points.append(.number(now, 32))
        return points
    }()
    let metric = Metric(from: schema, color: .brown, data: data)
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}

#Preview("Alcohol-free days") {
    let schema = MetricSchema.Fake.binary(
        title: "Alcohol-free days",
        emoji: "🌿",
        trueLabel: "Alcohol-free",
        falseLabel: "Had a drink"
    )
    let calendar = Calendar.current
    let now = Date()
    // A strong, aspirational streak with a few earlier slips.
    let slips: Set<Int> = [47, 52, 68, 81, 95]
    let data: [DataPoint] = (0..<110).reversed().map { offset in
        let date =
            calendar.date(byAdding: .day, value: -offset, to: now) ?? now
        return .binary(date, !slips.contains(offset))
    }
    let metric = Metric(from: schema, color: .teal, data: data)
    NavigationStack {
        MetricDetailView(metric: metric)
    }
}
