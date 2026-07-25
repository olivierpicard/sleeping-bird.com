import SwiftUI

enum MetricInputFactory {

    /// - Parameter date: The timestamp to stamp onto the produced `DataPoint`,
    ///   evaluated when the user saves rather than when the editor is built —
    ///   so a sheet left open, or a day picked after the fact, still records the
    ///   right moment. Defaults to "now". `MetricEntrySheet` passes the day
    ///   chosen in its date row. `.datetime` uses it only as the picker's
    ///   starting point — the date the user then picks *is* the value.
    @ViewBuilder
    static func make(
        from metric: Metric,
        in scheme: ColorScheme,
        date: @escaping () -> Date = { Date() },
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
                onAdd: { onAdd(.number(date(), $0)) }
            )
            .style(numberStyle(for: cfg))

        case .categorySingleChoice(let cfg):
            MetricEditor.Category(
                labels: cfg.labels,
                mainColor: mainColor,
                onAdd: { onAdd(.category(date(), $0)) }
            )
            .style(.single)

        case .categoryMultipleChoice(let cfg):
            MetricEditor.Category(
                labels: cfg.labels,
                mainColor: mainColor,
                onAdd: { onAdd(.category(date(), $0)) }
            )
            .style(.multiple)

        case .binary(let cfg):
            MetricEditor.Binary(
                trueLabel: cfg.trueLabel,
                falseLabel: cfg.falseLabel,
                mainColor: mainColor,
                onAdd: { onAdd(.binary(date(), $0)) }
            )

        case .duration:
            MetricEditor.Duration(
                mainColor: mainColor,
                onAdd: { onAdd(.duration(date(), $0)) }
            )

        case .datetime(_):
            MetricEditor.Datetime(
                defaultValue: date(),
                mainColor: mainColor,
                onAdd: { onAdd(.datetime( $0 )) }
            )

        }

    }

    /// Sheet height each editor needs on its own, without the date row above it.
    ///
    /// These used to live as `.presentationDetents` inside each concrete editor,
    /// but `MetricEntrySheet` has to add the date row's height and then grow
    /// again for the day wheel — so the numbers belong wherever that sum is
    /// computed, in one table, rather than scattered across nine files. The
    /// editors' own previews present them without the wrapper, so they read the
    /// same constants rather than restating a height.
    enum EditorHeight {
        static let stepper: CGFloat = 250
        static let slider: CGFloat = 280
        static let picker: CGFloat = 300
        static let numberInput: CGFloat = 280
        static let category: CGFloat = 300
        static let binary: CGFloat = 280
        static let duration: CGFloat = 320
        static let datetime: CGFloat = 360
    }

    static func editorHeight(for metric: Metric) -> CGFloat {
        switch metric.config {
        case .number(let cfg):
            switch numberStyle(for: cfg) {
            case .stepper: return EditorHeight.stepper
            case .slider: return EditorHeight.slider
            case .picker: return EditorHeight.picker
            case .numberInput: return EditorHeight.numberInput
            }
        case .categorySingleChoice, .categoryMultipleChoice:
            return EditorHeight.category
        case .binary: return EditorHeight.binary
        case .duration: return EditorHeight.duration
        case .datetime: return EditorHeight.datetime
        }
    }

    /// Category editors offered a draggable `.medium` detent so a long list of
    /// choices could be opened up. Preserved here so adding the date row doesn't
    /// quietly drop it.
    static func allowsMediumDetent(for metric: Metric) -> Bool {
        switch metric.config {
        case .categorySingleChoice, .categoryMultipleChoice: return true
        default: return false
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
