import UIKit
import CarPlay

/// CarPlay (صوت): قوائم القرّاء ثم السور، والتشغيل بمحرّك التلاوة نفسه.
/// يلزمه استحقاق com.apple.developer.carplay-audio من Apple قبل أن يظهر في السيارة.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interface: CPInterfaceController?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        interface = interfaceController
        interfaceController.setRootTemplate(recitersTemplate(), animated: false, completion: nil)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        interface = nil
    }

    private func recitersTemplate() -> CPListTemplate {
        let items: [CPListItem] = RecitationLibrary.reciters.map { r in
            let item = CPListItem(text: r.name, detailText: nil)
            item.handler = { [weak self] _, done in
                Task { @MainActor in
                    Recitation.shared.select(r)
                    self?.interface?.pushTemplate(self?.surahsTemplate(for: r) ?? CPListTemplate(title: "", sections: []), animated: true, completion: nil)
                    done()
                }
            }
            return item
        }
        let t = CPListTemplate(title: "أثر — التلاوة", sections: [CPListSection(items: items)])
        return t
    }

    private func surahsTemplate(for reciter: Reciter) -> CPListTemplate {
        let items: [CPListItem] = Quran.surahs.map { s in
            let item = CPListItem(text: s.name, detailText: s.ayahCount.ayahCountText)
            item.handler = { _, done in
                Task { @MainActor in Recitation.shared.play(surah: s.id) }
                done()
            }
            return item
        }
        // قوائم CarPlay محدودة الطول: تقسّم إلى أقسام من ٣٠ سورة.
        var sections: [CPListSection] = []
        for chunk in stride(from: 0, to: items.count, by: 30) {
            sections.append(CPListSection(items: Array(items[chunk..<min(chunk + 30, items.count)])))
        }
        return CPListTemplate(title: reciter.name, sections: sections)
    }
}
