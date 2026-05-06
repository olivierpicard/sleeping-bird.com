//
//  MetricDetailView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 03/05/2026.
//

import Charts
import SwiftUI

struct MetricDetailView: View {
    let metric: Metric

    @State private var range: TimeRange = .month
    @State private var selectedDate: Date?
    @State private var bins: [ChartBin] = []
    @State private var filledDays: Set<Date> = []
    @State private var isEditing: Bool = false

    private func recomputeBins() {
        bins = MetricAggregator.bins(
            from: metric.data,
            range: range,
            method: metric.visual.aggregation.method.numeric,
            behavior: metric.config.behavior
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

    private var isBinary: Bool {
        if case .binary = metric.config { return true }
        return false
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
        let _ = Self._printChanges()
        ScrollView {
            VStack(spacing: 24) {
                header
                    .padding(.horizontal)
             
                Group {
                    if !isBinary {
                            rangePicker
                                .frame(maxWidth: 280)
                        chartSection
                    } else {
                        binaryCalendarSection
                            .padding(.top)
                    }
                    
                }
//                .padding(.horizontal)
                recentEntries
                    .padding(.horizontal, 20)
            }

            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                    .tint(metric.color)
            }
        }
        .sheet(isPresented: $isEditing) {
            MetricEditSheet(metric: metric)
        }
        .onAppear {
            recomputeBins()
            recomputeFilledDays()
        }
        .onChange(of: range) { _, _ in
            selectedDate = nil
            recomputeBins()
        }
        .onChange(of: metric.data.count) { _, _ in
            recomputeBins()
            recomputeFilledDays()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Text(metric.emoji)
                    .font(.title3)
                Text(metric.name.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(metric.color)
            }

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
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ENTRIES")
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            let visible = Array(sortedEntries.prefix(8))
            VStack(spacing: 0) {
                ForEach(visible.indices, id: \.self) { index in
                    entryRow(for: visible[index])
                    if index < visible.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                Text(entryDate.formatted(date: .omitted, time: .shortened))
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
        guard let bin = displayedBin else { return "—" }
        return valueText(value: bin.value)
    }

    private var displayedUnitText: String {
        if isBinary { return "" }
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
        default:
            return .distantPast
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
        return date.formatted(.dateTime.month(.abbreviated).day())
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
    return NavigationStack {
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
    return NavigationStack {
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
    return NavigationStack {
        MetricDetailView(metric: metric)
    }
}


//Here is 3 of the design that I love.
//Focus on the header
//There is :
//- the emoji + metric name
//- A value label
//- A date label
//
//In the body there is:
//- A segment
//- A chart
//
//- I want the segment to be on the right and small size like it is on 2 pictures
//- I want the header to be only emoji + metric name only
//- Move the big value label & the date label under the segment, closer to the chart like it is on the third image
//- Except these keep everything, focus only on the "header" part
//
//Use the described layout for the image 2 (with the fine bar chart). Rework the segment to be smaller but keep all values
