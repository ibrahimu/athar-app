import Foundation

/// بطاقة Apple Wallet مُوقَّعة مسبقًا ومضمَّنة في التطبيق (Resources/WalletPasses/<id>.pkpass).
/// توقيع البطاقات يحتاج شهادة Pass Type ID على الماك، فلا تُولَّد بطاقات على الجهاز؛
/// والنصّ الشرعي المعروض داخل التطبيق يُقرأ من مصادره (quran.json / adhkar.json) بالمعرّف،
/// لا من ملف البطاقة — مصدر واحد للنصّ.
struct WalletCard: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let source: String
    let count: Int
    let kind: String          // quran | dhikr
    let serial: String        // الرقم التسلسلي داخل pass.json
    let surah: Int?
    let from: Int?
    let to: Int?
    let dhikrCategory: String?
    let dhikrId: String?
    /// ألوان البطاقة (سداسية بلا #) كما وُقّعت في ملفها — لون القسم: ورق فاتح بحبر داكن للنهار،
    /// وداكن بحبر فاتح للمساء والنوم والكرب والسفر. غيابها = الورق الكريمي الأول.
    let bg: String?
    let fg: String?
    let label: String?

    var isQuran: Bool { kind == "quran" }

    /// خلفية البطاقة وحبرها ولون عناوينها — للمعاينة داخل التطبيق من الأصل نفسه.
    var backgroundHex: UInt32 { Self.hex(bg) ?? 0xF7F2E7 }
    var inkHex: UInt32 { Self.hex(fg) ?? 0x14362C }
    var labelHex: UInt32 { Self.hex(label) ?? 0xA67C30 }

    private static func hex(_ s: String?) -> UInt32? {
        guard let s, let v = UInt32(s.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) else { return nil }
        return v
    }
    var repetitionText: String {
        switch count {
        case ...1: return "مرة واحدة"
        case 2: return "مرتان"
        case 3...10: return "\(count.counterText) مرات"
        default: return "\(count.counterText) مرة"
        }
    }


    /// النصّ من مصادر التطبيق نفسها؛ رقم الآية بين قوسين مزخرفين كما على البطاقة.
    var text: String {
        if isQuran, let surah, let from, let to, from <= to {
            return (from...to).compactMap { n in
                Quran.text(AyahRef(surah: surah, ayah: n)).map { "\($0) ﴿\(n)﴾" }
            }.joined(separator: " ")
        }
        if let dhikrCategory, let dhikrId {
            return AdhkarLibrary.category(id: dhikrCategory)?.items.first { $0.id == dhikrId }?.text ?? ""
        }
        return ""
    }
}

enum WalletCardLibrary {
    static let passTypeIdentifier = "pass.com.ibrahim.athar"
    static let cards: [WalletCard] = load()

    struct Group: Identifiable {
        let title: String
        let cards: [WalletCard]
        var id: String { title }
    }

    /// المجموعات بترتيب ورودها في الفهرس: القرآن ثم أذكار الصباح فالمساء…
    static let groups: [Group] = {
        var order: [String] = []
        var byTitle: [String: [WalletCard]] = [:]
        for card in cards {
            if byTitle[card.category] == nil { order.append(card.category) }
            byTitle[card.category, default: []].append(card)
        }
        return order.map { Group(title: $0, cards: byTitle[$0] ?? []) }
    }()

    static func passURL(for card: WalletCard) -> URL? {
        Bundle.main.url(forResource: card.id, withExtension: "pkpass", subdirectory: "WalletPasses")
            ?? Bundle.main.url(forResource: card.id, withExtension: "pkpass")
            ?? Bundle.main.url(forResource: card.id + "-cream", withExtension: "pkpass", subdirectory: "WalletPasses")
            ?? Bundle.main.url(forResource: card.id + "-cream", withExtension: "pkpass")
    }

    private static func load() -> [WalletCard] {
        guard let url = Bundle.main.url(forResource: "passes", withExtension: "json", subdirectory: "WalletPasses")
                ?? Bundle.main.url(forResource: "passes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cards = try? JSONDecoder().decode([WalletCard].self, from: data)
        else { return [] }
        return cards
    }
}
