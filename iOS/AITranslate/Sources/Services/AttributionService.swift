import Foundation
import AdServices

/// Apple Search Ads attribution: fetches the per-install token from AdServices
/// and POSTs it to Apple's attribution endpoint so installs are correctly
/// credited to ASA campaigns / keywords in the ASA dashboard.
///
/// Sends exactly once per install (idempotent via UserDefaults flag).
final class AttributionService {
    static let shared = AttributionService()
    private let sentKey = "asa.attribution.sent"
    private init() {}

    func trackAttribution() {
        guard !UserDefaults.standard.bool(forKey: sentKey) else { return }
        Task.detached(priority: .background) {
            do {
                let token = try AAAttribution.attributionToken()
                try await Self.postToApple(token: token)
                UserDefaults.standard.set(true, forKey: self.sentKey)
            } catch { /* silent */ }
        }
    }

    private static func postToApple(token: String) async throws {
        var req = URLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!)
        req.httpMethod = "POST"
        req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        req.httpBody = token.data(using: .utf8)
        _ = try await URLSession.shared.data(for: req)
    }
}
