//
//  FeedbackCardView.swift
//  ArperBird
//
//  Created by Olivier Picard on 09/06/2026.
//

import Darwin
import SwiftUI
import PostHog

struct FeedbackCardView: View {
    @Environment(\.openURL) private var openURL
    private let userId = UniqueIdentityStore().get()

    var body: some View {
        
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemFill))
                Text("💬")
                    .font(.largeTitle)
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading) {
                Text("An idea? A bug?")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Help us improve the app")
                    .font(.callout)
                    .foregroundStyle(.placeholder)

            }
            Spacer()
            Label("Open email", systemImage: "arrow.up.forward.square")
                .labelStyle(.iconOnly)
        }
        .background(.clear)
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture(perform: onCardTapped)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.gray), style: StrokeStyle(lineWidth: 1, dash: [6]))
                
        }
    }

    private func onCardTapped() {
        guard let url = feedbackURL else {
            PostHogSDK.shared.capture("feedback_openurl_failed")
            return
        }
        PostHogSDK.shared.capture("feedback_openurl_started")
        openURL(url)
    }

    private var deviceModel: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    private var feedbackURL: URL? {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let voiceLanguage = VoiceLanguageOption.saved.id

        let subject = String(format: String(localized: "Feedback Arper Bird version %@"), appVersion)
        let body = String(
            format: String(localized: """
            What I liked:


            What's buggy / bothered me:


            An idea:


            ---
            Version: %1$@ (%2$@)
            Device: %3$@ — iOS %4$@
            Locale: %5$@
            Voice: %6$@
            ID: %7$@
            """),
            appVersion,
            build,
            deviceModel,
            osVersion,
            Locale.current.identifier,
            voiceLanguage,
            userId
        )

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@sleeping-bird.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

#Preview {
    FeedbackCardView()
        .frame(height: 100)
        .environment(\.locale, Locale(identifier: "es"))
}
