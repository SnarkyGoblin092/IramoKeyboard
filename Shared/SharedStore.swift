import Foundation

/// Where settings live, so that the app and the keyboard extension can share them.
///
/// Sharing needs an "App Group". Depending on how the IPA was signed, the group's name can be
/// changed by the signing tool or the group can be missing entirely, so the real name is looked up
/// at runtime instead of being assumed:
///   1. names listed in the app's Info.plist under `ALTAppGroups` (written by AltStore / SideStore),
///   2. groups granted by the embedded provisioning profile,
///   3. the name this project asks for.
/// The first one that really has a container on this device wins. If none does, settings fall back
/// to the extension's own storage and `isShared` is false (the keyboard then offers its own
/// settings panel, and the app says that syncing is unavailable).
enum SharedStore {
    static let requestedGroupID = "group.com.hunkeys.k9x4.shared"

    /// The group that works on this install, or nil when sharing is not possible.
    static let groupID: String? = resolveGroupID()

    static var isShared: Bool { return groupID != nil }

    static let defaults: UserDefaults = {
        if let id = groupID, let suite = UserDefaults(suiteName: id) {
            return suite
        }
        return UserDefaults.standard
    }()

    // MARK: Lookup

    private static func resolveGroupID() -> String? {
        var candidates: [String] = []
        if let listed = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            candidates.append(contentsOf: listed)
        }
        candidates.append(contentsOf: provisionedGroups())
        candidates.append(requestedGroupID)

        var unique: [String] = []
        for candidate in candidates where !unique.contains(candidate) {
            unique.append(candidate)
        }

        let usable = unique.filter {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
        }
        // App and keyboard must pick the same group, so the choice has to be deterministic.
        let preferred = usable.filter { $0.hasPrefix(requestedGroupID) }.sorted()
        if let first = preferred.first { return first }
        return usable.sorted().first
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
              let entitlements = dictionary["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else {
            return []
        }
        return groups
    }
}
