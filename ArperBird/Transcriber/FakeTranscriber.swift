import Foundation

/// DEBUG-only `Transcriber` that emits a hardcoded sentence word-by-word
/// to simulate live dictation in SwiftUI previews.
final class FakeTranscriber: Transcriber {
    private let words: [String]
    private let interval: TimeInterval
    private let micPermission: Bool
    private var timer: Timer?
    private var index: Int = 0
    private var accumulated: String = ""

    init(
        text: String = "I want to track how much coffee I drink per day",
        interval: TimeInterval = 0.25,
        hasMicPermission: Bool = true
    ) {
        self.words = text.split(separator: " ").map(String.init)
        self.interval = interval
        self.micPermission = hasMicPermission
    }

    var hasMicPermission: Bool { micPermission }

    func start(onText: @escaping (_ text: String) -> Void) {
        stop()
        index = 0
        accumulated = ""
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { return }
            guard self.index < self.words.count else {
                timer.invalidate()
                return
            }
            self.accumulated += (self.accumulated.isEmpty ? "" : " ") + self.words[self.index]
            self.index += 1
            onText(self.accumulated)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
