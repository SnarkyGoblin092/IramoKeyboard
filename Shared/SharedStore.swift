import Foundation

/// Where the app and the keyboard extension keep their shared settings.
///
/// They are separate processes, so they share an App Group container (the entitlement is added when
/// the IPA is built, and the installer - iloader, AltStore, ... - keeps it when re-signing). iOS only
/// lets a keyboard use shared storage when "Allow Full Access" is on. If no group is reachable, each
/// process falls back to its own private storage and `isShared` is false.
enum SharedStore {
    static let requestedGroupID = "group.com.hunkeys.k9x4.shared"

    /// The App Group that has a container on this device, or nil.
    static let groupID: String? = resolveGroupID()

    /// True when the app and the keyboard really share storage.
    static var isShared: Bool { return groupID != nil }

    static let defaults: UserDefaults = {
        if let id = groupID, let suite = UserDefaults(suiteName: id) {
            return suite
        }
        return UserDefaults.standard
    }()

    // MARK: App group lookup

    private static func resolveGroupID() -> String? {
        var candidates: [String] = []
        func add(_ id: String) {
            if !candidates.contains(id) { candidates.append(id) }
        }

        // Installers like AltStore / SideStore rewrite the group name and list it in Info.plist.
        for id in Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? [] { add(id) }
        // The provisioning profile names the groups the signing really granted.
        for id in provisionedGroups() { add(id) }
        // The name built into HunKeys.
        add(requestedGroupID)

        let usable = candidates.filter { id in
            guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else { return false }
            return FileManager.default.isReadableFile(atPath: url.path)
        }

        // App and keyboard must pick the same group, so the choice has to be deterministic.
        let preferred = usable.filter { $0.hasPrefix(requestedGroupID) }.sorted()
        return preferred.first ?? usable.sorted().first
    }

    /// App groups named in this bundle's provisioning profile (present when signed for a device).
    private static func provisionedGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              start.lowerBound < end.upperBound else {
            return []
        }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let entitlements = dictionary["Entitlements"] as? [String: Any] else {
            return []
        }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }
}
