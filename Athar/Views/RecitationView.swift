import SwiftUI

// MARK: - شاشة التلاوة

/// اختيار القارئ، وتشغيل السور بثًّا أو تنزيلها للاستماع بلا إنترنت.
struct RecitationView: View {
    var isRootTab = false

    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @State private var query = ""
    @State private var showReciters = false

    private var filtered: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Quran.surahs }
        let n = q.strippedForSearch
        return Quran.surahs.filter { $0.name.strippedForSearch.contains(n) || String($0.id) == q }
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent)
            ScrollView {
                LazyVStack(spacing: 12) {
                    reciterCard
                    offlineNote
                    SettingsGroupTitle(text: loc("السور"))
                    SettingsCard {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, su in
                            surahRow(su)
                            if i < filtered.count - 1 { SettingsDivider() }
                        }
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView(loc("لا توجد نتائج"), systemImage: "magnifyingglass")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, audio.surah == nil ? 30 : 108)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) { MiniPlayer() }
        .searchable(text: $query, prompt: loc("ابحث عن سورة"))
        .navigationTitle(loc("التلاوة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .sheet(isPresented: $showReciters) {
            ReciterPicker()
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
    }

    // MARK: القارئ الحالي

    private var reciterCard: some View {
        Button { showReciters = true } label: {
            AtharCard(padding: 14, tint: Theme.accent) {
                HStack(spacing: 13) {
                    Image(systemName: "waveform")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("القارئ"))
                            .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                        Text(audio.reciter.name)
                            .font(Theme.display(17, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
        .pressable()
    }

    private var offlineNote: some View {
        let sum = audio.downloadedSummary(reciter: audio.reciterId)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: sum.count > 0 ? "arrow.down.circle.fill" : "wifi")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
                .padding(.top, 1)
            Text(sum.count > 0
                 ? loc("محمَّل لهذا القارئ: %1$@ سورة · %2$@. المحمَّل يعمل بلا إنترنت.",
                       sum.count.counterText, sum.bytes.fileSizeText)
                 : loc("التشغيل يحتاج إنترنت. نزّل السورة لتسمعها بلا اتصال."))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceAlt))
    }

    // MARK: صف سورة

    private func surahRow(_ su: Surah) -> some View {
        let isCurrent = audio.surah == su.id
        let dl = audio.state(reciter: audio.reciterId, surah: su.id)
        return HStack(spacing: 12) {
            Button { audio.toggle(surah: su.id) } label: {
                Image(systemName: isCurrent && audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(isCurrent ? Theme.onAccent : Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isCurrent ? Theme.accent : Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(loc("سورة %1$@", su.name))
                    .font(Theme.display(15, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                Text("\(su.revelation) · \(su.ayahCount.counterText) آية")
                    .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 6)
            downloadControl(su.id, dl)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(isCurrent ? Theme.accent.opacity(0.05) : .clear)
    }

    @ViewBuilder
    private func downloadControl(_ s: Int, _ dl: DownloadState) -> some View {
        switch dl {
        case .idle, .failed:
            Button { audio.download(surah: s) } label: {
                Image(systemName: dl == .failed ? "exclamationmark.arrow.circlepath" : "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(dl == .failed ? Color.red.opacity(0.7) : Theme.inkFaint)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        case .waiting:
            ProgressView().controlSize(.small).frame(width: 34, height: 34)
        case .downloading(let f):
            ZStack {
                Circle().stroke(Theme.accent.opacity(0.15), lineWidth: 2.5)
                Circle().trim(from: 0, to: max(0.02, f))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            .frame(width: 34, height: 34)
            .animation(Motion.snappy, value: f)
        case .done:
            Menu {
                Button(loc("حذف التنزيل"), systemImage: "trash", role: .destructive) {
                    audio.delete(surah: s)
                }
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
            }
        }
    }
}

// MARK: - اختيار القارئ

struct ReciterPicker: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.accent)
                ScrollView {
                    VStack(spacing: 12) {
                        SettingsCard {
                            ForEach(Array(RecitationLibrary.reciters.enumerated()), id: \.element.id) { i, r in
                                let sum = audio.downloadedSummary(reciter: r.id)
                                Button {
                                    audio.select(r)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: audio.reciterId == r.id
                                              ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 17))
                                            .foregroundStyle(audio.reciterId == r.id ? Theme.accent : Theme.hairline)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.name)
                                                .font(Theme.display(15,
                                                      weight: audio.reciterId == r.id ? .semibold : .regular))
                                                .foregroundStyle(Theme.ink)
                                            if sum.count > 0 {
                                                Text(loc("%1$@ سورة محمَّلة · %2$@",
                                                         sum.count.counterText, sum.bytes.fileSizeText))
                                                    .font(Theme.display(10.5))
                                                    .foregroundStyle(Theme.inkFaint)
                                            }
                                        }
                                        Spacer()
                                        if sum.count > 0 {
                                            Menu {
                                                Button(loc("حذف تنزيلات هذا القارئ"),
                                                       systemImage: "trash", role: .destructive) {
                                                    audio.deleteAll(reciter: r.id)
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle")
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Theme.inkFaint)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if i < RecitationLibrary.reciters.count - 1 { SettingsDivider() }
                            }
                        }

                        Text(loc("التلاوات من موقع MP3Quran.net، متاحة للعموم بلا مقابل، برواية حفص عن عاصم."))
                            .font(Theme.display(11.5))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                    .readableWidth(560)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(loc("اختر القارئ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("تم")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - مشغّل مصغّر

/// شريط تشغيل ثابت أسفل الشاشة — يظهر ما دامت هناك سورة جارية.
struct MiniPlayer: View {
    @StateObject private var audio = Recitation.shared

    var body: some View {
        if let s = audio.surah, let su = Quran.surah(s) {
            VStack(spacing: 7) {
                HStack(spacing: 12) {
                    Button { audio.toggle(surah: s) } label: {
                        ZStack {
                            Circle().fill(Theme.accentGradient).frame(width: 38, height: 38)
                            if audio.isBuffering {
                                ProgressView().controlSize(.small).tint(Theme.onAccent)
                            } else {
                                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.onAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc("سورة %1$@", su.name))
                            .font(Theme.display(14, weight: .semibold))
                            .foregroundStyle(Theme.ink).lineLimit(1)
                        Text(audio.failed ? loc("تعذّر التشغيل — تحقّق من الاتصال") : audio.reciter.name)
                            .font(Theme.display(11))
                            .foregroundStyle(audio.failed ? Color.red.opacity(0.8) : Theme.inkFaint)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)

                    Button { audio.repeats.toggle() } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(audio.repeats ? Theme.accent : Theme.inkFaint)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(audio.repeats ? Theme.accent.opacity(0.12) : .clear))
                    }
                    .buttonStyle(.plain)

                    Button { audio.stop() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }

                // شريط التقدّم — قابل للسحب للانتقال داخل السورة.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.14))
                        Capsule().fill(Theme.accent)
                            .frame(width: max(2, g.size.width * audio.progress))
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                        audio.seek(to: v.location.x / max(1, g.size.width))
                    })
                }
                .frame(height: 4)
                // الشريط يُملأ من اليسار كالزمن، فلا يُعكس مع اتجاه الواجهة.
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
            )
            .atharElevation(.e2)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(Motion.smooth, value: audio.surah)
        }
    }
}
