//
//  StartView.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/05/2026.
//

import CoreImage
import SwiftUI
import UIKit

struct StartView: View {

    var onStart: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    @State private var titleAppeared = false
    @State private var subtitleAppeared = false
    @State private var revealedEmojis: Set<Int> = []
    @State private var buttonAppeared = false
    @State private var footerAppeared = false
    @State private var floatPhase = false

    @State private var showLegal = false

    private let emojiCards: [EmojiCard] = [
        .init(emoji: "☕️"),
        .init(emoji: "💊"),
        .init(emoji: "📈"),
        .init(emoji: "⛽️"),
        .init(emoji: "🧘"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            titleBlock
            emojiStack
                .frame(height: 220)
                .padding(.top, 32)
            Spacer(minLength: 20)
            ctaBlock
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            EmptyDashboardBackground(intensity: 0.6)
                .ignoresSafeArea()
        }
        .onAppear(perform: runEntranceAnimation)
        .trackScreen("Onboarding_Start")
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(alignment: .center, spacing: 12) {

            VStack(alignment: .center, spacing: 4) {
                Text("Welcome 👋")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text("Arper Bird")
                    .font(.system(size: 45))
                    .fontWeight(.heavy)
                    .foregroundStyle(brandGradient)
            }
            .multilineTextAlignment(.center)
            .opacity(titleAppeared ? 1 : 0)

            Text("Track what matters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(subtitleAppeared ? 1 : 0)
                .offset(y: subtitleAppeared ? 0 : 12)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf4 / 255),
                    Color(red: 0xa1 / 255, green: 0xb7 / 255, blue: 0xf6 / 255),
                ]
                : [
                    Color(red: 0x64 / 255, green: 0x6c / 255, blue: 0xf6 / 255),
                    Color(red: 0xc2 / 255, green: 0x5d / 255, blue: 0xdd / 255),
                ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: Emoji stack

    private var emojiStack: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                ForEach(Array(emojiCards.enumerated()), id: \.offset) { index, card in
                    emojiBubble(card, index: index, center: center)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func emojiBubble(_ card: EmojiCard, index: Int, center: CGPoint) -> some View {
        let middle = Double(emojiCards.count - 1) / 2.0
        let offsetFromCenter = Double(index) - middle
        let spread: CGFloat = 65
        let isCenter = abs(offsetFromCenter) < 0.5
        let size: CGFloat = isCenter ? 120 : (abs(offsetFromCenter) < 1.5 ? 100 : 84)
        let rotation: Double = offsetFromCenter * 8
        let zIndex: Double = isCenter ? 10 : (10 - abs(offsetFromCenter))

        let shown = revealedEmojis.contains(index)

        let restingX = center.x + CGFloat(offsetFromCenter) * spread
        let restingY = center.y + abs(offsetFromCenter) * 6
        let startX = center.x
        let startY = center.y + 40
        let floatY: CGFloat = floatPhase
            ? CGFloat(sin(Double(index) * 1.2) * 6)
            : CGFloat(-sin(Double(index) * 1.2) * 6)

        return ZStack {
            Circle()
                .fill(.regularMaterial)

            Circle()
                .fill(card.tint.opacity(0.45))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.0),
                        ],
                        center: .init(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
            

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            Color.white.opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            Text(card.emoji)
                .font(.system(size: size * 0.55))
        }
        .frame(width: size, height: size)
        .shadow(color: card.tint.opacity(0.5), radius: 24, x: 0, y: 12)
        .rotationEffect(.degrees(rotation))
        .position(
            x: shown ? restingX : startX,
            y: (shown ? restingY : startY) + floatY
        )
        .scaleEffect(shown ? 1 : 0.3)
        .opacity(shown ? 1 : 0)
        .zIndex(zIndex)
        .accessibilityHidden(true)
    }

    // MARK: CTA

    private var ctaBlock: some View {
        VStack(spacing: 16) {
            Button(action: onStart) {
                Label("Get Started", systemImage: "arrow.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .tint(.indigo)
            .opacity(buttonAppeared ? 1 : 0)
            .scaleEffect(buttonAppeared ? 1 : 0.92)
            .offset(y: buttonAppeared ? 0 : 20)

            Text("By continuing, you agree to our [Terms and Privacy Policy](arperbird://legal).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tint(.indigo)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(footerAppeared ? 1 : 0)
                .environment(\.openURL, OpenURLAction { _ in
                    showLegal = true
                    return .handled
                })
        }
        .sheet(isPresented: $showLegal) {
            TermsAndPrivacyView()
        }
    }

    // MARK: Animation

    private func runEntranceAnimation() {
        withAnimation(.spring(response: 1.3, dampingFraction: 0.85)) {
            titleAppeared = true
        }
        withAnimation(.spring(response: 1.3, dampingFraction: 0.85).delay(0.35)) {
            subtitleAppeared = true
        }

        // Spread the emojis in from the center outward with a gentle stagger.
        let middle = Double(emojiCards.count - 1) / 2.0
        let revealOrder = emojiCards.indices.sorted {
            abs(Double($0) - middle) < abs(Double($1) - middle)
        }
        for (rank, index) in revealOrder.enumerated() {
            let delay = 0.7 + Double(rank) * 0.08
            withAnimation(.spring(response: 0.9, dampingFraction: 0.78).delay(delay)) {
                _ = revealedEmojis.insert(index)
            }
        }

        withAnimation(.spring(response: 1.1, dampingFraction: 0.75).delay(1.4)) {
            buttonAppeared = true
        }
        withAnimation(.easeOut(duration: 0.9).delay(1.7)) {
            footerAppeared = true
        }
        withAnimation(
            .easeInOut(duration: 2.6)
                .repeatForever(autoreverses: true)
                .delay(2.0)
        ) {
            floatPhase = true
        }
    }
}

private struct EmojiCard {
    let emoji: String
    let tint: Color

    init(emoji: String) {
        self.emoji = emoji
        self.tint = Color.dominantColor(of: emoji)
    }
}

private extension Color {
    /// Renders an emoji and computes its average color, used to tint its bubble.
    static func dominantColor(of emoji: String) -> Color {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let font = UIFont.systemFont(ofSize: 48)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let text = emoji as NSString
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attributes)
        }

        guard let ciImage = CIImage(image: image) else { return .gray }

        let extent = ciImage.extent
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        guard
            let filter = CIFilter(
                name: "CIAreaAverage",
                parameters: [
                    kCIInputImageKey: ciImage,
                    kCIInputExtentKey: CIVector(cgRect: extent),
                ]
            ),
            let output = filter.outputImage
        else { return .gray }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let alpha = CGFloat(bitmap[3]) / 255
        guard alpha > 0 else { return .gray }

        // Un-premultiply so transparent emoji edges don't darken the result.
        let red = CGFloat(bitmap[0]) / 255 / alpha
        let green = CGFloat(bitmap[1]) / 255 / alpha
        let blue = CGFloat(bitmap[2]) / 255 / alpha

        return Color(red: min(red, 1), green: min(green, 1), blue: min(blue, 1))
    }
}

#Preview {
    StartView()
        .environment(\.locale, Locale(identifier: "es"))
}
