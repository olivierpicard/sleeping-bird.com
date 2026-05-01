import SwiftUI

enum MetricInputFactory {

    @ViewBuilder
    static func make(from metric: Metric, onAdd: @escaping (DataPoint) -> Void)
        -> some View
    {
        switch metric.config {
        case .number(let cfg):
            MetricEditor.Number(
                min: cfg.min,
                max: cfg.max,
                defaultValue: cfg.min,
                step: cfg.granularity,
                unit: cfg.unit,
                mainColor: metric.color,
                onAdd: { onAdd(.number(Date(), $0)) }
            )
            .style(numberStyle(for: cfg))

        case .categorySingleChoice(let cfg):
            MetricEditor.Category(
                labels: cfg.labels,
                mainColor: metric.color,
                onAdd: { onAdd(.category(Date(), $0)) }
            )
            .style(.single)

        case .categoryMultipleChoice(let cfg):
            MetricEditor.Category(
                labels: cfg.labels,
                mainColor: metric.color,
                onAdd: { onAdd(.category(Date(), $0)) }
            )
            .style(.multiple)

        case .binary(let cfg):
            MetricEditor.Binary(
                trueLabel: cfg.trueLabel,
                falseLabel: cfg.falseLabel,
                mainColor: metric.color,
                onAdd: { onAdd(.binary(Date(), $0)) }
            )

        case .duration(let cfg):
            MetricEditor.Duration(
                granularity: cfg.granularity,
                maxInSeconds: cfg.maxInSeconds,
                mainColor: metric.color,
                onAdd: { onAdd(.duration(Date(), $0)) }
            )

        case .datetime:
            _DatetimeEditor(
                mainColor: metric.color,
                onAdd: { onAdd(.datetime($0)) }
            )
        }
    }

    private static func numberStyle(for cfg: NumberConfig)
        -> MetricEditor.NumberStyle
    {
        let steps = (cfg.max - cfg.min) / cfg.granularity
        if steps <= 10 { return .stepper }
        if steps <= 100 { return .slider }
        if steps <= 200 { return .picker }
        return .numberInput
    }
}

private struct _DatetimeEditor: View {
    let mainColor: Color
    let onAdd: (Date) -> Void
    @State private var date = Date()

    var body: some View {
        VStack(spacing: 24) {
            DatePicker("", selection: $date)
                .datePickerStyle(.graphical)
                .tint(mainColor)
            Button("Add") { onAdd(date) }
                .buttonStyle(.glassProminent)
                .tint(mainColor)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
