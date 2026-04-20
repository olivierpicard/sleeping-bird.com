//
//  MetricChoice.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

//Task {
//    do {
//        let response = try await AiAccess().suggestMetric(for: instruction)
//        print(response)
//       
//    } catch {
//        print("AiAccess error: \(error)")
//    }
//}

import SwiftUI

struct MetricChoice: View {
    let instruction: String
    private let pages = ["Page 1", "Page 2", "Page 3"]
    
    var body: some View {
        TabView {
            ForEach(pages, id: \.self) { page in
                VStack {
                    Text(page)
                        .font(.largeTitle)
                    Button(action: {}) {
                        Text(
                            "I like this one"
                        )
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

#Preview {
    MetricChoice(instruction: "")
}

