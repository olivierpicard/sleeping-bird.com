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
    @Environment(\.colorScheme) private var colorScheme



    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(alignment: .leading) {
                Text("SLEEPING BIRD")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(3)
                    .padding(.bottom, 15)
                    .foregroundStyle(.secondary)
                
                Text("What do you")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("Want to measure ?")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color(red: 0xe8/255, green: 0xee/255, blue: 0xf4/255),
                                Color(red: 0xa1/255, green: 0xb7/255, blue: 0xf6/255),
                            ] : [
                                Color(red: 0x64/255, green: 0x6c/255, blue: 0xf6/255),
                                Color(red: 0xc2/255, green: 0x5d/255, blue: 0xdd/255),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.bottom, 5)
                Text("Track anything you want. Just say it out loud.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            BadgesStackView(
                badges: [
                    "Water 💧",
                    "Maintenance 💰🚗",
                    "Sleeps 💤",
                    "Pain 😖",
                    "Mood 😁",
                    "Proteins 🥩🌱",
                    "Meditation ⏱️🧘",
                    "Coffee ☕️",
                    "Fuel Spend ⛽️",
                    "Ask anything..."
                ],
                borderThickness: 0.5
            )
            .padding(.top, 10)
            .padding(.trailing, 10)
            Spacer()
            VStack(spacing: -4) {
                Text("tap to start")
                    .font(.custom("Bradley Hand", size: 22))
                    .rotationEffect(.degrees(-3))
                    .offset(x: 28)
                HandDrawnArrow()
                    .stroke(
                        Color.primary.opacity(colorScheme == .dark ? 0.4 : 0.3),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [4, 6]
                        )
                    )
                    .frame(width: 80, height: 90)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, -20)
            .padding(.leading, 30)
            Button(action: { showModal = true }) {
                Label("Add a metric using voice", systemImage: "mic")
                    .font(.largeTitle)
                    .padding(.all, 8)
            }
            .labelStyle(.iconOnly)
            .controlSize(.extraLarge)
            .tint(Color(red: 0x64/255, green: 0x6c/255, blue: 0xf6/255))
            .buttonStyle(.glassProminent)
            .buttonStyle(.glass)

        }
        .padding()
        .background {
            EmptyDashboardBackground()
        }
        .sheet(
            isPresented: $showModal,
            onDismiss: { showModal = false }
        ) {
            MetricInputSheet(
                transcriber: DeepgramNova3Transcriber(),
                autoStartTranscription: true
            )
            .presentationDetents([.large])
        }
    }
}

private struct HandDrawnArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let start = CGPoint(x: w * 0.85, y: h * 0.05)
        let tip = CGPoint(x: w * 0.20, y: h * 1)

        path.move(to: start)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: w * 0.95, y: h * 0.55),
            control2: CGPoint(x: w * 0.10, y: h * 0.65)
        )

        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 15, y: tip.y - 10))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x + 15, y: tip.y - 10))

        return path
    }
}




#Preview {
    EmptyDashboardView()
        .environment(MetricGenerator())
        .modelContainer(for: Metric.self, inMemory: true)
}
