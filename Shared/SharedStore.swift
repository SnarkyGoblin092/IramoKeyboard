import Foundation
import Security
import UIKit

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

    /// Why the App Group could not be used (nil when it works). Drives the messages in the app and keyboard.
    enum GroupFailure {
        case notGranted                       // the installer never registered an App Group
        case containerUnavailable(String)     // a group was registered but iOS gives no container
    }
    private(set) static var groupFailure: GroupFailure? = nil
    /// One line per candidate, e.g. "group.x.TEAM (from ALTAppGroups): no container". Shown in the app.
    private(set) static var groupDiagnostics: [String] = []

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
        var log: [String] = []
        var candidates: [(id: String, source: String)] = []
        func add(_ id: String, _ source: String) {
            if !candidates.contains(where: { $0.id == id }) { candidates.append((id, source)) }
        }

        // AltStore / SideStore rewrite the group (group.x -> group.x.<TeamID>) and list it here.
        // The key is written separately into the app's and the keyboard's Info.plist.
        let listed = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        if listed.isEmpty {
            log.append("Info.plist: no ALTAppGroups key (AltStore/SideStore didn't register a group).")
        }
        for id in listed { add(id, "ALTAppGroups") }

        // A provisioning profile embedded in the bundle names the groups the signing really granted.
        let profile = provisionedGroups()
        switch profile.state {
        case .missing:
            log.append("No embedded.mobileprovision in this bundle.")
        case .unreadable:
            log.append("embedded.mobileprovision could not be read.")
        case .read:
            if profile.groups.isEmpty {
                log.append("embedded.mobileprovision: the profile contains no App Groups.")
            }
        }
        for id in profile.groups { add(id, "provisioning profile") }

        // The name built into HunKeys (works when it was signed with a profile that grants it as-is).
        add(requestedGroupID, "built-in name")

        var usable: [String] = []
        for candidate in candidates {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate.id),
               FileManager.default.isReadableFile(atPath: url.path) {
                usable.append(candidate.id)
                log.append("\(candidate.id) (\(candidate.source)): container OK.")
            } else {
                log.append("\(candidate.id) (\(candidate.source)): iOS gives no container (group not granted to this signature).")
            }
        }

        // App and keyboard must pick the same group, so the choice has to be deterministic.
        let preferred = usable.filter { $0.hasPrefix(requestedGroupID) }.sorted()
        let chosen = preferred.first ?? usable.sorted().first

        if chosen == nil {
            let registered = listed.first ?? profile.groups.first
            if let registered = registered {
                groupFailure = .containerUnavailable(registered)
            } else {
                groupFailure = .notGranted
            }
        }
        groupDiagnostics = log
        return chosen
    }

    private enum ProfileState { case missing, unreadable, read }

    /// App groups named in this bundle's provisioning profile (present when signed for a device).
    private static func provisionedGroups() -> (state: ProfileState, groups: [String]) {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            return (.missing, [])
        }
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              start.lowerBound < end.upperBound else {
            return (.unreadable, [])
        }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let entitlements = dictionary["Entitlements"] as? [String: Any] else {
            return (.unreadable, [])
        }
        let groups = entitlements["com.apple.security.application-groups"] as? [String] ?? []
        return (.read, groups)
    }

    // MARK: Explanations (shown in the app and, shortened, in the keyboard)

    /// What is going on and what to do about it. Empty when an automatic channel works.
    static var syncExplanation: String {
        if isShared { return "" }
        switch groupFailure {
        case .containerUnavailable(let id)?:
            return "The installer registered the App Group \(id), but iOS gives this build no access to it. Delete the app and reinstall HunKeys-AppGroup.ipa with AltStore or SideStore, or use \"Send settings to keyboard\" below."
        default:
            return "This install has no shared storage between the app and the keyboard. That is normal with Sideloadly and a free Apple ID: iOS only lets apps share storage through an App Group or a shared Keychain, and a free account can't be granted those. Settings still work - after changing something, tap \"Send settings to keyboard\" below, then switch to HunKeys in any text field and they import automatically."
        }
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

    // MARK: Keyboard side: automatic import from the clipboard

    /// For installs without shared storage (Sideloadly + free Apple ID). The app copies its settings as
    /// text; when the keyboard appears it checks, at most once per clipboard change, whether the
    /// clipboard holds HunKeys settings. If so it imports them and clears the clipboard.
    /// Needs "Allow Full Access" (iOS blocks clipboard access for keyboards without it).
    static func importFromClipboardIfNeeded(hasFullAccess: Bool) -> Bool {
        guard isExtension, hasFullAccess else { return false }
        let board = UIPasteboard.general
        let local = UserDefaults.standard
        let key = "hunkeys.local.pasteboardCount"
        let count = board.changeCount
        guard count != local.integer(forKey: key) else { return false }
        local.set(count, forKey: key)
        guard board.hasStrings, let text = board.string, isSettingsPayload(text) else { return false }
        guard importSettings(from: text) else { return false }
        board.string = ""
        local.set(board.changeCount, forKey: key)
        return true
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
