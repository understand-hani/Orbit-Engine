import Foundation

struct AppConfig {
    static let appName = "圆周引擎"
    static let backendBaseURLKey = "backend_base_url"
    static let defaultBackendBaseURL = URL(string: "https://graphical-teeth-athletes-holds.trycloudflare.com")!

    static var backendBaseURL: URL {
        let storedValue = UserDefaults.standard.string(forKey: backendBaseURLKey)
        return storedValue.flatMap(URL.init(string:)) ?? defaultBackendBaseURL
    }
}
