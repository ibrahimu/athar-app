import Foundation
import UniformTypeIdentifiers

/// تصدير بياناتك ملفًا واستيرادها — كل ما يخصّك من التفضيلات والمفضّلة والسجلات، بلا حسابات.
enum DataExport {
    static let fileName = "athar-backup.json"

    /// المفاتيح التي تُصدَّر: كل ما يبدأ بـ athar. عدا ما هو مؤقت أو خاص بالجهاز.
    private static let excludedPrefixes = ["athar.spotlight", "athar.whatsNew", "athar.tzChangePending", "athar.usesDeviceLocation"]

    static func export(from defaults: UserDefaults) throws -> URL {
        var payload: [String: Any] = [:]
        for (k, v) in defaults.dictionaryRepresentation() where k.hasPrefix("athar.") && !excludedPrefixes.contains(where: { k.hasPrefix($0) }) {
            if JSONSerialization.isValidJSONObject([v]) { payload[k] = v }
            else if let d = v as? Data { payload[k] = ["__data": d.base64EncodedString()] }
            else if let date = v as? Date { payload[k] = ["__date": date.timeIntervalSince1970] }
        }
        let wrapper: [String: Any] = ["app": "athar", "version": 1, "exported": Date().timeIntervalSince1970, "keys": payload]
        let data = try JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// يستورد ملفًا صدّره التطبيق. لا يمسح ما ليس في الملف.
    @discardableResult
    static func importFile(_ url: URL, into defaults: UserDefaults) throws -> Int {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], obj["app"] as? String == "athar",
              let keys = obj["keys"] as? [String: Any] else { throw NSError(domain: "athar", code: 1, userInfo: [NSLocalizedDescriptionKey: "ليس ملف نسخة احتياطية من أثر."]) }
        var n = 0
        for (k, v) in keys where k.hasPrefix("athar.") {
            if let dict = v as? [String: Any], let b64 = dict["__data"] as? String, let d = Data(base64Encoded: b64) { defaults.set(d, forKey: k); n += 1 }
            else if let dict = v as? [String: Any], let t = dict["__date"] as? Double { defaults.set(Date(timeIntervalSince1970: t), forKey: k); n += 1 }
            else { defaults.set(v, forKey: k); n += 1 }
        }
        return n
    }
}
