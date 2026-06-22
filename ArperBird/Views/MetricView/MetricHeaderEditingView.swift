//
//  MetricHeaderEditingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI

/// An editable metric header: emoji + a name text field.
/// No value and no "add entry" button — used while creating a tracker.
struct MetricHeaderEditingView: View {
    let emoji: String
    let mainColor: Color
    @Binding var title: String
    var placeholder: String = ""
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack {
            MetricHeaderEmoji(emoji: emoji, mainColor: mainColor)

            titleField

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var titleField: some View {
        let field = TextField(placeholder, text: $title)
            .font(.title2)
            .fontWeight(.semibold)
        if let focus {
            field.focused(focus)
        } else {
            field
        }
    }
}

#Preview {
    @Previewable @State var title = ""
    MetricHeaderEditingView(
        emoji: "🫥",
        mainColor: .gray,
        title: $title,
        placeholder: "Tracker name"
    )
    .padding()
}
