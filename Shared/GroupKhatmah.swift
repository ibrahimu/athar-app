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
        guard !busy else { return }
        busy = true; error = nil; defer { busy = false }
        let code = Self.makeCode()
        let record = CKRecord(recordType: "Khatmah", recordID: CKRecord.ID(recordName: "k-" + code))
        record["code"] = code; record["title"] = title; record["created"] = Date(); record["goalDays"] = goalDays
        do {
            let saved = try await db.save(record)
            do { try await joinGroup(record: saved, code: code, name: name) }
            catch {
                // لا نترك ختمة يتيمة إن فشلت عضوية منشئها.
                _ = try? await db.deleteRecord(withID: saved.recordID)
                throw error
            }
            await refresh()
        } catch { self.error = Self.describe(error) }
    }

    func join(code: String, name: String) async {
        guard !busy else { return }
        busy = true; error = nil; defer { busy = false }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let record = try await db.record(for: CKRecord.ID(recordName: "k-" + code))
            try await joinGroup(record: record, code: code, name: name)
            await refresh()
        } catch { self.error = Self.describe(error) }
    }

    private func joinGroup(record: CKRecord, code: String, name: String) async throws {
        let memberId = UserDefaults.standard.string(forKey: memberKey) ?? "m-" + UUID().uuidString
        let id = CKRecord.ID(recordName: "\(code)-\(memberId)")
        let member = try await existingOrNewMember(id: id)
        member["code"] = code; member["name"] = name; member["updated"] = Date()
        if member["pages"] == nil { member["pages"] = 0 }
        try await saveMember(member)
        // لا نظهر نجاح الانضمام قبل تأكيد كتابة سجل العضو نفسه.
        UserDefaults.standard.set(memberId, forKey: memberKey)
        UserDefaults.standard.set(code, forKey: codeKey)
        UserDefaults.standard.set(name, forKey: nameKey)
        group = GroupKhatmah(id: code, code: code, title: record["title"] as? String ?? "",
                            created: record["created"] as? Date ?? Date(), goalDays: record["goalDays"] as? Int ?? 30)
    }

    func leave() async {
        guard !busy, let code = joinedCode, let memberId = UserDefaults.standard.string(forKey: memberKey) else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            do { _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: "\(code)-\(memberId)")) }
            catch let error as CKError where error.code == .unknownItem { /* سبق حذف العضوية */ }
            UserDefaults.standard.removeObject(forKey: codeKey)
            // الهوية تبقى ثابتة لمنع الازدواج عند العودة إلى الختمة.
            group = nil; members = []
        } catch { self.error = Self.describe(error) }
    }

    func sync(pages: Int) async {
        guard !busy, let code = joinedCode, let memberId = UserDefaults.standard.string(forKey: memberKey) else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let record = try await existingOrNewMember(id: CKRecord.ID(recordName: "\(code)-\(memberId)"))
            record["code"] = code; record["name"] = memberName
            record["pages"] = max(0, min(Quran.pageCount, pages)); record["updated"] = Date()
            try await saveMember(record)
            await refresh()
        } catch { self.error = Self.describe(error) }
    }

    private func existingOrNewMember(id: CKRecord.ID) async throws -> CKRecord {
        do { return try await db.record(for: id) }
        catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: "Member", recordID: id)
        }
    }

    private func saveMember(_ record: CKRecord) async throws {
        let results = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
        guard let result = results.saveResults[record.recordID] else { throw CKError(.internalError) }
        _ = try result.get()
    }

    func refresh() async {
        guard let code = joinedCode else { return }
        do {
            if group == nil {
                let k = try await db.record(for: CKRecord.ID(recordName: "k-" + code))
                group = GroupKhatmah(id: code, code: code, title: k["title"] as? String ?? "", created: k["created"] as? Date ?? Date(), goalDays: k["goalDays"] as? Int ?? 30)
            }
            let q = CKQuery(recordType: "Member", predicate: NSPredicate(format: "code == %@", code))
            var (results, cursor) = try await db.records(matching: q, resultsLimit: 200)
            while let next = cursor {
                let page = try await db.records(continuingMatchFrom: next, resultsLimit: 200)
                results.append(contentsOf: page.matchResults)
                cursor = page.queryCursor
            }
            let me = UserDefaults.standard.string(forKey: memberKey) ?? ""
            members = results.compactMap { id, r -> GroupMember? in
                guard let rec = try? r.get() else { return nil }
                return GroupMember(id: id.recordName, code: code, name: rec["name"] as? String ?? "", pages: rec["pages"] as? Int ?? 0,
                                   updated: rec["updated"] as? Date ?? Date(), mine: id.recordName == "\(code)-\(me)")
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
