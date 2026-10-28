import Foundation
import Security

// MARK: - Sync keys

enum SyncKey {
    /// Written by the app's "Test sync" button; the keyboard echoes it back in its status.
    static let nonce = "hunkeys.sync.nonce"
    static let echoNonce = "hunkeys.status.echoNonce"
    /// Time stamps: the app asks the keyboard to clear recent emoji / learned words.
    static let clearRecents = "hunkeys.cmd.clearRecents"
    static let clearLearned = "hunkeys.cmd.clearLearned"
    /// Keyboard-local bookkeeping (never sent anywhere).
    static let lastApplied = "hunkeys.local.lastApplied"
    static let handledClearRecents = "hunkeys.local.handledClearRecents"
    static let handledClearLearned = "hunkeys.local.handledClearLearned"

    /// App -> keyboard.
    static let syncedKeys: [String] = SettingKey.preferenceKeys + [
        SettingKey.shortcuts, nonce, clearRecents, clearLearned
    ]
    /// Keyboard -> app.
    static let statusKeys: [String] = [
        SettingKey.lastSeen, SettingKey.fullAccess, SettingKey.emojiVersion,
        SettingKey.emojiTotal, SettingKey.emojiShown, echoNonce
    ]
}

enum SyncTransport: String {
    case appGroup, keychain, none

    var label: String {
        switch self {
        case .appGroup: return "App Group"
        case .keychain: return "Shared Keychain"
        case .none: return "None (manual paste)"
        }
    }
}

// MARK: - Keychain helper

enum KeychainBox {
    static let service = "com.hunkeys.sync"

    private static func query(account: String, group: String?) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group = group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    static func read(account: String, group: String?) -> (data: Data?, status: OSStatus) {
        var q = query(account: account, group: group)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        return (status == errSecSuccess ? (result as? Data) : nil, status)
    }

    @discardableResult
    static func write(_ data: Data, account: String, group: String?) -> OSStatus {
        let q = query(account: account, group: group)
        var status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = q
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        return status
    }

    /// The Team ID this build was signed with, read from the access group iOS gives a new item.
    static func discoverTeamID() -> String? {
        var q = query(account: "probe", group: nil)
        q[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        var status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound {
            var add = query(account: "probe", group: nil)
            add[kSecValueData as String] = Data([1])
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecReturnAttributes as String] = true
            result = nil
            status = SecItemAdd(add as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String,
              let team = group.split(separator: ".").first.map(String.init),
              team.count == 10 else {
            return nil
        }
        return team
    }
}

// MARK: - SharedStore

/// How settings travel between the HunKeys app and its keyboard extension.
///
/// The two are separate processes with separate storage, so a channel both can reach is needed.
/// Several are used at once, best first:
///   1. App Group UserDefaults - needs the App Group entitlement to survive re-signing, and iOS only
///      lets a keyboard use shared storage when "Allow Full Access" is on.
///   2. A shared Keychain access group named after the Team ID (found at runtime). Needs the
///      signing tool to grant `keychain-access-groups`; whether a free Apple ID does depends on the tool.
///   3. A manual fallback: the app copies the settings as text and the keyboard's paste tool imports it.
/// Nothing here can be verified without a real device; the app's "Test sync" button reports what works.
enum SharedStore {
    static let requestedGroupID = "group.com.hunkeys.k9x4.shared"
    static let keychainGroupName = "com.hunkeys.k9x4.shared"
    static let exportPrefix = "HUNKEYS1:"

    /// True inside the keyboard extension, false in the app.
    static let isExtension: Bool = Bundle.main.bundlePath.hasSuffix(".appex")

    /// The App Group that has a container on this device, or nil.
    static let groupID: String? = resolveGroupID()

    /// "<TeamID>.com.hunkeys.k9x4.shared" when the keychain group passed a write/read test.
    static let keychainGroup: String? = resolveKeychainGroup()
    private(set) static var keychainDiagnosis: String = ""
    private(set) static var teamID: String?

    static var activeTransport: SyncTransport {
        if groupID != nil { return .appGroup }
        if keychainGroup != nil { return .keychain }
        return .none
    }

    /// True when some automatic channel exists (it may still be blocked by Full Access).
    static var isShared: Bool { return activeTransport != .none }

    static var transportLabel: String {
        var parts: [String] = []
        if groupID != nil { parts.append(SyncTransport.appGroup.label) }
        if keychainGroup != nil { parts.append(SyncTransport.keychain.label) }
        return parts.isEmpty ? SyncTransport.none.label : parts.joined(separator: " + ")
    }

    static let defaults: UserDefaults = {
        if let id = groupID, let suite = UserDefaults(suiteName: id) {
            return suite
        }
        return UserDefaults.standard
    }()

    // MARK: App group lookup

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

    // MARK: Keychain lookup

    private static func resolveKeychainGroup() -> String? {
        guard let team = KeychainBox.discoverTeamID() else {
            keychainDiagnosis = "No Team ID found (the app isn't signed with a developer identity)."
            return nil
        }
        teamID = team
        let group = team + "." + keychainGroupName
        let probe = Data("ok".utf8)
        let writeStatus = KeychainBox.write(probe, account: "selftest", group: group)
        guard writeStatus == errSecSuccess else {
            keychainDiagnosis = writeStatus == errSecMissingEntitlement
                ? "Keychain sharing isn't granted by the signing (error -34018)."
                : "Keychain write failed (error \(writeStatus))."
            return nil
        }
        let readBack = KeychainBox.read(account: "selftest", group: group)
        guard readBack.data == probe else {
            keychainDiagnosis = "Keychain read-back failed (error \(readBack.status))."
            return nil
        }
        keychainDiagnosis = "Keychain group OK for this process."
        return group
    }

    // MARK: Payloads

    private static func encode(stamp: Double, values: [String: Any]) -> Data? {
        let root: [String: Any] = ["stamp": stamp, "values": values]
        return try? PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
    }

    private static func decode(_ data: Data) -> (stamp: Double, values: [String: Any])? {
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let root = object as? [String: Any],
              let stamp = root["stamp"] as? Double,
              let values = root["values"] as? [String: Any] else {
            return nil
        }
        return (stamp, values)
    }

    private static func currentValues() -> [String: Any] {
        var values: [String: Any] = [:]
        for key in SyncKey.syncedKeys {
            if let value = defaults.object(forKey: key) { values[key] = value }
        }
        return values
    }

    // MARK: App side: send settings

    private static var lastPublished: [String: Any]?

    /// Pushes all keyboard-relevant settings into the Keychain channel. Cheap; skips unchanged data.
    static func publishPreferences() {
        guard let group = keychainGroup else { return }
        let values = currentValues()
        if let last = lastPublished, NSDictionary(dictionary: last).isEqual(to: values) { return }
        guard let data = encode(stamp: Date().timeIntervalSince1970, values: values) else { return }
        if KeychainBox.write(data, account: "prefs", group: group) == errSecSuccess {
            lastPublished = values
        }
    }

    /// Text the user can paste into the keyboard (manual channel).
    static func exportString() -> String {
        let data = encode(stamp: Date().timeIntervalSince1970, values: currentValues()) ?? Data()
        return exportPrefix + data.base64EncodedString()
    }

    // MARK: Keyboard side: receive settings

    private static var lastRefresh = Date.distantPast

    /// Called whenever the keyboard reads a setting; checks the Keychain channel at most once a second.
    static func refreshIfNeeded() {
        guard isExtension else { return }
        let now = Date()
        guard now.timeIntervalSince(lastRefresh) > 1.0 else { return }
        lastRefresh = now
        pullPreferences()
    }

    @discardableResult
    static func pullPreferences() -> Bool {
        lastRefresh = Date()
        guard let group = keychainGroup,
              let data = KeychainBox.read(account: "prefs", group: group).data,
              let payload = decode(data) else {
            return false
        }
        return apply(payload.stamp, payload.values, force: false)
    }

    static func isSettingsPayload(_ text: String) -> Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(exportPrefix)
    }

    /// Imports text produced by `exportString()`. Returns false if it isn't valid.
    @discardableResult
    static func importSettings(from text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(exportPrefix),
              let data = Data(base64Encoded: String(trimmed.dropFirst(exportPrefix.count))),
              let payload = decode(data) else {
            return false
        }
        return apply(payload.stamp, payload.values, force: true)
    }

    private static func apply(_ stamp: Double, _ values: [String: Any], force: Bool) -> Bool {
        if !force && stamp <= defaults.double(forKey: SyncKey.lastApplied) { return false }
        for key in SyncKey.syncedKeys {
            if let value = values[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(max(stamp, defaults.double(forKey: SyncKey.lastApplied)), forKey: SyncKey.lastApplied)
        handleCommands()
        return true
    }

    private static func handleCommands() {
        let recents = defaults.double(forKey: SyncKey.clearRecents)
        if recents > defaults.double(forKey: SyncKey.handledClearRecents) {
            defaults.removeObject(forKey: SettingKey.recentEmoji)
            defaults.set(recents, forKey: SyncKey.handledClearRecents)
        }
        let learned = defaults.double(forKey: SyncKey.clearLearned)
        if learned > defaults.double(forKey: SyncKey.handledClearLearned) {
            for code in ["en", "hu"] { defaults.removeObject(forKey: SettingKey.learnedPrefix + code) }
            defaults.set(learned, forKey: SyncKey.handledClearLearned)
        }
    }

    // MARK: Status (keyboard -> app)

    /// Keyboard: copies the status values into the Keychain channel (the App Group channel needs no copy).
    static func publishStatus() {
        guard let group = keychainGroup else { return }
        var status: [String: Any] = [:]
        for key in SyncKey.statusKeys {
            if let value = defaults.object(forKey: key) { status[key] = value }
        }
        guard let data = encode(stamp: Date().timeIntervalSince1970, values: status) else { return }
        KeychainBox.write(data, account: "status", group: group)
    }

    /// App: the newest status from either channel.
    static func readStatus() -> [String: Any] {
        var fromDefaults: [String: Any] = [:]
        for key in SyncKey.statusKeys {
            if let value = defaults.object(forKey: key) { fromDefaults[key] = value }
        }
        var fromKeychain: [String: Any] = [:]
        if let group = keychainGroup,
           let data = KeychainBox.read(account: "status", group: group).data,
           let payload = decode(data) {
            fromKeychain = payload.values
        }
        let seenDefaults = fromDefaults[SettingKey.lastSeen] as? Double ?? 0
        let seenKeychain = fromKeychain[SettingKey.lastSeen] as? Double ?? 0
        return seenKeychain > seenDefaults ? fromKeychain : fromDefaults
    }
}
