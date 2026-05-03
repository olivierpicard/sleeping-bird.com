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

    @State private var selectedIndex: Int?

    private var entries: [DataPoint] {
        metric.data
    }

    private var sortedEntries: [DataPoint] {
        entries.sorted { lhs, rhs in
            date(of: lhs) > date(of: rhs)
        }
    }

    private var displayedPoint: DataPoint? {
        if let index = selectedIndex, entries.indices.contains(index) {
            return entries[index]
        }
        return entries.last
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
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

    // MARK: - Chart

    private var chartSection: some View {
        let barWidth: CGFloat = 14
        let spacing: CGFloat = 6
        let count = entries.count
        let chartWidth = max(CGFloat(count) * (barWidth + spacing), 0)

        return ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(entries.indices, id: \.self) { index in
                    let point = entries[index]
                    BarMark(
                        x: .value("Index", index),
                        y: .value("Value", numericValue(of: point)),
                        width: .fixed(barWidth)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: barWidth / 2.5)
                    )
                    .foregroundStyle(barGradient(forIndex: index))
                }
            }
            .chartXAxis {
                AxisMarks(values: xAxisIndices) { value in
                    if let index = value.as(Int.self),
                        entries.indices.contains(index)
                    {
                        AxisValueLabel {
                            Text(shortDate(date(of: entries[index])))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    handleTap(
                                        at: value.location,
                                        proxy: proxy,
                                        geo: geo
                                    )
                                }
                        )
                }
            }
            .frame(width: chartWidth, height: 200)
            .padding(.horizontal, 4)
        }
        .frame(height: 220)
        .scrollClipDisabled()
        .defaultScrollAnchor(.trailing)
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

    private var xAxisIndices: [Int] {
        let count = entries.count
        guard count > 0 else { return [] }
        let desired = 5
        let stride = max(count / desired, 1)
        return Array(Swift.stride(from: 0, to: count, by: stride))
    }

    private func handleTap(
        at location: CGPoint,
        proxy: ChartProxy,
        geo: GeometryProxy
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
        guard entries.indices.contains(index) else { return }
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
                Text(valueText(of: point))
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
        guard let point = displayedPoint else { return "—" }
        return valueText(of: point)
    }

    private var displayedUnitText: String {
        guard displayedPoint != nil else { return "" }
        return unitText
    }

    private var displayedDateText: String {
        guard let point = displayedPoint else { return "No data" }
        let formatted = date(of: point).formatted(
            .dateTime.month(.abbreviated).day().hour().minute()
        )
        let suffix =
            (selectedIndex == nil) ? " · Latest reading" : ""
        return formatted + suffix
    }

    private var unitText: String {
        switch metric.config {
        case .number(let cfg): return cfg.unit ?? ""
        default: return ""
        }
    }

    private func valueText(of point: DataPoint) -> String {
        switch point {
        case .number(_, let v):
            if case .number(let cfg) = metric.config {
                return cfg.granularity >= 1
                    ? String(Int(v))
                    : String(format: "%.1f", v)
            }
            return String(format: "%.1f", v)
        case .category(_, let labels):
            return labels.first ?? "—"
        case .binary(_, let flag):
            if case .binary(let cfg) = metric.config {
                return flag ? cfg.trueLabel : cfg.falseLabel
            }
            return flag ? "Yes" : "No"
        case .datetime(let d):
            return d.formatted(date: .abbreviated, time: .shortened)
        case .duration(_, let t):
            let seconds = Int(t)
            return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        }
    }

    private func numericValue(of point: DataPoint) -> Double {
        switch point {
        case .number(_, let v): return v
        case .duration(_, let t): return t
        case .binary(_, let flag): return flag ? 1 : 0
        case .category(_, let labels): return Double(labels.count)
        case .datetime: return 1
        }
    }

    private func date(of point: DataPoint) -> Date {
        switch point {
        case .number(let d, _), .category(let d, _), .binary(let d, _),
            .duration(let d, _):
            return d
        case .datetime(let d): return d
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func relativeDay(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
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
        data: Metric.fakeData(for: schema.config, days: 30)
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
        data: Metric.fakeData(for: schema.config, days: 30)
    )
    return NavigationStack {
        MetricDetailView(metric: metric)
    }
}
