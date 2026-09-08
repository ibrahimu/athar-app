import SwiftUI
import WidgetKit

/// بياناتك: المزامنة والنسخ أولًا، ثم أرقامك وإحصاء الشهر، والتصفير آخر شيء —
/// فالفعل الذي لا يُرجَع عنه يأتي بعد كل ما يُبقي بياناتك لا قبله.
struct DataSettingsView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var importMessage: String?
    /// ملفٌ قُرئ وتُحقّق منه ولم يُكتب بعد — بقاؤه هنا هو ما يفتح ورقة التأكيد.
    @State private var pending: DataExport.Preview?
    @State private var showResetConfirm = false

    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                backup
                stats
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: Theme.accent(for: "sea")) }
        .navigationTitle(loc("بياناتك"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(loc("هل تريد تصفير كل الإحصائيات؟"), isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(loc("تصفير"), role: .destructive) {
                store.resetAllProgress()
                WidgetCenter.shared.reloadAllTimelines()
            }
            Button(loc("cancel"), role: .cancel) {}
        }
        .sheet(item: $exportURL) { url in
            // الأوراق لا ترث اتجاه الكتابة من جذر التطبيق، فنثبّته صراحةً.
            ShareSheet(items: [url]).ignoresSafeArea()
                .environment(\.layoutDirection, direction)
        }
        // لا يُكتب شيء عند اختيار الملف: يُقرأ ويُعرض ما فيه، والكتابة بعد موافقةٍ صريحة.
        .sheet(item: $pending) { preview in
            ImportConfirmSheet(preview: preview) { restore(preview) }
                .atharSheetChrome()
                .presentationDetents([.medium, .large])
                .environment(\.layoutDirection, direction)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    pending = try DataExport.inspect(url)
                    importMessage = nil
                } catch { importMessage = error.localizedDescription }
            case .failure: importMessage = loc("لم يُختر ملف")
            }
        }
    }

    // MARK: المزامنة والنسخ

    private var backup: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("المزامنة والنسخ"), tint: Theme.accent(for: "sea"))
            SettingsCard {
                SettingsRow(icon: "icloud.fill", tint: Theme.accent(for: "sea"), title: loc("مزامنة iCloud"),
                            subtitle: loc("اختيارية، وما يخرج من جهازك مكتوبٌ تحتها")) {
                    Toggle("", isOn: Binding(get: { store.cloudSyncEnabled }, set: { store.cloudSyncEnabled = $0 }))
                        .labelsHidden()
                        .accessibilityLabel(loc("مزامنة iCloud"))
                        .accessibilityHint(syncDisclosure)
                }
                // البيان تحت المفتاح لا في صفحة أخرى: من يفتحه يفتحه على بيّنة بما يخرج،
                // والتدبّرات أوّل ما يُسمّى فيه لأنها كلامه هو لا تفضيلًا يُعوَّض.
                syncNote
                SettingsDivider()
                Button { exportData() } label: {
                    SettingsRow(icon: "square.and.arrow.up.on.square.fill", tint: Theme.accent(for: "sea"),
                                title: loc("تصدير بياناتي"), subtitle: loc("ملف واحد: المفضّلة والسجلات والتدبّرات والختمة والإعدادات")) { EmptyView() }
                }
                .buttonStyle(.plain)
                SettingsDivider()
                Button { showImporter = true } label: {
                    SettingsRow(icon: "square.and.arrow.down.on.square.fill", tint: Theme.accent(for: "sea"),
                                title: loc("استيراد نسخة"), subtitle: importMessage ?? loc("من ملف صدّرته من أثر")) { EmptyView() }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// جردٌ حرفيّ لمفاتيح CloudKV.keys — يُقرأ بالعين تحت المفتاح، ويُسمعه VoiceOver
    /// عند المفتاح نفسه، فلا يُقلب إلا وصاحبه يعلم ما يغادر جهازه.
    private var syncDisclosure: String {
        loc("يخرج من جهازك إلى مخزن iCloud في حسابك: تدبّراتك على الآيات بنصّها، وعلامات المصحف وتظليلاته، وموضع القراءة وعلامة الوقوف، والأحاديث المحفوظة، وإعدادات المظهر والخط وترتيب الشاشة، والأذان والتنبيه القبلي والإقامة، وعبارة المسبحة وهدفها، والمدينة الثانية.")
    }

    private var syncNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(syncDisclosure)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkSoft)
            Text(loc("ولا تخرج عدّاداتك ولا إحصاءاتك ولا سجلّا الصلاة والقراءة. المزامنة إلى حسابك وحده عبر Apple، لا إلى خادم لنا؛ وإيقافها يوقف ما بعده ولا يمحو ما بلغ iCloud."))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
            // يُقال ما يفعله الكود لا ما يُطمئن: عند ضيق الحصّة يضيق المرفوع ولا يقف —
            // يُطرح سجلّ التراجع أوّلًا ثم أقدم التدبّرات، ويبقى الحيّ منها يُزامَن.
            if store.cloudSyncEnabled, store.notesNearCloudLimit {
                Text(loc("قاربت تدبّراتك حصّة iCloud، فلم يعد يُرفع منها إلا الأحدث ونسخُها السابقة تُطرح أوّلًا. وكلّها محفوظة على هذا الجهاز — صدّر نسخة تحفظها."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.danger)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: أثري

    private var stats: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpStats"), tint: Theme.accent(for: "dawn"))
            SettingsCard {
                HStack(spacing: 0) {
                    statPill("flame.fill", Theme.gold, store.displayStreak.counterText, loc("statStreak"))
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 44)
                    statPill("trophy.fill", Theme.accent(for: "dawn"), store.bestStreak.counterText, loc("statBest"))
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 44)
                    statPill("infinity", Theme.accent, store.totalDhikrCount.counterText, loc("statTotal"))
                }
                .padding(.vertical, 16)
                SettingsDivider(inset: 0)
                NavigationLink { StatsView() } label: {
                    SettingsRow(icon: "chart.bar.xaxis", tint: Theme.accent(for: "dawn"),
                                title: loc("إحصاء الشهر"), subtitle: loc("أذكارك وصفحاتك وصلواتك في كل شهر هجري")) {
                        Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()
                Button { showResetConfirm = true } label: {
                    // يفتح مربّع تأكيد لا شاشة، فلا سهم يعِد بانتقال لا يأتي.
                    SettingsRow(icon: "arrow.counterclockwise", tint: Theme.danger,
                                title: loc("rowReset"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statPill(_ icon: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .background(
                    Circle().fill(tint.opacity(0.22)).frame(width: 26, height: 26).blur(radius: 7)
                )
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                                startPoint: .top, endPoint: .bottom))
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func exportData() {
        do { exportURL = try DataExport.export(from: store.defaults) } catch { importMessage = loc("تعذّر التصدير") }
    }

    /// الكتابة أخيرًا، ثم إيقاظ كل ما يقرأ التفضيلات: الطابع والسحابة والودجات
    /// والساعة والتنبيهات — وإلا بقي التطبيق يعرض بيانات مَن كان قبل الاستيراد.
    private func restore(_ preview: DataExport.Preview) {
        let n = DataExport.apply(preview, into: store.defaults)
        store.applyStoredTheme(); store.objectWillChange.send()
        if store.cloudSyncEnabled { store.startCloudSync() } else { CloudKV.shared.stop() }
        WidgetCenter.shared.reloadAllTimelines()
        WatchSync.shared.push(store: store)
        Haptics.done(enabled: store.hapticsEnabled)
        importMessage = loc("استُوردت %1$@", valuesText(n))
        Task { await Reminders.rescheduleAll(store: store) }
    }
}

// MARK: - ورقة تأكيد الاستيراد

/// ما سيُكتب معروضًا قبل أن يُكتب: تاريخ النسخة، وعائلات ما فيها بعددها، وتحذيرٌ
/// صريح بأنها تحلّ محلّ الحاضر. من هنا وحده تُستبدل سنواتُ أحدهم ببياناتٍ أخرى.
private struct ImportConfirmSheet: View {
    let preview: DataExport.Preview
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { Theme.accent(for: "sea") }

    /// «5 سبتمبر 2026» — بأرقام لاتينية كسائر أرقام التطبيق.
    private var exportedText: String? {
        guard let date = preview.exported else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                warning
                list
                buttons
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .background { AtharBackground(tint: tint) }
    }

    private var header: some View {
        VStack(spacing: 10) {
            IconChip(icon: "square.and.arrow.down.on.square.fill", tint: tint, size: .lg)
            Text(loc("استيراد نسخة احتياطية"))
                .font(Theme.display(20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitle: String {
        switch (exportedText, preview.appVersion) {
        case let (date?, version?): return loc("نسخة %1$@ · من إصدار %2$@", date, version)
        case let (date?, nil):      return loc("نسخة %1$@", date)
        default:                    return preview.fileName
        }
    }

    /// التحذير أوّلًا وبلون الخطر: الاستيراد لا يُرجَع عنه، ومن يقرؤه بعد الضغط لا ينتفع به.
    private var warning: some View {
        AtharCard(padding: 14, tint: Theme.danger) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.danger)
                    .accessibilityHidden(true)
                Text(loc("ما في هذا الملف يحلّ محلّ ما عندك الآن، ولا رجوع عنه. وما لا ذكر له في الملف يبقى كما هو."))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var list: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("ما سيُستعاد"), tint: tint)
            SettingsCard {
                ForEach(Array(preview.families.enumerated()), id: \.element.id) { i, family in
                    SettingsRow(icon: family.icon, tint: Theme.accent(for: family.accent), title: family.title) {
                        SettingsValue(text: family.count.counterText)
                    }
                    // العدد وحده لا يُقرأ: يُضمّ إلى اسم العائلة قيمةً لها.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(family.title)
                    .accessibilityValue(valuesText(family.count))
                    if i < preview.families.count - 1 { SettingsDivider() }
                }
            }
            Text(loc("المجموع: %1$@", valuesText(preview.count)))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                onConfirm()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text(loc("استيراد واستبدال"))
                }
                .font(Theme.display(16, weight: .semibold))
                .gradientButton(LinearGradient(colors: [Theme.danger, Theme.danger.opacity(0.78)],
                                               startPoint: .topTrailing, endPoint: .bottomLeading),
                                glow: Theme.danger)
            }
            .pressable()
            .accessibilityHint(loc("يستبدل بياناتك الحالية بما في الملف"))

            Button { dismiss() } label: {
                Text(loc("cancel"))
                    .font(Theme.display(16, weight: .semibold))
                    .softButton(tint)
            }
            .pressable()
        }
        .padding(.top, 4)
    }
}

/// تمييز العدد في العربية: مفردٌ للواحدة، ومثنّى لاثنتين، وجمعٌ مجرور من ٣ إلى ١٠، ومفردٌ فوقها.
private func valuesText(_ n: Int) -> String {
    switch n {
    case 1:      return loc("قيمة واحدة")
    case 2:      return loc("قيمتان")
    case 3...10: return loc("%1$@ قيم", n.counterText)
    default:     return loc("%1$@ قيمة", n.counterText)
    }
}
