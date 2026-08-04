import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var backendBaseURL: String = AppConfig.backendBaseURL.absoluteString
    @Published private(set) var savedBackendBaseURL: String = AppConfig.backendBaseURL.absoluteString
    @Published private(set) var backendURLMessage: String?
    @Published var defaultNotificationTime: String = "06:00"

    func saveBackendBaseURL() {
        let trimmedValue = backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedValue), url.scheme != nil, url.host != nil else {
            backendURLMessage = "URL 无效"
            return
        }
        let normalizedValue = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        UserDefaults.standard.set(normalizedValue, forKey: AppConfig.backendBaseURLKey)
        backendBaseURL = normalizedValue
        savedBackendBaseURL = normalizedValue
        backendURLMessage = "已保存"
    }

    func resetBackendBaseURL() {
        backendBaseURL = AppConfig.defaultBackendBaseURL.absoluteString
        savedBackendBaseURL = AppConfig.defaultBackendBaseURL.absoluteString
        UserDefaults.standard.removeObject(forKey: AppConfig.backendBaseURLKey)
        backendURLMessage = "已恢复默认值"
    }

    func reload() {
        let value = AppConfig.backendBaseURL.absoluteString
        backendBaseURL = value
        savedBackendBaseURL = value
        backendURLMessage = nil
    }
}
