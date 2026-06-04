//
//  EmptyDashboardView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import SwiftData
import SwiftUI

struct EmptyDashboardView: View {
    let onAddMetric: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(alignment: .leading) {
                Text(String(localized: "empty_dashboard.app_name"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(3)
                    .padding(.bottom, 2)
                    .foregroundStyle(.secondary)

                Text(String(localized: "empty_dashboard.headline_1"))
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(String(localized: "empty_dashboard.headline_2"))
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [
                                    Color(
                                        red: 0xe8 / 255,
                                        green: 0xee / 255,
                                        blue: 0xf4 / 255
                                    ),
                                    Color(
                                        red: 0xa1 / 255,
                                        green: 0xb7 / 255,
                                        blue: 0xf6 / 255
                                    ),
                                ]
                                : [
                                    Color(
                                        red: 0x64 / 255,
                                        green: 0x6c / 255,
                                        blue: 0xf6 / 255
                                    ),
                                    Color(
                                        red: 0xc2 / 255,
                                        green: 0x5d / 255,
                                        blue: 0xdd / 255
                                    ),
                                ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.bottom, 5)
                Text(String(localized: "empty_dashboard.subtitle"))
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            BadgesStackView(
                badges: [
                    String(localized: "empty_dashboard.badge.water"),
                    String(localized: "empty_dashboard.badge.maintenance"),
                    String(localized: "empty_dashboard.badge.sleeps"),
                    String(localized: "empty_dashboard.badge.pain"),
                    String(localized: "empty_dashboard.badge.mood"),
                    String(localized: "empty_dashboard.badge.proteins"),
                    String(localized: "empty_dashboard.badge.meditation"),
                    String(localized: "empty_dashboard.badge.coffee"),
                    String(localized: "empty_dashboard.badge.fuel_spend"),
                    String(localized: "empty_dashboard.badge.ask_anything"),
                ],
                borderThickness: 0.5
            )
            .padding(.top, 10)
            //            Spacer()
            VStack(spacing: -4) {
                Text(String(localized: "empty_dashboard.tap_to_start"))
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
            Button(action: onAddMetric) {
                Label(
                    String(localized: "empty_dashboard.add_metric"),
                    systemImage: "plus"
                )
                .font(.largeTitle)
                .labelStyle(.iconOnly)
                .frame(width: 40, height: 40)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .tint(.indigo)

        }
        .padding()
        .trackScreen("EmptyDashboard")
        //        .background {
        //            EmptyDashboardBackground()
        //        }
        //        .sheet(
        //            isPresented: $showModal,
        //            onDismiss: { showModal = false }
        //        ) {
        //            MetricInputSheet()
        //                .presentationDetents([.large])
        //        }
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
    EmptyDashboardView(onAddMetric: {})
        .environment(\.locale, Locale(identifier: "fr"))
        .environment(MetricGenerator())
        .modelContainer(for: Metric.self, inMemory: true)
}
