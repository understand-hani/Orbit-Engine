import Foundation

struct AppConfig {
    static let appName = "个人 Infra Agent"
    static let backendBaseURLKey = "backend_base_url"
    static let defaultBackendBaseURL = URL(string: "https://dominant-movements-rising-gmc.trycloudflare.com")!

    static var backendBaseURL: URL {
        let storedValue = UserDefaults.standard.string(forKey: backendBaseURLKey)
        return storedValue.flatMap(URL.init(string:)) ?? defaultBackendBaseURL
    }
}
