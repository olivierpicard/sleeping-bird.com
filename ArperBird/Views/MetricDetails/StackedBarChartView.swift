import SwiftUI
import Charts

struct StackedBarChartView: View {
    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let value: Double
    }

    let entries: [Entry]
    let range: TimeRange
    @Binding var selectedDate: Date?

    @State private var rawSelectedDate: Date?

    private var paddedDomain: ClosedRange<Date> {
        guard let minDate = entries.map(\.date).min(),
              let maxDate = entries.map(\.date).max() else {
            let now = Date()
            return now...now
        }
        let padding: TimeInterval = 60 * 60 * 24
        return minDate.addingTimeInterval(-padding)...maxDate.addingTimeInterval(padding)
    }

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Date", entry.date, unit: range.bucketComponent),
                y: .value("Value", entry.value)
            )
            .foregroundStyle(by: .value("Label", entry.label))
            .opacity(barOpacity(for: entry.date))
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(initialX: Date.now)
        .chartXVisibleDomain(length: range.visibleDomainSeconds)
        .chartXSelection(value: $rawSelectedDate)
        .contentMargins(.trailing, 25)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: range.desiredAxisLabels))
        }
        .frame(height: 240)
        .onChange(of: rawSelectedDate) { _, newValue in
            selectedDate = newValue.map { bucketStart(for: $0) }
        }
    }

    private func bucketStart(for date: Date) -> Date {
        let cal = Calendar.current
        switch range.bucketComponent {
        case .weekOfYear:
            return cal.dateInterval(of: .weekOfYear, for: date)?.start
                ?? cal.startOfDay(for: date)
        case .month:
            return cal.dateInterval(of: .month, for: date)?.start
                ?? cal.startOfDay(for: date)
        default:
            return cal.startOfDay(for: date)
        }
    }

    private func barOpacity(for date: Date) -> Double {
        guard let selectedDate else { return 1.0 }
        return Calendar.current.isDate(
            date,
            equalTo: selectedDate,
            toGranularity: range.bucketComponent
        ) ? 1.0 : 0.3
    }
}

#Preview("Month") {
    @Previewable @State var selected: Date?
    let calendar = Calendar.current
    let today = Date()
    let labels = ["Work", "Sleep", "Exercise"]
    let entries: [StackedBarChartView.Entry] = (0..<730).flatMap { dayOffset in
        labels.map { label in
            StackedBarChartView.Entry(
                date: calendar.date(byAdding: .day, value: -dayOffset, to: today)!,
                label: label,
                value: Double.random(in: 1...8)
            )
        }
    }
    return StackedBarChartView(entries: entries, range: .month, selectedDate: $selected)
        .padding()
}

#Preview("6 Months") {
    @Previewable @State var selected: Date?
    let calendar = Calendar.current
    let today = Date()
    let labels = ["Work", "Sleep", "Exercise"]
    let entries: [StackedBarChartView.Entry] = (0..<104).flatMap { weekOffset in
        let weekStart = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
            )
        )!
        return labels.map { label in
            StackedBarChartView.Entry(
                date: weekStart,
                label: label,
                value: Double.random(in: 1...8)
            )
        }
    }
    return StackedBarChartView(entries: entries, range: .sixMonths, selectedDate: $selected)
        .padding()
}

#Preview("Year") {
    @Previewable @State var selected: Date?
    let calendar = Calendar.current
    let today = Date()
    let labels = ["Work", "Sleep", "Exercise"]
    let entries: [StackedBarChartView.Entry] = (0..<24).flatMap { monthOffset in
        let monthStart = calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: calendar.date(byAdding: .month, value: -monthOffset, to: today)!
            )
        )!
        return labels.map { label in
            StackedBarChartView.Entry(
                date: monthStart,
                label: label,
                value: Double.random(in: 1...8)
            )
        }
    }
    return StackedBarChartView(entries: entries, range: .year, selectedDate: $selected)
        .padding()
}
