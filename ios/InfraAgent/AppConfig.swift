import Foundation

struct AppConfig {
    static let appName = "圆周引擎"
    static let backendBaseURLKey = "backend_base_url"
    static let defaultBackendBaseURL = URL(string: "https://flex-islands-four-aurora.trycloudflare.com")!
    private static let legacyDefaultBackendBaseURLs = [
        "https://habitat-sequence-investigated-geek.trycloudflare.com",
        "https://graphical-teeth-athletes-holds.trycloudflare.com"
    ]

    static var backendBaseURL: URL {
        let storedValue = UserDefaults.standard.string(forKey: backendBaseURLKey)
        if let storedValue, legacyDefaultBackendBaseURLs.contains(storedValue) {
            return defaultBackendBaseURL
        }
        return storedValue.flatMap(URL.init(string:)) ?? defaultBackendBaseURL
    }
}
