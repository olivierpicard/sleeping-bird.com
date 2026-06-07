//
//  MetricEditor.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

enum MetricEditor {}

extension MetricEditor {
    enum NumberStyle { case stepper, slider, picker, numberInput }

    struct Number: View {
        let min: Double
        let max: Double
        let defaultValue: Double
        let step: Double
        let unit: String?
        let mainColor: Color
        let onAdd: (Double) -> Void
        private var style: NumberStyle = .stepper

        init(
            min: Double,
            max: Double,
            defaultValue: Double,
            step: Double,
            unit: String? = nil,
            mainColor: Color = .accentColor,
            onAdd: @escaping (Double) -> Void = { _ in }
        ) {
            self.min = min
            self.max = max
            self.defaultValue = defaultValue
            self.step = step
            self.unit = unit
            self.mainColor = mainColor
            self.onAdd = onAdd
        }

        func style(_ style: NumberStyle) -> Self {
            var copy = self
            copy.style = style
            return copy
        }

        var body: some View {
            switch style {
            case .stepper:
                _StepperEditor(
                    min: min,
                    max: max,
                    defaultValue: defaultValue,
                    step: step,
                    unit: unit,
                    mainColor: mainColor,
                    onAdd: onAdd
                )
            case .slider:
                _SliderEditor(
                    min: min,
                    max: max,
                    defaultValue: defaultValue,
                    step: step,
                    unit: unit,
                    mainColor: mainColor,
                    onAdd: onAdd
                )
            case .picker:
                _PickerEditor(
                    min: min,
                    max: max,
                    defaultValue: defaultValue,
                    step: step,
                    unit: unit,
                    mainColor: mainColor,
                    onAdd: onAdd
                )
            case .numberInput:
                _NumberInputEditor(
                    min: min,
                    max: max,
                    defaultValue: defaultValue,
                    step: step,
                    unit: unit,
                    mainColor: mainColor,
                    onAdd: onAdd
                )
            }
        }
    }

    enum CategoryStyle { case single, multiple }

    struct Category: View {
        let labels: [String]
        let mainColor: Color
        let onAdd: ([String]) -> Void
        private var style: CategoryStyle = .single

        init(
            labels: [String],
            mainColor: Color = .accentColor,
            onAdd: @escaping ([String]) -> Void = { _ in }
        ) {
            self.labels = labels
            self.mainColor = mainColor
            self.onAdd = onAdd
        }

        func style(_ style: CategoryStyle) -> Self {
            var copy = self
            copy.style = style
            return copy
        }

        var body: some View {
            switch style {
            case .single:
                _CategorySingleEditor(
                    labels: labels,
                    mainColor: mainColor,
                    onAdd: { label in onAdd([label]) }
                )
            case .multiple:
                _CategoryMultipleEditor(
                    labels: labels,
                    mainColor: mainColor,
                    onAdd: onAdd
                )
            }
        }
    }

    struct Duration: View {
        let granularity: String
        let maxInSeconds: Int
        let defaultValue: TimeInterval
        let mainColor: Color
        let onAdd: (TimeInterval) -> Void

        init(
            granularity: String,
            maxInSeconds: Int,
            defaultValue: TimeInterval = 0,
            mainColor: Color = .accentColor,
            onAdd: @escaping (TimeInterval) -> Void = { _ in }
        ) {
            self.granularity = granularity
            self.maxInSeconds = maxInSeconds
            self.defaultValue = defaultValue
            self.mainColor = mainColor
            self.onAdd = onAdd
        }

        var body: some View {
            _WheelEditor(
                granularity: _DurationGranularity(granularity),
                maxInSeconds: maxInSeconds,
                defaultValue: defaultValue,
                mainColor: mainColor,
                onAdd: onAdd
            )
        }
    }

    struct Datetime: View {
        let defaultValue: Date
        let mainColor: Color
        let onAdd: (Date) -> Void

        init(
            defaultValue: Date = Date(),
            mainColor: Color = .accentColor,
            onAdd: @escaping (Date) -> Void = { _ in }
        ) {
            self.defaultValue = defaultValue
            self.mainColor = mainColor
            self.onAdd = onAdd
        }

        var body: some View {
            _DatePickerEditor(
                defaultValue: defaultValue,
                mainColor: mainColor,
                onAdd: onAdd
            )
        }
    }

    struct Binary: View {
        let trueLabel: String
        let falseLabel: String
        let mainColor: Color
        let onAdd: (Bool) -> Void

        init(
            trueLabel: String = "Yes",
            falseLabel: String = "No",
            mainColor: Color = .accentColor,
            onAdd: @escaping (Bool) -> Void = { _ in }
        ) {
            self.trueLabel = trueLabel
            self.falseLabel = falseLabel
            self.mainColor = mainColor
            self.onAdd = onAdd
        }

        var body: some View {
            _BinaryEditor(
                trueLabel: trueLabel,
                falseLabel: falseLabel,
                mainColor: mainColor,
                onAdd: onAdd
            )
        }
    }
}
