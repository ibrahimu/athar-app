import SwiftUI

/// سِمة الورق لها عنوان ومختصر وتفصيل أصلًا، فتصلح لقائمة الاختيار كغيرها.
extension ReadingTheme: SettingsChoice {}

/// القارئ خيارٌ في قائمة الإعدادات كغيره: اسمه عنوانًا، والتفصيل واحد للجميع
/// لأن الفرق بينهم الصوت لا الوصف.
extension AyahReciter: SettingsChoice {
    var title: String { name }
    var shortTitle: String { name }
    var detail: String { loc("تلاوة مرتّلة آية بآية — تُحمَّل من الإنترنت عند التشغيل") }
}

/// المصحف والقراءة: الإعدادات نفسها التي في لوحة القارئ (ReaderControls) لكن من
/// الإعدادات — فمن أراد ضبط المصحف قبل فتحه وجدها هنا، والقيم واحدة في الموضعين.
struct ReadingSettingsView: View {
    @EnvironmentObject private var store: AtharStore
    // القارئ يُحفظ في AyahAudio لا في المخزن، فنراقبه مباشرةً كما تفعل ورقة التفسير.
    @ObservedObject private var ayahAudio = AyahAudio.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                display
                sound
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: Theme.accent(for: "green")) }
        .navigationTitle(loc("المصحف والقراءة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: العرض

    private var display: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("العرض"), tint: Theme.accent(for: "green"))
            SettingsCard {
                chipsBlock(icon: "book.pages.fill", tint: Theme.accent(for: "green"), title: loc("displayMode")) {
                    ForEach(ReadingMode.allCases) { mode in
                        chip(icon: mode.icon, title: mode.title, on: store.readingMode == mode) {
                            store.readingMode = mode
                        }
                    }
                }

                // في وضعَي الصفحة: تصغيرٌ تلقائي حتى تظهر الصفحة كاملةً بلا تمرير
                // كالمصحف المطبوع. لا معنى له في «آية آية» فيُخفى هناك.
                if store.readingMode != .ayah {
                    SettingsDivider()
                    SettingsRow(icon: "arrow.down.left.and.arrow.up.right", tint: Theme.accent(for: "noon"),
                                title: loc("الصفحة كاملة على الشاشة"),
                                subtitle: loc("تصغير الخط تلقائيًّا حتى تظهر الصفحة بلا تمرير")) {
                        Toggle("", isOn: Binding(get: { store.fitPage }, set: { store.fitPage = $0 }))
                            .labelsHidden()
                            .accessibilityLabel(loc("الصفحة كاملة على الشاشة"))
                    }
                }

                SettingsDivider()
                // الوضع الليلي التلقائي: بين العشاء والفجر يُقرأ على ورق الليل مهما كانت السِمة.
                SettingsRow(icon: "moon.fill", tint: Theme.accent(for: "night"),
                            title: loc("ليلي تلقائيًّا"),
                            subtitle: loc("بين العشاء والفجر بحساب مواقيتك")) {
                    Toggle("", isOn: Binding(get: { store.readingThemeAuto }, set: { store.readingThemeAuto = $0 }))
                        .labelsHidden()
                        .accessibilityLabel(loc("ليلي تلقائيًّا"))
                }

                SettingsDivider()
                SettingsPickerRow(
                    icon: "doc.plaintext.fill", tint: Theme.accent(for: "dawn"),
                    title: loc("pageTheme"), options: ReadingTheme.allCases,
                    selection: Binding(
                        get: { store.readingTheme },
                        set: { store.readingTheme = $0 }))

                SettingsDivider()
                // وضع الحفظ: يخفي بعض الكلمات فيُسمّع القارئ نفسه، والنقر على الآية يكشفها.
                chipsBlock(icon: "eye.slash.fill", tint: Theme.accent(for: "hifz"), title: loc("وضع الحفظ"),
                           footnote: loc("المخفيّ يظهر بالنقر على آيته — ومع التكرار الصوتي يصير الحفظ تدريبًا.")) {
                    ForEach(HifzHide.allCases) { h in
                        chip(icon: h.icon, title: h.title, on: store.hifzHide == h) {
                            store.hifzHide = h
                        }
                    }
                }
            }
        }
        .animation(Motion.smooth, value: store.readingMode)
    }

    // MARK: الصوت

    private var sound: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الصوت"), tint: Theme.accent(for: "dusk"))
            SettingsCard {
                SettingsPickerRow(
                    icon: "speaker.wave.2.fill", tint: Theme.accent(for: "dusk"),
                    title: loc("خيار الصوت عند فتح الآية"), options: AyahSoundMode.allCases,
                    selection: Binding(
                        get: { store.ayahSoundMode },
                        set: { store.ayahSoundMode = $0 }))

                SettingsDivider()
                SettingsPickerRow(
                    icon: "person.wave.2.fill", tint: Theme.accent(for: "sea"),
                    title: loc("القارئ"), options: AyahReciters.all,
                    selection: Binding(
                        get: { AyahReciters.reciter(id: ayahAudio.reciterId) },
                        set: { ayahAudio.reciterId = $0.id }))
            }
        }
    }

    // MARK: رقائق الاختيار

    /// صفّ عنوان ثم رقائق تحته — كما في لوحة القارئ، لكن داخل بطاقة الإعدادات.
    private func chipsBlock<Chips: View>(icon: String, tint: Color, title: String, footnote: String? = nil,
                                         @ViewBuilder chips: () -> Chips) -> some View {
        // تُبنى الرقائق مرة هنا لا داخل مغلِّف HStack، فلا تُمرَّر مغلقة غير هاربة إلى مغلقة أخرى.
        let items = chips()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                IconChip(icon: icon, tint: tint, size: .sm)
                Text(title)
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            HStack(spacing: 8) { items }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(title)
            if let footnote {
                Text(footnote)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func chip(icon: String, title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(title).font(Theme.display(13, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(on ? Theme.accent : Theme.surfaceAlt))
        }
        .pressable()
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
