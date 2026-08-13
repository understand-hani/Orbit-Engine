import Foundation

struct AppConfig {
    static let appName = "圆周引擎"
    static let backendBaseURLKey = "backend_base_url"
    static let apiTimeoutInterval: TimeInterval = 30
    static let defaultBackendBaseURL = URL(string: "https://basis-assignment-capable-soc.trycloudflare.com")!
    private static let legacyDefaultBackendBaseURLs = [
        "https://limits-celebrate-ide-termination.trycloudflare.com",
        "https://refused-atom-org-soil.trycloudflare.com",
        "https://builder-estimates-leads-beneath.trycloudflare.com",
        "https://fairfield-rpm-leo-sacred.trycloudflare.com",
        "https://flex-islands-four-aurora.trycloudflare.com",
        "https://habitat-sequence-investigated-geek.trycloudflare.com",
        "https://graphical-teeth-athletes-holds.trycloudflare.com",
        "https://mounting-harvard-bicycle-grove.trycloudflare.com",
        "https://psychological-merger-cedar-qualifying.trycloudflare.com",
        "https://lemon-somehow-sussex-adrian.trycloudflare.com",
        "https://telephony-locator-billing-empirical.trycloudflare.com",
        "https://times-com-submit-vids.trycloudflare.com",
        "https://sequences-careers-present-exhaust.trycloudflare.com",
        "https://ssl-mirror-unsigned-championships.trycloudflare.com",
        "https://comparable-electron-filename-period.trycloudflare.com",
        "https://explaining-discount-limitations-tribe.trycloudflare.com",
        "https://needle-mar-diameter-mortality.trycloudflare.com",
        "https://encouraged-okay-rom-string.trycloudflare.com",
        "https://express-cons-gamma-nose.trycloudflare.com",
        "https://continuous-ranges-contacted-licence.trycloudflare.com",
        "https://proof-usb-inspiration-surgeon.trycloudflare.com",
        "https://guru-aaron-allowed-hawk.trycloudflare.com",
        "https://village-seat-pollution-playstation.trycloudflare.com"
    ]

    static var backendBaseURL: URL {
        let storedValue = UserDefaults.standard.string(forKey: backendBaseURLKey)
        if let storedValue, legacyDefaultBackendBaseURLs.contains(storedValue) {
            return defaultBackendBaseURL
        }
        return storedValue.flatMap(URL.init(string:)) ?? defaultBackendBaseURL
    }
}
