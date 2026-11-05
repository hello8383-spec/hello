import Foundation

/// Same options as the desktop app's electron-store defaults.
enum Prefs {
    static let defaults: [String: Any] = [
        "activityType": 3, "showProgress": true, "showSmallIcon": true, "clearOnPause": false,
        "customDetails": "{title}", "customState": "{channel}", "customLargeText": "",
        "showButton": true, "rpcEnabled": true,
    ]
    static func register() { UserDefaults.standard.register(defaults: defaults) }
    static var int: (String) -> Int { { UserDefaults.standard.integer(forKey: $0) } }
    static var bool: (String) -> Bool { { UserDefaults.standard.bool(forKey: $0) } }
    static var string: (String) -> String { { UserDefaults.standard.string(forKey: $0) ?? "" } }
}
