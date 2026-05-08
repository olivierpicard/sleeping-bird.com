//
//  EmptyDashboardView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import SwiftData
import SwiftUI

struct EmptyDashboardView: View {
    @State private var showModal = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(alignment: .leading) {
                Text("SLEEPING BIRD")
                    .font(.subheadline)
                    .padding(.bottom, 15)
                Text("What do you")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("Want to measure ?")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .padding(.bottom, 10)
                Text("Just say it out loud. we'll figure out the rest.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            BadgesStackView(badges: [
                "Water",
                "Sleeps",
                "Pain",
                "Mood",
                "Relax Time",
                "Coffee",
                "Meat ate",
                "Car cost",
            ])
            .padding(.top, 10)
            Spacer()
            Button(action: {}) {
                Label("Add a metric using voice", systemImage: "mic")
                    .font(.largeTitle)
                    .padding(.all, 8)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)

        }
        .padding()
        .sheet(
            isPresented: $showModal,
            onDismiss: { showModal = false }
        ) {
            MetricInputSheet(
                transcriber: DeepgramNova3Transcriber()
            )
            .presentationDetents([.large])
        }
    }
}

#Preview {
    EmptyDashboardView()
        .environment(MetricGenerator())
        .modelContainer(for: Metric.self, inMemory: true)
}
