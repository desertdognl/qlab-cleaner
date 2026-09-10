import Foundation

/// Walks NSKeyedArchiver property lists, including nested bplist blobs.
struct KeyedArchive {
    let objects: [Any]

    init(data: Data) throws {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: Any],
              let objects = dict["$objects"] as? [Any] else {
            throw ParserError.invalidArchive
        }
        self.objects = objects
    }

    func uidIndex(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let dict = value as? [String: Any] {
            if let n = dict["CF$UID"] as? Int { return n }
            if let n = dict["CF$UID"] as? Int64 { return Int(n) }
            if let n = dict["CF$UID"] as? NSNumber { return n.intValue }
        }
        let description = String(describing: value)
        guard description.hasPrefix("<CFKeyedArchiverUID") else { return nil }
        if let parsed = Self.parseUID(from: description) {
            return parsed
        }
        return Self.keyedArchiverUIDValue(value)
    }

    func resolve(_ value: Any?) -> Any? {
        guard let value else { return nil }
        if let index = uidIndex(value), objects.indices.contains(index) {
            return objects[index]
        }
        return value
    }

    func string(from value: Any?) -> String {
        guard let raw = resolve(value) else { return "" }
        if let s = raw as? String {
            return s == "$null" ? "" : s
        }
        if let dict = raw as? [String: Any] {
            if dict["NS.string"] != nil {
                return string(from: dict["NS.string"])
            }
        }
        return ""
    }

    func className(of object: Any?) -> String? {
        guard let dict = object as? [String: Any] else { return nil }
        guard let cls = resolve(dict["$class"]) as? [String: Any] else { return nil }
        let name = string(from: cls["$classname"])
        return name.isEmpty ? nil : name
    }

    func array(from value: Any?) -> [Any] {
        let raw = resolve(value)
        if let arr = raw as? [Any] { return arr }
        if let arr = raw as? NSArray { return arr.map { $0 } }
        if let dict = raw as? [String: Any], dict["NS.objects"] != nil {
            return array(from: dict["NS.objects"])
        }
        return []
    }

    func nestedArchives() -> [KeyedArchive] {
        var result: [KeyedArchive] = []
        for object in objects {
            guard let dict = object as? [String: Any] else { continue }
            let data: Data?
            if let nsData = dict["NS.data"] as? Data {
                data = nsData
            } else if let nested = resolve(dict["NS.data"]) as? Data {
                data = nested
            } else {
                data = nil
            }
            guard let blob = data, blob.starts(with: Data("bplist00".utf8)) else { continue }
            if let archive = try? KeyedArchive(data: blob) {
                result.append(archive)
                result.append(contentsOf: archive.nestedArchives())
            }
        }
        return result
    }

    func dictionaryEntries(_ object: Any?) -> [(String, Any)] {
        guard let dict = object as? [String: Any] else { return [] }
        if dict["NS.keys"] != nil && dict["NS.objects"] != nil {
            let keys = array(from: dict["NS.keys"]).map { string(from: $0) }
            let values = array(from: dict["NS.objects"])
            return zip(keys, values).map { ($0, $1) }
        }
        return dict
            .filter { $0.key != "$class" }
            .map { ($0.key, $0.value) }
    }

    func boolSetting(_ name: String) -> Bool? {
        let nameIndex = objects.firstIndex {
            ($0 as? String) == name || String(describing: $0) == name
        }
        for object in objects {
            guard let dict = object as? [String: Any], dict["NS.keys"] != nil, dict["NS.objects"] != nil else {
                continue
            }
            let keys = array(from: dict["NS.keys"])
            let values = array(from: dict["NS.objects"])
            for (index, keyItem) in keys.enumerated() {
                let text = string(from: keyItem)
                let direct = (resolve(keyItem) as? String) == name || (keyItem as? String) == name
                let matchesName = text == name
                    || direct
                    || (nameIndex != nil && uidIndex(keyItem) == nameIndex)
                guard matchesName, values.indices.contains(index) else { continue }
                if let parsed = boolValue(values[index]) {
                    return parsed
                }
            }
        }
        return nil
    }

    func boolValue(_ value: Any?) -> Bool? {
        let resolved = resolve(value)
        if let flag = resolved as? Bool { return flag }
        if let number = resolved as? NSNumber { return number.intValue != 0 }
        if let number = resolved as? Int { return number != 0 }
        if let number = resolved as? Int64 { return number != 0 }
        if let number = resolved as? Int32 { return number != 0 }
        if let number = resolved as? UInt64 { return number != 0 }
        if let number = resolved as? Double { return number != 0 }
        if let text = resolved as? String {
            let lowered = text.lowercased()
            if ["1", "true", "yes"].contains(lowered) { return true }
            if ["0", "false", "no"].contains(lowered) { return false }
        }
        return nil
    }

    private static let uidFunction: ((Any) -> Int?)? = {
        typealias UIDFn = @convention(c) (UnsafeRawPointer) -> UInt32
        guard let handle = dlopen(nil, RTLD_NOW) else { return nil }
        let names = ["CFKeyedArchiverUIDGetValue", "_CFKeyedArchiverUIDGetValue"]
        for name in names {
            if let symbol = dlsym(handle, name) {
                let fn = unsafeBitCast(symbol, to: UIDFn.self)
                return { object in
                    let pointer = Unmanaged.passUnretained(object as AnyObject).toOpaque()
                    return Int(fn(pointer))
                }
            }
        }
        return nil
    }()

    private static func parseUID(from description: String) -> Int? {
        guard let range = description.range(of: #"value\s*=\s*(\d+)"#, options: .regularExpression) else {
            return nil
        }
        let matched = String(description[range])
        let digits = matched.split(separator: "=").last?.trimmingCharacters(in: .whitespaces)
        return digits.flatMap { Int($0) }
    }

    private static func keyedArchiverUIDValue(_ value: Any) -> Int? {
        guard String(describing: value).hasPrefix("<CFKeyedArchiverUID") else { return nil }
        return uidFunction?(value)
    }
}

enum ParserError: LocalizedError {
    case invalidArchive
    case unreadableFile
    case noWorkspaceFile
    case multipleWorkspaces([String])

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return L10n.t("error.invalidArchive")
        case .unreadableFile: return L10n.t("error.unreadable")
        case .noWorkspaceFile: return L10n.t("error.noWorkspace")
        case .multipleWorkspaces(let names):
            return L10n.t("error.multipleWorkspaces", names.joined(separator: ", "))
        }
    }
}
