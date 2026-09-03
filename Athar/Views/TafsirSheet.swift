import SwiftUI

/// ورقة التفسير تنزلق من الآية: السعدي للمعنى، والجلالين للبيان الموجز — هيكل أوّلي.
struct TafsirSheet: View {
    let ref: AyahRef
    @State private var edition: TafsirEdition = .saadi

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 14) {
                    Picker("", selection: $edition) {
                        ForEach(TafsirEdition.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if let e = Tafsir.entry(edition, for: ref) {
                        AtharCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(e.rangeTitle).font(Theme.display(12, weight: .semibold)).foregroundStyle(Theme.accent)
                                Text(e.text).font(Theme.dhikrFont(size: 17)).foregroundStyle(Theme.ink).lineSpacing(7)
                            }
                        }
                    } else {
                        Text(loc("لا تفسير متاح لهذه الآية")).font(Theme.display(13)).foregroundStyle(Theme.inkFaint)
                    }
                }
                .padding(Theme.gutter)
            }
        }
    }
}
