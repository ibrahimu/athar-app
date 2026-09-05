import Foundation
#if canImport(CloudKit)
import CloudKit

// MARK: - الختمة الجماعية (CloudKit العام — بلا حسابات)
//
// ختمة برمز من ستة أحرف يتقاسمها أهل بيت أو أصدقاء: كل عضو يسجّل صفحاته، ويرى تقدّم الباقين.
// لا يُرسل اسم إلا ما يكتبه المستخدم بنفسه، ولا معرّفات أجهزة.

struct GroupKhatmah: Identifiable, Hashable {
    let id: String          // recordName = code
    let code: String
    let title: String
    let created: Date
    let goalDays: Int
}

struct GroupMember: Identifiable, Hashable {
    let id: String          // recordName
    let code: String
    let name: String
    let pages: Int
    let updated: Date
    let mine: Bool
}

@MainActor
final class GroupKhatmahService: ObservableObject {
    static let shared = GroupKhatmahService()
    private let db = CKContainer(identifier: "iCloud.com.ibrahim.athar").publicCloudDatabase

    @Published var group: GroupKhatmah?
    @Published var members: [GroupMember] = []
    @Published var busy = false
    @Published var error: String?

    private let codeKey = "athar.groupKhatmah.code"
    private let memberKey = "athar.groupKhatmah.member"
    private let nameKey = "athar.groupKhatmah.name"

    var joinedCode: String? { UserDefaults.standard.string(forKey: codeKey) }
    var memberName: String { UserDefaults.standard.string(forKey: nameKey) ?? "" }

    private static func makeCode() -> String {
        let alphabet = Array("ابتحدرسصطعفقكلمنهوي")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    func create(title: String, name: String, goalDays: Int) async {
        busy = true; error = nil; defer { busy = false }
        let code = Self.makeCode()
        let rec = CKRecord(recordType: "Khatmah", recordID: CKRecord.ID(recordName: "k-" + code))
        rec["code"] = code; rec["title"] = title; rec["created"] = Date(); rec["goalDays"] = goalDays
        do {
            _ = try await db.save(rec)
            UserDefaults.standard.set(code, forKey: codeKey)
            await join(code: code, name: name)
        } catch { self.error = Self.describe(error) }
    }

    func join(code: String, name: String) async {
        busy = true; error = nil; defer { busy = false }
        let code = code.trimmingCharacters(in: .whitespaces)
        do {
            let k = try await db.record(for: CKRecord.ID(recordName: "k-" + code))
            group = GroupKhatmah(id: code, code: code, title: k["title"] as? String ?? "", created: k["created"] as? Date ?? Date(), goalDays: k["goalDays"] as? Int ?? 30)
            let memberId = UserDefaults.standard.string(forKey: memberKey) ?? "m-" + UUID().uuidString.prefix(8)
            UserDefaults.standard.set(memberId, forKey: memberKey)
            UserDefaults.standard.set(code, forKey: codeKey)
            UserDefaults.standard.set(name, forKey: nameKey)
            let m = CKRecord(recordType: "Member", recordID: CKRecord.ID(recordName: "\(code)-\(memberId)"))
            m["code"] = code; m["name"] = name; m["pages"] = 0; m["updated"] = Date()
            _ = try? await db.modifyRecords(saving: [m], deleting: [], savePolicy: .changedKeys)
            await refresh()
        } catch { self.error = Self.describe(error) }
    }

    func leave() {
        for k in [codeKey, memberKey] { UserDefaults.standard.removeObject(forKey: k) }
        group = nil; members = []
    }

    /// يرفع صفحات المستخدم (من ختمته المحلية) ويجلب الأعضاء.
    func sync(pages: Int) async {
        guard let code = joinedCode, let memberId = UserDefaults.standard.string(forKey: memberKey) else { return }
        do {
            let id = CKRecord.ID(recordName: "\(code)-\(memberId)")
            let rec = (try? await db.record(for: id)) ?? CKRecord(recordType: "Member", recordID: id)
            rec["code"] = code; rec["name"] = memberName; rec["pages"] = pages; rec["updated"] = Date()
            _ = try await db.modifyRecords(saving: [rec], deleting: [], savePolicy: .changedKeys)
        } catch { self.error = Self.describe(error) }
        await refresh()
    }

    func refresh() async {
        guard let code = joinedCode else { return }
        busy = true; defer { busy = false }
        do {
            if group == nil {
                let k = try await db.record(for: CKRecord.ID(recordName: "k-" + code))
                group = GroupKhatmah(id: code, code: code, title: k["title"] as? String ?? "", created: k["created"] as? Date ?? Date(), goalDays: k["goalDays"] as? Int ?? 30)
            }
            let q = CKQuery(recordType: "Member", predicate: NSPredicate(format: "code == %@", code))
            let (results, _) = try await db.records(matching: q, resultsLimit: 200)
            let me = UserDefaults.standard.string(forKey: memberKey) ?? ""
            members = results.compactMap { id, r -> GroupMember? in
                guard let rec = try? r.get() else { return nil }
                return GroupMember(id: id.recordName, code: code, name: rec["name"] as? String ?? "", pages: rec["pages"] as? Int ?? 0,
                                   updated: rec["updated"] as? Date ?? Date(), mine: id.recordName.hasSuffix(me))
            }.sorted { $0.pages > $1.pages }
        } catch { self.error = Self.describe(error) }
    }

    private static func describe(_ e: Error) -> String {
        if let ck = e as? CKError {
            switch ck.code {
            case .notAuthenticated: return "سجّل الدخول إلى iCloud في إعدادات الجهاز لتشارك الختمة."
            case .networkUnavailable, .networkFailure: return "لا اتصال بالإنترنت."
            case .unknownItem: return "لا ختمة بهذا الرمز."
            default: return "تعذّر الاتصال بخدمة الختمة (\(ck.code.rawValue))."
            }
        }
        return "تعذّر الاتصال بخدمة الختمة."
    }
}
#endif
