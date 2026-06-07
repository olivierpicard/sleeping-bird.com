import Foundation

/// Builds a `mailto:` URL for the "Contact Support" flow, pre-filling the
/// recipient, a localized subject, and a diagnostic body (app version, build,
/// and the RevenueCat anonymous ID) so support requests arrive with the context
/// needed to help the user.
struct SupportMailLink {
    static let address = "support@sleeping-bird.com"

    let anonymousID: String

    /// The composed `mailto:` URL, or `nil` if it cannot be encoded.
    var url: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }

    private var subject: String {
        String(localized: "support.email.subject")
    }

    private var body: String {
        let appVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "—"
        let build =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "—"
        let device = "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"

        // A blank line for the user to type above, then a diagnostic block they
        // are asked to keep so we can identify the account.
        return String(
            localized: "support.email.body \(appVersion) \(build) \(device) \(anonymousID)"
        )
    }
}
