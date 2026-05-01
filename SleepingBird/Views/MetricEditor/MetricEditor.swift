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

    struct Category: View {
        let labels: [String]
        let mainColor: Color
        let onAdd: ([String]) -> Void

        init(
            labels: [String],
            mainColor: Color = .accentColor,
            onAdd: @escaping ([String]) -> Void = { _ in }
        ) {
            self.labels = labels
            self.mainColor = mainColor
            self.onAdd = onAdd
        }

        var body: some View {
            _CategorySingleEditor(
                labels: labels,
                mainColor: mainColor,
                onAdd: { label in onAdd([label]) }
            )
        }
    }
}
