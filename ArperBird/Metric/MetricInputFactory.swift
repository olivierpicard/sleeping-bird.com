import SwiftUI

enum MetricInputFactory {

    @ViewBuilder
    static func make(
        from metric: Metric,
        in scheme: ColorScheme,
        onAdd: @escaping (DataPoint) -> Void
    ) -> some View {
        let mainColor = metric.displayColor(in: scheme)
        switch metric.config {
        case .number(let cfg):
            MetricEditor.Number(
                min: cfg.min,
                max: cfg.max,
                defaultValue: cfg.min,
                step: cfg.granularity,
                unit: cfg.unit,
                mainColor: mainColor,
                onAdd: { onAdd(.number(Date(), $0)) }
            )
            .style(numberStyle(for: cfg))

        case .categorySingleChoice(let cfg):
            MetricEditor.Category(
                labels: cfg.labels,
                mainColor: mainColor,
                onAdd: { onAdd(.category(Date(), $0)) }
            )
            .style(.single)

        case .categoryMultipleChoice(let cfg):
            MetricEditor.Category(
                labels: cfg.labels,
                mainColor: mainColor,
                onAdd: { onAdd(.category(Date(), $0)) }
            )
            .style(.multiple)

        case .binary(let cfg):
            MetricEditor.Binary(
                trueLabel: cfg.trueLabel,
                falseLabel: cfg.falseLabel,
                mainColor: mainColor,
                onAdd: { onAdd(.binary(Date(), $0)) }
            )

        case .duration(let cfg):
            MetricEditor.Duration(
                granularity: cfg.granularity,
                maxInSeconds: cfg.maxInSeconds,
                mainColor: mainColor,
                onAdd: { onAdd(.duration(Date(), $0)) }
            )
        
        case .datetime(_):
            MetricEditor.Datetime(
                defaultValue: Date.now,
                mainColor: mainColor,
                onAdd: { onAdd(.datetime( $0 )) }
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
