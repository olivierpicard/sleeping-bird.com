////
////  HeaderDetail.swift
////  ArperBird
////
////  Created by Olivier Picard on 03/05/2026.
////
//
//import SwiftUI
//
//struct HeaderDetail: View {
//    @Biding var currentValue: String
//    
//    init(metric: Metric) {
//        self.metric = metric
//        
//    }
//    
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading) {
//                HStack {
//                    Text(metric.emoji)
//                    Text(metric.name)
//                }
//                .font(.title)
//                HStack {
//                    Text(displayedValue)
//                    Text(metric.config)
//                    
//                }
//                .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//}
//
//#Preview {
//    NavigationStack {
//        MetricDetailView(
//            metric: Metric(
//                from: MetricSchema.Fake.number(
//                    title: "Daily Steps",
//                    emoji: "👟"
//                ),
//                data: Metric.fakeData(for: MetricSchema.Fake.number().config)
//            )
//        )
//    }
//}
