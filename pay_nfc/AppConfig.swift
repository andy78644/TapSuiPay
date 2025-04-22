import Foundation

/// Loads config values from Config.plist (which should be gitignored)
class AppConfig {
    static let shared = AppConfig()
    private var config: [String: Any] = [:]
    private init() {
        if let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            config = dict
        }
    }
    var clientId: String? { config["CLIENT_ID"] as? String }
    var redirectUri: String? { config["REDIRECT_URI"] as? String }
}
