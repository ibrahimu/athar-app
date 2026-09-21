import SwiftUI
import UIKit

struct ReadingPathsView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var adding = false
    @State private var title = ""
    @State private var page = 1
    @State private var editing: ReadingPath?
    @State private var remove: ReadingPath?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                AtharCard(padding: 18, tint: Theme.accent) {
                    HStack(alignment: .top, spacing: 14) {
                        IconChip(icon: "bookmark.fill", tint: Theme.accent, size: .lg)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("لكل قراءة موضعها")
                                .font(Theme.display(22, weight: .bold)).foregroundStyle(Theme.ink)
                            Text("تابع ختمتك أو مراجعتك من هنا. البحث وفتح سورة أخرى لا يغيّران موضعها.")
                                .font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Button {
                    editing = nil
                    page = Quran.page(of: store.lastRead ?? AyahRef(surah: 1, ayah: 1))
                    title = ""; adding = true
                } label: {
                    Label("قراءة جديدة من موضعي", systemImage: "bookmark.badge.plus")
                        .font(Theme.display(15, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .foregroundStyle(Theme.onAccent)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                }.buttonStyle(.plain)
                if !store.readingPaths.isEmpty {
                    Text("قراءاتك المحفوظة")
                        .font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                        .padding(.top, 8).padding(.horizontal, 4)
                }
                ForEach(store.readingPaths) { path in
                    AtharCard(padding: 16) {
                        HStack(spacing: 8) {
                            NavigationLink {
                                SurahReaderView(surahId: path.position.surah, scrollTo: path.position, readingPathID: path.id)
                            } label: {
                                HStack(spacing: 12) {
                                    IconChip(icon: "book.closed", tint: Theme.accent)
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(path.title).font(Theme.display(17, weight: .semibold)).foregroundStyle(Theme.ink)
                                        Text("سورة \(Quran.surah(path.position.surah)?.name ?? "") · صفحة \(Quran.page(of: path.position))")
                                            .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
                                    }
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Menu {
                                Button { editing = path; title = path.title; page = Quran.page(of: path.position); adding = true } label: {
                                    Label("تعديل القراءة", systemImage: "pencil")
                                }
                                Button(role: .destructive) { remove = path } label: {
                                    Label("حذف القراءة", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.inkSoft).frame(width: 44, height: 44).contentShape(Rectangle())
                            }.accessibilityLabel("خيارات قراءة \(path.title)")
                        }
                    }
                }
                if store.readingPaths.isEmpty {
                    AtharCard {
                        Text("احفظ ختمتك أو مراجعتك الأولى، ثم تنقّل في المصحف بحرية.")
                            .font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding(Theme.gutter).readableWidth(620)
        }
        .background { AtharBackground(tint: Theme.accent) }
        .tint(Theme.accent)
        .onAppear { store.prepareReadingPaths() }
        .navigationTitle("قراءاتي").navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $adding, onDismiss: { editing = nil }) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AtharCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("اسم القراءة", systemImage: "bookmark")
                                    .font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.accent)
                                TextField("مثل ختمة رمضان", text: $title)
                                    .font(Theme.display(17)).padding(12)
                                    .background(Theme.surfaceAlt, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        AtharCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("موضع البداية", systemImage: "book")
                                    .font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.accent)
                                Stepper("صفحة \(page)", value: $page, in: 1...Quran.pageCount)
                                    .font(Theme.display(16))
                                HStack {
                                    Text("رقم الصفحة").font(Theme.display(14))
                                    TextField("رقم الصفحة", value: $page, format: .number)
                                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                        .font(Theme.display(17)).padding(12)
                                        .background(Theme.surfaceAlt, in: RoundedRectangle(cornerRadius: 12))
                                }
                                Text("من 1 إلى \(Quran.pageCount)").font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            }
                        }
                        Text("سيُحفظ موضع هذه القراءة وحدها أثناء تصفّحها.")
                            .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
                    }.padding(Theme.gutter).readableWidth(620)
                }
                .background { AtharBackground(tint: Theme.accent) }
                .foregroundStyle(Theme.ink)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(editing == nil ? "قراءة جديدة" : "تعديل القراءة")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { adding = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("حفظ") { save(); adding = false }
                            .disabled(!(1...Quran.pageCount).contains(page) || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.tint(Theme.accent).environment(\.layoutDirection, .rightToLeft).atharSheetChrome()
        }
        .confirmationDialog("حذف القراءة المحفوظة؟", isPresented: Binding(get: { remove != nil }, set: { if !$0 { remove = nil } }), titleVisibility: .visible) {
            Button("حذف القراءة", role: .destructive) {
                if let remove { store.readingPaths = store.readingPaths.filter { $0.id != remove.id } }
                remove = nil
            }
        } message: { Text("يحذف الاسم والموضع فقط؛ لا يحذف تدبّراتك أو علاماتك.") }
    }
    private func save() {
        let ref = Quran.firstAyah(ofPage: page)
        if let editing, let index = store.readingPaths.firstIndex(where: { $0.id == editing.id }) {
            var paths = store.readingPaths
            paths[index].title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
            if page != Quran.page(of: editing.position) { paths[index].position = ref }
            store.readingPaths = paths
        } else { store.addReadingPath(title: title, at: ref) }
    }
}

struct QiyamReaderView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var page = 1
    @State private var size: Double = 23
    @State private var showJump = false
    @State private var jump = 1
    private var originals: ClosedRange<Int> { QiyamLayout.originalPages(for: page) }
    private var refs: [AyahRef] { originals.flatMap { Quran.ayahs(inPage: $0) } }
    private var groups: [(surah: Int, refs: [AyahRef])] {
        let all = refs
        return Array(Set(all.map(\.surah))).sorted().map { s in (s, all.filter { $0.surah == s }) }
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("اللوحة \(page) من \(QiyamLayout.count)").font(Theme.display(18, weight: .bold))
                        Text("صفحات المصحف الأصلية: \(originals.lowerBound)–\(originals.upperBound)")
                            .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                        Text("عرض مكثّف للنص الكامل؛ ليست هذه أرقام صفحات طبعة جديدة. مرّر لقراءة بقية اللوحة، وكبّر الخط بما يريحك.")
                            .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                        HStack {
                            Image(systemName: "textformat.size")
                            Slider(value: $size, in: 16...36, step: 1).accessibilityLabel("حجم خط مصحف القيام")
                        }
                    }.id("top")
                    ForEach(groups, id: \.surah) { group in
                        VStack(spacing: 14) {
                            Text("سورة \(Quran.surah(group.surah)?.name ?? "")").font(Theme.display(19, weight: .semibold))
                            if group.refs.first?.ayah == 1 && group.surah != 1 && group.surah != 9 {
                                Text(Quran.basmalah).font(Theme.dhikrFont(size: CGFloat(size)))
                            }
                            QiyamJustifiedText(
                                text: group.refs.map { "\(Quran.text($0) ?? "") ﴿\($0.ayah)﴾" }.joined(separator: " "),
                                fontSize: CGFloat(size)
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    NavigationLink("افتح الموضع في المصحف الأصلي") {
                        let ref = Quran.firstAyah(ofPage: originals.lowerBound)
                        SurahReaderView(surahId: ref.surah, scrollTo: ref)
                    }.font(Theme.display(14))
                }.padding(Theme.gutter).readableWidth(820)
            }
            .onChange(of: page) { _, value in
                store.defaults.set(value, forKey: "athar.mushaf.qiyam.page")
                proxy.scrollTo("top", anchor: .top)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("السابق") { page -= 1 }.disabled(page <= 1)
                Spacer()
                Button("\(page) / 200") { jump = page; showJump = true }.accessibilityLabel("الانتقال إلى لوحة")
                Spacer()
                Button("التالي") { page += 1 }.disabled(page >= QiyamLayout.count)
            }.font(Theme.display(16, weight: .semibold)).padding().background(Theme.canvas)
        }
        .background(Theme.canvas)
        .navigationTitle("مصحف القيام").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            page = max(1, min(200, store.defaults.integer(forKey: "athar.mushaf.qiyam.page")))
        }
        .sheet(isPresented: $showJump) {
            NavigationStack {
                Form {
                    Stepper("اللوحة \(jump)", value: $jump, in: 1...200)
                    TextField("رقم اللوحة", value: $jump, format: .number).keyboardType(.numberPad)
                    Button("انتقل") { page = jump; showJump = false }.disabled(!(1...200).contains(jump))
                }
                .scrollContentBackground(.hidden)
                .background { AtharBackground(tint: Theme.accent) }
                .font(Theme.display(15)).foregroundStyle(Theme.ink).tint(Theme.accent)
                .navigationTitle("انتقال")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { showJump = false } } }
            }
            .atharSheetChrome()
        }
    }
}


/// Native paragraph layout keeps Arabic shaping and selection while aligning both margins.
private struct QiyamJustifiedText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineSpacing = 8
        paragraph.lineBreakMode = .byWordWrapping
        let base = UIFont(name: "NotoNaskhArabic-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize)
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: view.traitCollection)
        let content = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor(Theme.ink),
            .paragraphStyle: paragraph
        ])
        if !view.attributedText.isEqual(to: content) {
            view.attributedText = content
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: ceil(height))
    }
}
