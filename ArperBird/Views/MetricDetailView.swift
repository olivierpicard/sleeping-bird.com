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

    @State private var range: TimeRange = .month
    @State private var selectedDate: Date?
    @State private var bins: [ChartBin] = []
    @State private var filledDays: Set<Date> = []
    @State private var categoryEntries: [StackedBarChartView.Entry] = []
    @State private var datetimeFilledDays: Set<Date> = []
    @State private var isEditing: Bool = false
    @State private var isAddingEntry: Bool = false

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

    private func recomputeFilledDays() {
        let cal = Calendar.current
        var set: Set<Date> = []
        for point in metric.data {
            if case .binary(let date, true) = point {
                set.insert(cal.startOfDay(for: date))
            }
        }
        filledDays = set
    }

    private func recomputeDatetimeFilledDays() {
        let cal = Calendar.current
        var set: Set<Date> = []
        for point in metric.data {
            if case .datetime(let date) = point {
                set.insert(cal.startOfDay(for: date))
            }
        }
        datetimeFilledDays = set
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
                .tint(metric.color)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isEditing = true }) {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                    .tint(metric.color)
            }
        }
        .sheet(isPresented: $isEditing) {
            MetricEditSheet(metric: metric)
        }
        .sheet(isPresented: $isAddingEntry) {
            MetricInputFactory.make(from: metric) { point in
                try? metric.append(point)
                isAddingEntry = false
                PostHogSDK.shared.capture(
                    "entry_added",
                    properties: ["via": "details"]
                )
            }
            .trackScreen("AddEntry")
        }
        .onAppear {
            recomputeBins()
            recomputeFilledDays()
            recomputeDatetimeFilledDays()
            recomputeCategoryEntries()
        }
        .onChange(of: range) { _, _ in
            selectedDate = nil
            recomputeBins()
            recomputeCategoryEntries()
        }
        .onChange(of: metric.data.count) { _, _ in
            recomputeBins()
            recomputeFilledDays()
            recomputeDatetimeFilledDays()
            recomputeCategoryEntries()
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
                            rangePicker
                                .frame(maxWidth: 280)
                            categoryChartSection
                        } else {
                            rangePicker
                                .frame(maxWidth: 280)
                            chartSection
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
            string[range].foregroundColor = metric.color
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
                    .fill(metric.color.opacity(0.12))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: emptyStateSymbol)
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(metric.color)
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

//                Button(action: { isAddingEntry = true }) {
//                    Label("metric_detail.empty.cta", systemImage: "plus")
//                        .font(.headline)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 4)
//                }
//                .controlSize(.large)
//                .buttonStyle(.glassProminent)
//                .tint(metric.color)
//                .padding(.top, 15)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State (card variant)

//    private var emptyStateCard: some View {
//        VStack(spacing: 0) {
//            metricLabel
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal, 20)
//                .padding(.top, 8)
//
//            Spacer()
//
//            VStack(spacing: 20) {
//                RoundedRectangle(cornerRadius: 20, style: .continuous)
//                    .fill(metric.color.opacity(0.12))
//                    .frame(width: 88, height: 88)
//                    .overlay {
//                        Image(systemName: emptyStateSymbol)
//                            .font(.system(size: 34, weight: .semibold))
//                            .foregroundStyle(metric.color)
//                    }
//
//                VStack(spacing: 8) {
//                    Text("metric_detail.empty.card.title")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundStyle(.primary)
//                        .multilineTextAlignment(.center)
//
//                    Text("metric_detail.empty.card.subtitle")
//                        .font(.body)
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                        .fixedSize(horizontal: false, vertical: true)
//                }
//
//                Button(action: { isAddingEntry = true }) {
//                    Label("metric_detail.empty.card.cta", systemImage: "plus")
//                        .font(.headline)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 4)
//                }
//                .controlSize(.large)
//                .buttonStyle(.glassProminent)
//                .tint(metric.color)
//                .padding(.top, 4)
//            }
//            .padding(28)
//            .frame(maxWidth: .infinity)
//            .background(
//                RoundedRectangle(cornerRadius: 28, style: .continuous)
//                    .fill(Color(.secondarySystemGroupedBackground))
//            )
//            .padding(.horizontal, 16)
//            .padding(.bottom, 24)
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemGroupedBackground))
//    }

    // MARK: - Header

    private var metricLabel: some View {
        HStack(spacing: 8) {
            Text(metric.emoji)
                .font(.title3)
            Text(metric.name.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(metric.color)
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
                        .foregroundStyle(metric.color)
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

    // MARK: - Binary Calendar

    private var binaryCalendarSection: some View {
        let cal = Calendar.current
        let now = Date()
        let endMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
        let startMonth =
            cal.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        let cfg = binaryConfig
        return BinaryCalendarView(
            filledDays: filledDays,
            startMonth: startMonth,
            endMonth: endMonth,
            tint: metric.color,
            trueLabel: cfg?.trueLabel ?? "Yes",
            falseLabel: cfg?.falseLabel ?? "No",
            selectedDate: $selectedDate
        )
    }

    // MARK: - Datetime Calendar

    private var datetimeCalendarSection: some View {
        let cal = Calendar.current
        let now = Date()
        let endMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
        let startMonth =
            cal.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        return BinaryCalendarView(
            filledDays: datetimeFilledDays,
            startMonth: startMonth,
            endMonth: endMonth,
            tint: metric.color,
            trueLabel: "Event",
            falseLabel: "No event",
            selectedDate: $selectedDate
        )
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
        let top = metric.color.opacity(isSelected ? 1.0 : 0.45)
        let bottom = metric.color.opacity(isSelected ? 0.6 : 0.15)
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
                    .foregroundStyle(metric.color)
                if !isBinary, !unitText.isEmpty {
                    Text(unitText)
                        .font(.caption)
                        .foregroundStyle(metric.color.opacity(0.7))
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
            let suffix = (selectedDate == nil) ? " · Today" : ""
            return formatted + suffix
        }
        if isDatetime {
            let target = selectedDate ?? Date()
            let formatted = target.formatted(
                .dateTime.month(.abbreviated).day()
            )
            let suffix = (selectedDate == nil) ? " · Today" : ""
            return formatted + suffix
        }
        if isCategory {
            guard let bucket = displayedCategoryBucket else { return "No data" }
            let formatted = formattedBucketDate(bucket)
            let suffix = (selectedDate == nil) ? " · Latest" : ""
            return formatted + suffix
        }
        guard let bin = displayedBin else { return "No data" }
        let formatted = formattedBucketDate(bin.date)
        let suffix = (selectedDate == nil) ? " · Latest" : ""
        return formatted + suffix
    }

    private func formattedBucketDate(_ date: Date) -> String {
        switch range {
        case .month:
            return date.formatted(
                .dateTime.month(.abbreviated).day().year()
            )
        case .sixMonths:
            return "Week of "
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

    private func date(of point: DataPoint) -> Date {
        switch point {
        case .number(let d, _), .duration(let d, _):
            return d
        case .category(let d, _), .binary(let d, _):
            return d
        case .datetime(let d):
            return d
        }
    }

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
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
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
