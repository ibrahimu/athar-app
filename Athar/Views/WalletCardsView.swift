import SwiftUI
import PassKit

/// «بطاقات Wallet»: مكتبة بطاقات موقَّعة مسبقًا (آية الكرسي، خواتيم البقرة، سيد الاستغفار،
/// أذكار الصباح والمساء…) يختار المستخدم منها ما يضيفه إلى Apple Wallet عبر
/// PKAddPassesViewController — لا يحتاج استحقاقًا ولا خادمًا. الموجود منها في المحفظة
/// يُعلَّم بختم، ويُفتح من Wallet مباشرة.
struct WalletCardsView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var query = ""
    @State private var preview: WalletCard?
    @State private var pending: [PKPass] = []
    @State private var showAdd = false
    @State private var passes: [String: PKPass] = [:]
    @State private var isLoading = true
    @State private var inWallet: Set<String> = []

    private var tint: Color { Theme.accent(for: "gold") }
    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }
    private var canAdd: Bool { PKAddPassesViewController.canAddPasses() }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                LazyVStack(spacing: 22) {
                    intro
                    if isLoading {
                        ProgressView("جارٍ تجهيز البطاقات…")
                            .font(Theme.display(13)).tint(tint)
                    }
                    if filteredGroups.isEmpty { ContentUnavailableView.search(text: query) }
                    ForEach(filteredGroups) { group in
                        section(group)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
            // ورقة الإضافة الجماعية («أضف الكل») على المُمرِّر، وورقة المعاينة على الحاوية:
            // ورقتان على عنصر واحد تتنازعان العرض.
            .sheet(isPresented: $showAdd, onDismiss: refresh) {
                AddPassesController(passes: pending) {
                    showAdd = false
                    refresh()
                }
                .ignoresSafeArea()
                .environment(\.layoutDirection, direction)
            }
        }
        .navigationTitle(loc("بطاقات المحفظة"))
        .searchable(text: $query, prompt: "ابحث عن بطاقة أو ذكر")
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .task {
            let loaded = await WalletPassLoader.shared.load()
            guard !Task.isCancelled else { return }
            passes = loaded
            isLoading = false
            refresh()
        }
        .sheet(item: $preview) { card in
            WalletCardSheet(card: card, tint: tint, pass: passes[card.id],
                            isInWallet: inWallet.contains(card.id), canAdd: canAdd, isLoading: isLoading) {
                refresh()
            }
            .atharSheetChrome()
            .presentationDetents([.large])
            .environment(\.layoutDirection, direction)
        }
    }

    // MARK: المقدّمة

    private var intro: some View {
        AtharCard(padding: 18, elevation: .e2, tint: tint) {
            HStack(alignment: .top, spacing: 14) {
                IconChip(icon: "wallet.pass.fill", tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("آياتك وأذكارك في محفظتك"))
                        .font(Theme.display(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(canAdd
                         ? loc("آيات وأذكار قريبة منك، حتى دون إنترنت. اختر بطاقة لمعاينتها وإضافتها إلى محفظتك. تجد النص الكامل في تفاصيل البطاقة.")
                         : loc("Apple Wallet غير متاح على هذا الجهاز."))
                        .font(Theme.display(13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !inWallet.isEmpty {
                        Text("البطاقات في محفظتك: \(inWallet.count.counterText)")
                            .font(Theme.display(12, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }

    // MARK: المجموعات

    private func section(_ group: WalletCardLibrary.Group) -> some View {
        let missing = group.cards.filter { !inWallet.contains($0.id) && passes[$0.id] != nil }
        let addAll: (() -> Void)? = (canAdd && missing.count > 1) ? { add(missing) } : nil
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: group.title, tint: tint, action: addAll, actionTitle: loc("أضف الكل"))
            AtharCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(group.cards.enumerated()), id: \.element.id) { i, card in
                        row(card)
                        if i < group.cards.count - 1 { SettingsDivider() }
                    }
                }
            }
        }
    }

    private var filteredGroups: [WalletCardLibrary.Group] {
        let key = ArabicMatch.normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return WalletCardLibrary.groups.compactMap { group in
            let cards = group.cards.filter { key.isEmpty || ArabicMatch.normalize($0.title + " " + $0.category + " " + $0.source).contains(key) }
            return cards.isEmpty ? nil : .init(title: group.title, cards: cards)
        }
    }

    private func row(_ card: WalletCard) -> some View {
        let added = inWallet.contains(card.id)
        return Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            preview = card
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.09))
                    Image(systemName: card.isQuran ? "book.closed" : "sparkles")
                        .font(.system(size: 23, weight: .light)).foregroundStyle(Theme.accent)
                }
                .frame(width: 56, height: 68)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.25), lineWidth: 0.7))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title).font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(card.source).font(Theme.display(11)).foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                    if added {
                        Label("في المحفظة", systemImage: "checkmark.circle.fill")
                            .font(Theme.display(11)).foregroundStyle(Theme.success)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkFaint)
            }
            .padding(16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(added ? "\(card.title)، في المحفظة" : card.title)
        .accessibilityHint("عرض البطاقة والنص الكامل")
    }

    // MARK: المحفظة

    /// تُحمَّل البطاقات من الحزمة مرّة، ثم تُسأل المحفظة عن الموجود منها.
    /// containsPass لا يحتاج استحقاق Pass Type ID، بخلاف passes().
    private func refresh() {
        guard PKPassLibrary.isPassLibraryAvailable() else { return }
        let library = PKPassLibrary()
        inWallet = Set(passes.filter { library.containsPass($0.value) }.map(\.key))
    }

    private func add(_ cards: [WalletCard]) {
        let list = cards.compactMap { passes[$0.id] }
        guard !list.isEmpty else { return }
        Haptics.tap(enabled: store.hapticsEnabled)
        pending = list
        showAdd = true
    }
}

// MARK: - معاينة بطاقة

private struct WalletCardSheet: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    let card: WalletCard
    let tint: Color
    let pass: PKPass?
    let isInWallet: Bool
    let canAdd: Bool
    let isLoading: Bool
    var onChange: () -> Void

    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    WalletCardArtwork(card: card)
                    actions
                    textCard
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(card.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("إغلاق")) { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: onChange) {
                AddPassesController(passes: pass.map { [$0] } ?? []) {
                    showAdd = false
                    onChange()
                    dismiss()
                }
                .ignoresSafeArea()
            }
        }
    }

    /// النصّ كما في مصادر التطبيق — نسخٌ بلون الحبر، لا نسخة من ألوان البطاقة.
    private var textCard: some View {
        AtharCard(padding: 20, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 14) {
                Text(card.text)
                    .font(Theme.dhikrFont(size: 20, scale: store.fontScale))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    Text(card.source)
                    if card.count > 1 { Text("· " + card.repetitionText) }
                }
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isInWallet, let url = pass?.passURL {
            VStack(spacing: 10) {
                Label(loc("موجودة في محفظتك"), systemImage: "checkmark.seal.fill")
                    .font(Theme.display(14, weight: .medium))
                    .foregroundStyle(tint)
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label(loc("افتح في المحفظة"), systemImage: "wallet.pass")
                        .font(Theme.display(15, weight: .semibold))
                        .softButton(tint)
                }
                .pressable()
            }
        } else if isLoading {
            ProgressView("جارٍ تجهيز البطاقة…").tint(tint)
        } else if pass == nil {
            Text(loc("تعذّر تحميل هذه البطاقة."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
        } else if canAdd {
            WalletAddButton {
                Haptics.tap(enabled: store.hapticsEnabled)
                showAdd = true
            }
            .frame(width: 230, height: 50)
        } else {
            Text(loc("Apple Wallet غير متاح على هذا الجهاز."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - ورقة Wallet النظامية

/// PKAddPassesViewController داخل ورقة SwiftUI: أزرار «إلغاء/إضافة» من النظام،
/// وإغلاق الورقة على عاتقنا عند انتهائه.
private struct AddPassesController: UIViewControllerRepresentable {
    let passes: [PKPass]
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard !passes.isEmpty, let controller = PKAddPassesViewController(passes: passes) else {
            DispatchQueue.main.async { onFinish() }
            return UIViewController()
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        var onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) { onFinish() }
    }
}

/// معاينة من أصل الرسم نفسه الذي يُوقّع داخل ملف البطاقة.
private struct WalletCardArtwork: View {
    let card: WalletCard
    private let ink = Color(hex: 0x14362C)
    private let gold = Color(hex: 0xA67C30)
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("أثر").font(Theme.naskhFont(fixed: 30, bold: true))
                Spacer()
                Text(card.category).font(Theme.display(11, weight: .medium))
            }
            .foregroundStyle(ink).padding(.horizontal, 20).padding(.top, 14)
            if let url = Bundle.main.url(forResource: card.id + "-preview", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
            } else {
                Text(card.title).font(Theme.dhikrFont(size: 26)).foregroundStyle(ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("المصدر").font(Theme.display(10)).foregroundStyle(gold)
                    Text(card.source).font(Theme.display(12)).foregroundStyle(ink)
                }
                Spacer()
                if !card.isQuran {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("التكرار").font(Theme.display(10)).foregroundStyle(gold)
                        Text(card.repetitionText).font(Theme.display(12)).foregroundStyle(ink)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(hex: 0xF7F2E7))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(gold.opacity(0.3), lineWidth: 0.7))
        .shadow(color: ink.opacity(0.12), radius: 15, y: 8)
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("معاينة بطاقة \(card.title). النص الكامل أسفل زر الإضافة.")
    }
}

private struct WalletAddButton: UIViewRepresentable {
    let action: () -> Void
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.accessibilityLabel = "إضافة إلى Apple Wallet"
        return button
    }
    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
}

/// التحقق من التواقيع وفك الملفات بعيدًا عن MainActor، مع إعادة استخدام النتيجة.
private actor WalletPassLoader {
    static let shared = WalletPassLoader()
    private var cached: [String: PKPass] = [:]

    func load() -> [String: PKPass] {
        if cached.count == WalletCardLibrary.cards.count { return cached }
        var loaded: [String: PKPass] = [:]
        for card in WalletCardLibrary.cards {
            guard let url = WalletCardLibrary.passURL(for: card),
                  let data = try? Data(contentsOf: url),
                  let pass = try? PKPass(data: data),
                  pass.serialNumber == card.serial,
                  pass.passTypeIdentifier == WalletCardLibrary.passTypeIdentifier else { continue }
            loaded[card.id] = pass
        }
        cached = loaded
        return loaded
    }
}
