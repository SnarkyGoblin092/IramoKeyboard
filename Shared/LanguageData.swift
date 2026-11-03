import Compression
import Foundation

/// The keyboard's language data (dictionaries, language models, word pairs, accents, phonetic tables, emoji
/// keywords) ships compressed in the keyboard's bundle as `<file>.zlib` (raw DEFLATE, written by the CI build), so
/// the app stays small. A language's files are unpacked only once it is used: by the app when the language is
/// enabled, or by the keyboard the first time it loads one that is not unpacked yet. Unpacked files go to the App
/// Group container when this process can write there (so the app and the keyboard share them), else to this
/// process's own Caches folder; files of languages that are no longer enabled are removed.
///
/// An unpacked file is named after its compressed size (`dict_hu.bin.1234567`), so a build with new data unpacks
/// it again instead of using the old copy.
enum LanguageData {
    /// The file to read for `name.ext` (as Bundle.url(forResource:withExtension:) takes them): the bundle's own
    /// copy if it ships uncompressed, else the unpacked one (unpacked now if it is not yet). nil if there is none.
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let plain = Bundle.main.url(forResource: name, withExtension: ext) { return plain }
        // In the app, files the keyboard ships uncompressed (emoji.json) are in the keyboard's bundle inside it.
        if let plain = packedBundle?.url(forResource: name, withExtension: ext) { return plain }
        let file = "\(name).\(ext)"
        guard let packed = packedURL(file), let stamp = size(of: packed) else { return nil }
        let unpackedName = "\(file).\(stamp)"
        for folder in folders() {
            let url = folder.appendingPathComponent(unpackedName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return unpack(packed, as: unpackedName, file: file)
    }

    /// Unpacks every file of the `enabled` languages and removes the unpacked files of every other language (the
    /// app, when it opens and when the languages change). Slow: call it off the main thread.
    static func prepare(enabled: [String]) {
        let wanted = Set(enabled)
        for packed in packedFiles() where wanted.contains(languageCode(of: packed.lastPathComponent)) {
            let file = String(packed.lastPathComponent.dropLast(".zlib".count))
            let parts = file.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            _ = url(forResource: parts[0], withExtension: parts[1])
        }
        removeUnpacked(keeping: wanted)
    }

    private static let queue = DispatchQueue(label: "LanguageData", qos: .utility)

    /// `prepare` on a background queue, one run after another.
    static func prepareInBackground(enabled: [String]) {
        queue.async { prepare(enabled: enabled) }
    }

    /// `removeUnpacked` on a background queue.
    static func removeUnpackedInBackground(keeping: Set<String>) {
        queue.async { removeUnpacked(keeping: keeping) }
    }

    /// Removes the unpacked files of the languages not in `keeping`, and old copies left by earlier builds.
    static func removeUnpacked(keeping: Set<String>) {
        // English stays: emoji search always looks in it too (EmojiStore.loadSearchIfNeeded).
        let keeping = keeping.union(["en"])
        var current = Set<String>()
        for packed in packedFiles() {
            if let stamp = size(of: packed) { current.insert("\(packed.lastPathComponent.dropLast(".zlib".count)).\(stamp)") }
        }
        for folder in folders() {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            // (Names starting with "." are files being unpacked right now, by this process or the other one.)
            for name in names where !name.hasPrefix(".")
                && (!current.contains(name) || !keeping.contains(languageCode(of: name))) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    // MARK: Where the files are

    /// The bundle that holds the compressed files: the keyboard's own, or (in the app) the keyboard's inside it.
    private static let packedBundle: Bundle? = {
        if Bundle.main.bundleURL.pathExtension == "appex" { return Bundle.main }
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let names = try? FileManager.default.contentsOfDirectory(atPath: plugins.path),
              let appex = names.first(where: { $0.hasSuffix(".appex") }) else { return nil }
        return Bundle(url: plugins.appendingPathComponent(appex))
    }()

    private static func packedURL(_ file: String) -> URL? {
        return packedBundle?.url(forResource: file, withExtension: "zlib")
    }

    private static func packedFiles() -> [URL] {
        return packedBundle?.urls(forResourcesWithExtension: "zlib", subdirectory: nil) ?? []
    }

    /// The folders unpacked files are kept in, the shared one first. Created when missing.
    private static func folders() -> [URL] {
        var list: [URL] = []
        if let id = SharedStore.groupID,
           let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            list.append(group.appendingPathComponent("LanguageData", isDirectory: true))
        }
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            list.append(caches.appendingPathComponent("LanguageData", isDirectory: true))
        }
        for folder in list {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return list
    }

    /// The language a data file belongs to: the code after the last "_" of its name ("dict_hu.bin" -> "hu").
    private static func languageCode(of name: String) -> String {
        let base = name.split(separator: ".").first.map(String.init) ?? name
        return base.split(separator: "_").last.map(String.init) ?? base
    }

    private static func size(of url: URL) -> Int? {
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
    }

    // MARK: Unpacking

    /// Unpacks `packed` into the first folder this process can write to, piece by piece (the keyboard has little
    /// memory to spare), through a temporary file that is moved into place once complete.
    private static func unpack(_ packed: URL, as unpackedName: String, file: String) -> URL? {
        for folder in folders() {
            let target = folder.appendingPathComponent(unpackedName)
            let temporary = folder.appendingPathComponent(".\(unpackedName).\(UUID().uuidString)")
            guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else { continue }
            if inflate(packed, into: temporary) {
                // Older copies of the same file (an earlier build's data) go.
                let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
                for name in names where name.hasPrefix("\(file).") && name != unpackedName {
                    try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
                }
                do {
                    try FileManager.default.moveItem(at: temporary, to: target)
                } catch {
                    // The other process unpacked it at the same time: its copy is just as good.
                    try? FileManager.default.removeItem(at: temporary)
                }
                if FileManager.default.fileExists(atPath: target.path) { return target }
            } else {
                try? FileManager.default.removeItem(at: temporary)
            }
        }
        return nil
    }

    private static func inflate(_ packed: URL, into target: URL) -> Bool {
        guard let input = try? FileHandle(forReadingFrom: packed),
              let output = try? FileHandle(forWritingTo: target) else { return false }
        defer {
            try? input.close()
            try? output.close()
        }
        do {
            let filter = try OutputFilter(.decompress, using: .zlib) { data in
                if let data = data { output.write(data) }
            }
            while true {
                let chunk = input.readData(ofLength: 256 * 1024)
                if chunk.isEmpty { break }
                try filter.write(chunk)
            }
            try filter.finalize()
            return true
        } catch {
            return false
        }
    }
}
