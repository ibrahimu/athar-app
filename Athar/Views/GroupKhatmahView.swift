import SwiftUI

/// الختمة الجماعية: أنشئ ختمة وشارك رمزها، أو انضم برمز، وتابع صفحات الجميع.
struct GroupKhatmahView: View {
    @EnvironmentObject private var store: AtharStore
    @ObservedObject private var service = GroupKhatmahService.shared
    @State private var title = ""
    @State private var name = ""
    @State private var code = ""
    @State private var days = 30
    @State private var confirmLeave = false

    private var tint: Color { Theme.gold }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let g = service.group {
                    groupCard(g)
                    membersCard
                    Button { confirmLeave = true } label: {
                        Text(loc("مغادرة الختمة وحذف مشاركتي")).font(Theme.display(14, weight: .semibold)).frame(maxWidth: .infinity).softButton(Theme.danger)
                    }
                    .pressable().disabled(service.busy)
                } else if service.joinedCode != nil {
                    // عضوٌ برمزٍ محفوظ ولم تُجلَب ختمتُه بعد: يُعرض رمزُه ويُعاد الطلب،
                    // ولا يُعرض عليه إنشاءٌ ولا انضمام فينشئ ثانيةً أو ينضمّ مرّتين.
                    pendingCard
                } else {
                    intro
                    createCard
                    joinCard
                }
                if let e = service.error {
                    Text(e).font(Theme.display(12)).foregroundStyle(Theme.danger).multilineTextAlignment(.center)
                }
                Text(loc("تحتاج المشاركة إلى تسجيل الدخول إلى iCloud. يُحفظ اسمك وعدد صفحاتك في قاعدة التطبيق العامة لدى Apple؛ استخدم اسمًا مستعارًا إن رغبت. مغادرة الختمة تحذف مشاركتك."))
                    .font(Theme.display(11)).foregroundStyle(Theme.inkFaint).multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.gutter).padding(.top, 8).padding(.bottom, 32).readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: tint) }
        .navigationTitle(loc("ختمة جماعية"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { name = service.memberName; await service.refresh(); await service.sync(pages: store.khatmahPagesDone) }
        .refreshable { await service.sync(pages: store.khatmahPagesDone) }
        .confirmationDialog(loc("مغادرة الختمة؟"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(loc("مغادرة وحذف مشاركتي"), role: .destructive) { Task { await service.leave() } }
            Button(loc("إلغاء"), role: .cancel) {}
        } message: { Text("يُحذف اسمك وتقدمك من هذه الختمة. لا تتأثر ختمتك الشخصية أو صفحاتك المحفوظة على الجهاز.") }
    }

    /// انتظارُ الجلب أو تعذّرُه — لعضوٍ يحمل رمزًا.
    private var pendingCard: some View {
        AtharCard(padding: 16, tint: tint) {
            VStack(spacing: 12) {
                IconChip(icon: service.fetchFailed ? "exclamationmark.arrow.triangle.2.circlepath" : "person.3.fill",
                         tint: tint, size: .lg)
                Text(service.fetchFailed ? loc("تعذّر جلب ختمتك الجماعية") : loc("جارٍ جلب ختمتك الجماعية…"))
                    .font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if let code = service.joinedCode {
                    Text(loc("رمزك: %1$@", code))
                        .font(Theme.display(13, weight: .semibold)).foregroundStyle(tint)
                }
                Button { Task { await service.refresh() } } label: {
                    Text(loc("أعد المحاولة")).font(Theme.display(14, weight: .semibold))
                        .frame(maxWidth: .infinity).softButton(tint)
                }
                .pressable().disabled(service.busy)
                Button { confirmLeave = true } label: {
                    Text(loc("مغادرة الختمة وحذف مشاركتي")).font(Theme.display(13))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var intro: some View {
        AtharCard(padding: 16, tint: tint) {
            HStack(spacing: 12) {
                IconChip(icon: "person.3.fill", tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("أهل بيت أو أصدقاء يتقاسمون ختمة: كلٌّ يقرأ في مصحفه ويرى تقدّم الباقين."))
                        .font(Theme.display(14)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    // الصفحات تُحتسب من الختمة الشخصية، فمن لا ختمة له لا يتقدّم عدّاده
                    // ولا يدري لماذا — فيُقال له، ويُفتح له بابها.
                    Text(loc("صفحاتك تُحتسب من ختمتك الشخصية."))
                        .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle(text: loc("أنشئ ختمة"), tint: tint)
            SettingsCard {
                field(loc("اسم الختمة"), text: $title, placeholder: loc("ختمة العائلة"))
                SettingsDivider(inset: 16)
                field(loc("اسمك"), text: $name, placeholder: loc("كما يراه الأعضاء"))
                SettingsDivider(inset: 16)
                HStack {
                    Text(loc("المدة")).font(Theme.display(15)).foregroundStyle(Theme.ink)
                    Spacer()
                    Picker("", selection: $days) { ForEach([7, 15, 30, 60], id: \.self) {
                    // تمييز العدد كما في شاشة الختمة: «٧ أيام» لا «٧ يومًا».
                    Text(loc("%1$@ %2$@", $0.counterText, (3...10).contains($0) ? loc("أيام") : loc("يومًا"))).tag($0)
                } }
                        .pickerStyle(.menu).tint(tint)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            Button {
                Task { await service.create(title: title.isEmpty ? loc("ختمة") : title, name: name.isEmpty ? loc("عضو") : name, goalDays: days) }
            } label: {
                Text(service.busy ? loc("جارٍ…") : loc("إنشاء ومشاركة الرمز")).font(Theme.display(15, weight: .semibold)).frame(maxWidth: .infinity).gradientButton(Theme.goldGradient, glow: Theme.gold)
            }
            .pressable().disabled(service.busy)
        }
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle(text: loc("أو انضم برمز"), tint: tint)
            SettingsCard {
                field(loc("الرمز"), text: $code, placeholder: loc("ستة أحرف"))
                SettingsDivider(inset: 16)
                field(loc("اسمك"), text: $name, placeholder: loc("كما يراه الأعضاء"))
            }
            Button {
                Task { await service.join(code: code, name: name.isEmpty ? loc("عضو") : name) }
            } label: {
                Text(loc("انضمام")).font(Theme.display(15, weight: .semibold)).frame(maxWidth: .infinity).softButton(tint)
            }
            .pressable().disabled(service.busy || code.count < 4)
        }
    }

    private func groupCard(_ g: GroupKhatmah) -> some View {
        AtharCard(padding: 16, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                Text(g.title).font(Theme.display(18, weight: .bold)).foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    Text(loc("الرمز")).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                    Text(g.code).font(.custom("NotoNaskhArabic-Bold", size: 22)).foregroundStyle(tint).tracking(4)
                    Spacer()
                    ShareLink(item: loc("انضم إلى ختمة «%1$@» في تطبيق أثر بالرمز: %2$@", g.title, g.code)) {
                        Label(loc("مشاركة"), systemImage: "square.and.arrow.up").font(Theme.display(13, weight: .semibold))
                    }
                }
                let total = members.reduce(0) { $0 + $1.pages }
                ProgressRing(progress: min(1, Double(total) / Double(Quran.pageCount)), color: tint, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay(Text("\(Int(min(100, Double(total) / Double(Quran.pageCount) * 100)).counterText)٪").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink))
                // صفحات كلّ عضوٍ تُعدّ من أوّل المصحف، فجمعُها يحسب الصفحةَ الواحدة
                // مرارًا — فلا يصحّ نسبتُه إلى ٦٠٤. يُقال ما هو: مجموعُ ما قرأوه.
                // (والحلقة تبقى مؤشّرًا مقيَّدًا لا كسرًا دقيقًا.)
                Text(loc("مجموع ما قرأه الأعضاء: %1$@ صفحة — خلال %2$@ %3$@",
                         total.counterText, g.goalDays.counterText,
                         (3...10).contains(g.goalDays) ? loc("أيام") : loc("يومًا")))
                    .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var members: [GroupMember] { service.members }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle(text: loc("الأعضاء"), tint: tint)
            SettingsCard {
                if members.isEmpty {
                    Text(loc("لا أعضاء بعد — شارك الرمز.")).font(Theme.display(13)).foregroundStyle(Theme.inkFaint).padding(16)
                }
                ForEach(Array(members.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 12) {
                        IconChip(icon: m.mine ? "person.fill.checkmark" : "person.fill", tint: m.mine ? tint : Theme.inkFaint, size: .sm)
                        Text(m.name.isEmpty ? loc("عضو") : m.name).font(Theme.display(15, weight: m.mine ? .semibold : .regular)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(loc("%1$@ صفحة", m.pages.counterText)).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(tint).monospacedDigit()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if i < members.count - 1 { SettingsDivider() }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label).font(Theme.display(15)).foregroundStyle(Theme.ink)
            Spacer()
            TextField(placeholder, text: text).multilineTextAlignment(.trailing).font(Theme.display(15)).foregroundStyle(Theme.ink).frame(maxWidth: 200)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
