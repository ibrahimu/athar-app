import SwiftUI

/// حاسبة زكاة المال — تعمل بلا إنترنت: المستخدم يدخل أمواله وأسعار الذهب والفضة
/// بنفسه، والتطبيق يحسب النصاب (٨٥ غرام ذهب) والواجب (ربع العشر) فورًا.
/// الأسعار تُحفظ لأنها لا تتغيّر كل يوم، والمبالغ لا تُحفظ لأنها خاصّة وتتبدّل كل حَوْل.
struct ZakatView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    /// الحقول — نصوص لا أرقام حتى يكتب المستخدم بحرّية (فاصلة، صفر بادئ) ونحن نفسّر.
    @State private var cash = ""
    @State private var gold = ""
    @State private var silver = ""
    @State private var trade = ""
    @State private var receivables = ""
    @State private var debts = ""
    @State private var goldPrice = ""
    @State private var silverPrice = ""
    @State private var confirmReset = false
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case cash, gold, silver, trade, receivables, debts, goldPrice, silverPrice
    }

    private var tint: Color { Theme.accent(for: "calm") }

    private var input: ZakatInput {
        ZakatInput(cash: ZakatNumber.parse(cash),
                   goldGrams: ZakatNumber.parse(gold),
                   silverGrams: ZakatNumber.parse(silver),
                   tradeGoods: ZakatNumber.parse(trade),
                   receivables: ZakatNumber.parse(receivables),
                   debtsDue: ZakatNumber.parse(debts),
                   goldPricePerGram: ZakatNumber.parse(goldPrice),
                   silverPricePerGram: ZakatNumber.parse(silverPrice))
    }

    private var result: ZakatResult { Zakat.compute(input) }

    private var hasAnyAmount: Bool {
        [cash, gold, silver, trade, receivables, debts].contains { ZakatNumber.parse($0) > 0 }
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    header.appearStagger(0)
                    resultCard.appearStagger(1)
                    amountsSection.appearStagger(2)
                    pricesSection.appearStagger(3)
                    resetButton.appearStagger(4)
                    notesCard.appearStagger(5)
                    evidenceCard.appearStagger(6)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
                // نقرة خارج الحقول تُغلق لوحة المفاتيح؛ الحقول والأزرار تسبقها في الالتقاط.
                .contentShape(Rectangle())
                .onTapGesture { focused = nil }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(loc("الزكاة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(loc("تم")) { focused = nil }
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .onAppear(perform: loadPrices)
        // السعران يُحفظان فور كتابتهما — لا زرّ حفظ.
        .onChange(of: goldPrice) { _, v in store.zakatGoldPrice = ZakatNumber.parse(v) }
        .onChange(of: silverPrice) { _, v in store.zakatSilverPrice = ZakatNumber.parse(v) }
        .alert(loc("تصفير المبالغ؟"), isPresented: $confirmReset) {
            Button(loc("تصفير"), role: .destructive, action: resetAmounts)
            Button(loc("إلغاء"), role: .cancel) {}
        } message: {
            Text(loc("تُمسح المبالغ المدخلة، وتبقى أسعار الذهب والفضة محفوظة."))
        }
    }

    // MARK: الرأس

    private var header: some View {
        VStack(spacing: 6) {
            Text(loc("حاسبة زكاة المال"))
                .font(Theme.display(24, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(loc("أدخل ما تملك وسعر الغرام اليوم، ويُحسب الواجب فورًا — كل شيء يبقى على جهازك."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: النتيجة

    private var resultCard: some View {
        let r = result
        // «لا نعرف النصاب» لا «لا زكاة عليك»: النصاب يُعرف بسعر الذهب أو الفضة، أيّهما أدخل.
        let priceMissing = !r.nisabKnown
        return AtharCard(padding: 20, elevation: .e2, tint: tint, radius: Theme.Radius.xl) {
            VStack(spacing: 14) {
                Text(loc("الزكاة الواجبة"))
                    .font(Theme.display(13, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)

                // الرقم الكبير ذهبيّ — ذروة الشاشة كلها.
                Text(ZakatNumber.string(r.due))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: r.due)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                statusPill(reaches: r.reachesNisab, priceMissing: priceMissing)

                SettingsDivider(inset: 0)

                HStack(spacing: 0) {
                    figure(title: loc("مجموع المال الزكوي"), value: ZakatNumber.string(r.base))
                    Rectangle().fill(Theme.hairline.opacity(0.6)).frame(width: 0.7, height: 34)
                    figure(title: r.nisabMetal == .silver ? loc("النصاب (بالفضة)") : loc("النصاب (بالذهب)"),
                           value: priceMissing ? "—" : ZakatNumber.string(r.nisab))
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.top, 1)
                    Text(loc("تجب الزكاة إذا مضت على المال سنة هجرية كاملة (الحَوْل) وهو بالغٌ النصاب."))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .shadow(color: tint.opacity(0.14), radius: 18, y: 8)
    }

    private func figure(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusPill(reaches: Bool, priceMissing: Bool) -> some View {
        let (icon, text, color): (String, String, Color) = priceMissing
            ? ("info.circle.fill", loc("أدخل سعر غرام الذهب أو الفضة ليُحسب النصاب"), Theme.inkFaint)
            : reaches
                ? ("checkmark.seal.fill", loc("بلغ المال النصاب"), Theme.accent(for: "green"))
                : ("minus.circle.fill", loc("لم يبلغ المال النصاب — لا زكاة عليه"), Theme.inkSoft)
        return HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(text).font(Theme.display(12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 13).padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 0.5))
        .multilineTextAlignment(.center)
    }

    // MARK: الحقول

    private var amountsSection: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("أموالك"), tint: tint)
            SettingsCard {
                // مجموعتان لأن باني الواجهة يقبل عشرة عناصر لا أكثر (٦ صفوف + ٥ فواصل = ١١).
                Group {
                    amountRow(.cash, icon: "banknote.fill", tint: Theme.accent(for: "green"),
                              title: loc("النقد"), subtitle: loc("في اليد والحسابات"), text: $cash)
                    SettingsDivider(inset: 16)
                    amountRow(.gold, icon: "circle.hexagongrid.fill", tint: Theme.gold,
                              title: loc("الذهب (غرام)"), subtitle: nil, text: $gold)
                    SettingsDivider(inset: 16)
                    amountRow(.silver, icon: "circle.hexagongrid", tint: Theme.accent(for: "sea"),
                              title: loc("الفضة (غرام)"), subtitle: nil, text: $silver)
                    SettingsDivider(inset: 16)
                }
                Group {
                    amountRow(.trade, icon: "shippingbox.fill", tint: Theme.accent(for: "asr"),
                              title: loc("عروض التجارة"), subtitle: loc("بسعر بيعها اليوم"), text: $trade)
                    SettingsDivider(inset: 16)
                    amountRow(.receivables, icon: "arrow.down.left.circle.fill", tint: Theme.accent(for: "dawn"),
                              title: loc("ديون لك"), subtitle: loc("المرجوّ سدادها"), text: $receivables)
                    SettingsDivider(inset: 16)
                    amountRow(.debts, icon: "arrow.up.right.circle.fill", tint: Theme.danger,
                              title: loc("ديون عليك"), subtitle: loc("الحالّة — تُخصم"), text: $debts)
                }
            }
        }
    }

    private var pricesSection: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("أسعار اليوم — تُحفظ"), tint: tint)
            SettingsCard {
                amountRow(.goldPrice, icon: "tag.fill", tint: Theme.gold,
                          title: loc("سعر غرام الذهب"), subtitle: loc("عيار ما تملكه"), text: $goldPrice)
                SettingsDivider(inset: 16)
                amountRow(.silverPrice, icon: "tag", tint: Theme.accent(for: "sea"),
                          title: loc("سعر غرام الفضة"), subtitle: nil, text: $silverPrice)
            }
        }
    }

    private func amountRow(_ field: Field, icon: String, tint: Color, title: String,
                           subtitle: String?, text: Binding<String>) -> some View {
        let active = focused == field
        return HStack(spacing: 13) {
            IconChip(icon: icon, tint: tint, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Spacer(minLength: 8)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .focused($focused, equals: field)
                // بلا تسمية ينطق VoiceOver الحقول الثمانية كلها «٠» فلا يُعرف أيّها.
                .accessibilityLabel(subtitle.map { loc("%1$@ — %2$@", title, $0) } ?? title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(active ? tint.opacity(0.6) : Theme.hairline.opacity(0.5),
                                  lineWidth: active ? 1 : 0.5))
                .animation(Motion.snappy, value: active)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // نقرة على الصف كلّه تفتح حقله — الهدف أوسع من المربّع الصغير.
        .onTapGesture { focused = field }
    }

    // MARK: تصفير

    private var resetButton: some View {
        Button {
            focused = nil
            confirmReset = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text(loc("تصفير"))
                    .font(Theme.display(15, weight: .semibold))
            }
            .softButton(Theme.danger)
        }
        .pressable()
        .disabled(!hasAnyAmount)
        .opacity(hasAnyAmount ? 1 : 0.5)
    }

    private func resetAmounts() {
        withAnimation(Motion.snappy) {
            cash = ""; gold = ""; silver = ""; trade = ""; receivables = ""; debts = ""
        }
        Haptics.done(enabled: store.hapticsEnabled)
    }

    /// الأسعار المحفوظة تُعرض في حقليهما عند الفتح — بلا فواصل تجميع حتى لا يتعثّر التفسير.
    private func loadPrices() {
        if goldPrice.isEmpty, store.zakatGoldPrice > 0 { goldPrice = ZakatNumber.editable(store.zakatGoldPrice) }
        if silverPrice.isEmpty, store.zakatSilverPrice > 0 { silverPrice = ZakatNumber.editable(store.zakatSilverPrice) }
    }

    // MARK: الملاحظات والأدلة

    private var notesCard: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("مسائل تهمّك"), tint: tint)
            AtharCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(Zakat.notes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 9) {
                            Circle()
                                .fill(tint.opacity(0.7))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(note)
                                .font(Theme.display(14))
                                .foregroundStyle(Theme.inkSoft)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var evidenceCard: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الدليل"), tint: Theme.gold)
            AtharCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(Zakat.evidence.enumerated()), id: \.offset) { i, e in
                        evidenceRow(text: e.text, source: e.source)
                        if i < Zakat.evidence.count - 1 { SettingsDivider(inset: 16) }
                    }
                }
            }
        }
    }

    /// النصّ الشرعي بخط النسخ وحبر الصفحة — لا يُلوَّن أبدًا؛ والمصدر تعليقًا خافتًا تحته.
    private func evidenceRow(text: String, source: String) -> some View {
        let isHadith = source.hasPrefix("رواه") || source.hasPrefix("متفق")
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isHadith ? "quote.opening" : "book.closed.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.gold)
                .frame(width: 20)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(Theme.dhikrFont(size: 17))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(source)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - الأرقام

/// تفسير ما يكتبه المستخدم وعرض النتائج — أرقام غربية دائمًا، تجميع بالفاصلة، وخانتان عشريتان.
