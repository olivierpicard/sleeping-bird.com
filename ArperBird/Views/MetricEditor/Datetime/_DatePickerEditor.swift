//
//  _DatePickerEditor.swift
//  SleepingBird
//
//  Created by Olivier Picard on 11/05/2026.
//

import SwiftUI

struct _DatePickerEditor: View {
    let defaultValue: Date
    let mainColor: Color
    let onAdd: (Date) -> Void

    @State private var value: Date
    @State private var now: Date = Date()

    init(
        defaultValue: Date,
        mainColor: Color,
        onAdd: @escaping (Date) -> Void
    ) {
        self.defaultValue = defaultValue
        self.mainColor = mainColor
        self.onAdd = onAdd
        _value = State(initialValue: Swift.min(defaultValue, Date()))
    }

    var body: some View {
        VStack(spacing: 24) {
            DatePicker(
                "",
                selection: $value,
                in: ...now,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .tint(mainColor)
            .padding(.horizontal)

            _SaveButton(mainColor: mainColor) { onAdd(value) }
        }
        .padding(.vertical, 24)
        .onAppear { now = Date() }
        .presentationDetents([.height(360)])
    }
}

#Preview("Now") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _DatePickerEditor(
                defaultValue: Date(),
                mainColor: .blue,
                onAdd: { _ in }
            )
        }
}
