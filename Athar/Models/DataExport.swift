import Foundation
import UniformTypeIdentifiers

/// تصدير بياناتك ملفًا واستيرادها — كل ما يخصّك من التفضيلات والمفضّلة والسجلات، بلا حسابات.
enum DataExport {
    static let fileName = "athar-backup.json"

    /// المفاتيح التي تُصدَّر: كل ما يبدأ بـ athar. عدا ما هو مؤقت أو خاص بالجهاز.
    private static let excludedPrefixes = ["athar.spotlight", "athar.whatsNew", "athar.tzChangePending", "athar.usesDeviceLocation", "athar.groupKhatmah", "athar.notifications", "athar.cloudSync"]

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
              obj["version"] as? Int == 1, let keys = obj["keys"] as? [String: Any] else { throw NSError(domain: "athar", code: 1, userInfo: [NSLocalizedDescriptionKey: "ليس ملف نسخة احتياطية من أثر."]) }
        var validated: [String: Any] = [:]
        for (key, value) in keys where key.hasPrefix("athar.") && !excludedPrefixes.contains(where: { key.hasPrefix($0) }) {
            let decoded: Any
            if let dict = value as? [String: Any], let b64 = dict["__data"] as? String {
                guard let bytes = Data(base64Encoded: b64) else { throw invalidBackup() }
                decoded = bytes
            } else if let dict = value as? [String: Any], let timestamp = dict["__date"] as? Double {
                guard timestamp.isFinite else { throw invalidBackup() }
                decoded = Date(timeIntervalSince1970: timestamp)
            } else { decoded = value }
            // JSON يسمح بـ null بينما UserDefaults لا يسمح به؛ نتحقق من الملف كله قبل أول كتابة.
            guard PropertyListSerialization.propertyList([key: decoded], isValidFor: .binary) else { throw invalidBackup() }
            validated[key] = decoded
        }
        for (key, value) in validated { defaults.set(value, forKey: key) }
        return validated.count
    }

    private static func invalidBackup() -> NSError {
        NSError(domain: "athar", code: 2, userInfo: [NSLocalizedDescriptionKey: "تحتوي النسخة على بيانات غير صالحة. لم تُستورد أي تغييرات."])
    }
}
