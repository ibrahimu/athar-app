import SwiftUI
import WidgetKit

/// بياناتك: المزامنة والنسخ أولًا، ثم أرقامك وإحصاء الشهر، والتصفير آخر شيء —
/// فالفعل الذي لا يُرجَع عنه يأتي بعد كل ما يُبقي بياناتك لا قبله.
struct DataSettingsView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var showResetConfirm = false

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
                .environment(\.layoutDirection,
                             AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let n = try DataExport.importFile(url, into: store.defaults)
                    store.applyStoredTheme(); store.objectWillChange.send()
                    if store.cloudSyncEnabled { store.startCloudSync() } else { CloudKV.shared.stop() }
                    WidgetCenter.shared.reloadAllTimelines()
                    WatchSync.shared.push(store: store)
                    importMessage = loc("استُوردت %1$@ قيمة", n.counterText)
                    Task { await Reminders.rescheduleAll(store: store) }
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
                            subtitle: loc("التفضيلات والمفضّلة والعلامات فقط — لا العدّادات")) {
                    Toggle("", isOn: Binding(get: { store.cloudSyncEnabled }, set: { store.cloudSyncEnabled = $0 }))
                        .labelsHidden()
                        .accessibilityLabel(loc("مزامنة iCloud"))
                }
                SettingsDivider()
                Button { exportData() } label: {
                    SettingsRow(icon: "square.and.arrow.up.on.square.fill", tint: Theme.accent(for: "sea"),
                                title: loc("تصدير بياناتي"), subtitle: loc("ملف واحد: المفضّلة والسجلات والختمة والإعدادات")) { EmptyView() }
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
}
