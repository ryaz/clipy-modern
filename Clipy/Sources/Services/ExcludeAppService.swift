import AppKit

final class ExcludeAppService {
    static let shared = ExcludeAppService()
    private init() {}

    private var excludedBundleIDs: Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: Constants.excludedAppsKey) ?? []
        let defaults: Set<String> = ["com.agilebits.onepassword7","com.agilebits.onepassword-osx","com.dashlane.dashlane-osx","com.lastpass.LastPass","com.apple.keychainaccess"]
        return defaults.union(Set(stored))
    }

    func addExclusion(bundleID: String) {
        var c = UserDefaults.standard.stringArray(forKey: Constants.excludedAppsKey) ?? []
        if !c.contains(bundleID) { c.append(bundleID); UserDefaults.standard.set(c, forKey: Constants.excludedAppsKey) }
    }

    func removeExclusion(bundleID: String) {
        var c = UserDefaults.standard.stringArray(forKey: Constants.excludedAppsKey) ?? []
        c.removeAll { $0 == bundleID }; UserDefaults.standard.set(c, forKey: Constants.excludedAppsKey)
    }

    func frontProcessIsExcluded() -> Bool {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return excludedBundleIDs.contains(id)
    }
}
