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
    @State private var selectedIndex: Int?

    private var entries: [DataPoint] {
        metric.data
    }

    private var sortedEntries: [DataPoint] {
        entries.sorted { lhs, rhs in
            date(of: lhs) > date(of: rhs)
        }
    }

    private var bins: [ChartBin] {
        MetricAggregator.bins(
            from: metric.data,
            range: range,
            method: metric.visual.aggregation.method.numeric,
            behavior: metric.config.behavior
        )
    }

    private var displayedBin: ChartBin? {
        if let index = selectedIndex {
            let current = bins
            if current.indices.contains(index) { return current[index] }
        }
        return bins.last
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                rangePicker
                chartSection
                recentEntries
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {}
                    .tint(metric.color)
            }
        }
        .onChange(of: range) { _, _ in
            selectedIndex = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
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

            Text(displayedDateText)
                .font(.subheadline)
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
        let currentBins = bins
        return GeometryReader { geo in
            let viewportWidth = geo.size.width
            let spacing: CGFloat = 4
            let visibleCount = max(range.visibleBarCount, 1)
            let barWidth = max(
                (viewportWidth / CGFloat(visibleCount)) - spacing,
                2
            )
            let chartWidth = max(
                CGFloat(currentBins.count) * (barWidth + spacing),
                viewportWidth
            )

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(currentBins.indices, id: \.self) { index in
                        let bin = currentBins[index]
                        BarMark(
                            x: .value("Index", index),
                            y: .value("Value", bin.value),
                            width: .fixed(barWidth)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: barWidth / 2.5)
                        )
                        .foregroundStyle(barGradient(forIndex: index))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisIndices(for: currentBins)) { value in
                        if let index = value.as(Int.self),
                            currentBins.indices.contains(index)
                        {
                            AxisValueLabel {
                                Text(axisLabel(for: currentBins[index].date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { plotGeo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        handleTap(
                                            at: value.location,
                                            proxy: proxy,
                                            geo: plotGeo,
                                            binsCount: currentBins.count
                                        )
                                    }
                            )
                    }
                }
                .frame(width: chartWidth, height: 200)
            }
            .scrollClipDisabled()
            .defaultScrollAnchor(.trailing)
        }
        .frame(height: 220)
    }

    private func barGradient(forIndex index: Int) -> LinearGradient {
        let isSelected = selectedIndex == index
        let top = metric.color.opacity(isSelected ? 1.0 : 0.45)
        let bottom = metric.color.opacity(isSelected ? 0.6 : 0.15)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func xAxisIndices(for bins: [ChartBin]) -> [Int] {
        let count = bins.count
        guard count > 0 else { return [] }
        let desired = 5
        let stride = max(count / desired, 1)
        return Array(Swift.stride(from: 0, to: count, by: stride))
    }

    private func handleTap(
        at location: CGPoint,
        proxy: ChartProxy,
        geo: GeometryProxy,
        binsCount: Int
    ) {
        guard let plot = proxy.plotFrame else { return }
        let frame = geo[plot]
        let xInPlot = location.x - frame.origin.x
        guard
            let rawIndex: Double = proxy.value(
                atX: xInPlot,
                as: Double.self
            )
        else { return }
        let index = Int(rawIndex.rounded())
        guard (0..<binsCount).contains(index) else { return }
        selectedIndex = (selectedIndex == index) ? nil : index
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
                Text(valueText(value: numericValue(of: point)))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(metric.color)
                if !unitText.isEmpty {
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
        guard let bin = displayedBin else { return "—" }
        return valueText(value: bin.value)
    }

    private var displayedUnitText: String {
        guard displayedBin != nil else { return "" }
        return unitText
    }

    private var displayedDateText: String {
        guard let bin = displayedBin else { return "No data" }
        let formatted = formattedBucketDate(bin.date)
        let suffix = (selectedIndex == nil) ? " · Latest" : ""
        return formatted + suffix
    }

    private func formattedBucketDate(_ date: Date) -> String {
        switch range {
        case .week, .month:
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
        case .week, .month:
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
        data: Metric.fakeData(for: schema.config, days: 365)
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
