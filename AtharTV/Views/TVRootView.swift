import SwiftUI

/// الجذر: المدينةُ أوّلًا ثمّ اللون، وكلاهما مرّةً واحدة، ثمّ المجلس.
/// وبعدها لا يُسأل عن شيء: ما يُضبط مرّةً ويُنسى موضعُه «الإعدادات».
struct TVRootView: View {
    @ObservedObject private var prefs = TVPrefs.shared

    /// فتحُ شاشةٍ بعينها من سطر الأوامر — للتصوير والفحص، كما يفعل التطبيق مع
    /// `-whatsnew`. لا أثرَ له في الاستعمال العادي.
    private var forced: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    var body: some View {
        Group {
            if let forced {
                switch forced {
                case "settings": TVSettingsView()
                case "reciters": TVRecitersView()
                case "city":     CityPickerView()
                case "theme":    TVThemePicker()
                case "player":   TVPlayerView()
                default:         TVMajlisView()
                }
            } else if prefs.city == nil {
                CityPickerView()
            } else if !prefs.pickedTheme {
                TVThemePicker()
            } else {
                TVMajlisView()
            }
        }
        .animation(Motion.gentle, value: prefs.city?.id)
        .animation(Motion.gentle, value: prefs.pickedTheme)
    }
}

// MARK: - اللون، مرّةً واحدة

/// يُسأل عنه في أوّل تشغيلٍ ثمّ لا يُسأل: صفُّ ألوانٍ دائمٌ في أسفل المجلس كان
/// يشغل مكانًا لخيارٍ يُتّخذ مرّةً في العمر. وهو بعدُ في «الإعدادات» متى شاء.
struct TVThemePicker: View {
    @ObservedObject private var prefs = TVPrefs.shared
    @FocusState private var focus: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: TVMetric.gridGap), count: 6)

    var body: some View {
        TVScreen(title: loc("اختر لونك"), subtitle: loc("يمكنك تبديله من الإعدادات متى شئت.")) {
            LazyVGrid(columns: columns, spacing: TVMetric.gridGap) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        prefs.theme = theme
                        prefs.pickedTheme = true
                    } label: {
                        TVSwatch(theme: theme,
                                 chosen: prefs.theme == theme,
                                 focused: focus == theme.rawValue)
                    }
                    .focused($focus, equals: theme.rawValue)
                    .tvButton(focus == theme.rawValue, radius: TVMetric.tileRadius)
                }
            }
            .frame(maxWidth: 1500, alignment: .leading)
            .focusSection()
        }
        .onAppear { focus = prefs.theme.rawValue }
    }
}

/// مربّعُ لون: تدرّجُ الطابع واسمُه، والمختارُ عليه علامة. النصُّ إلى اليمين
/// كسائر نصوص التطبيق، ولو كان المربّعُ نفسُه في وسط الشاشة.
struct TVSwatch: View {
    let theme: AppTheme
    var chosen: Bool
    var focused: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: theme.palette.accent.dark),
                                              Color(hex: theme.palette.accent2.dark)],
                                     startPoint: .topTrailing, endPoint: .bottomLeading))
            TVStar()
                .fill(Color.white.opacity(0.10))
                .frame(width: 190, height: 190)
                .offset(x: -60, y: -52)
            HStack(spacing: 10) {
                Text(theme.title)
                    .font(Theme.display(TVType.caption, weight: .bold))
                    .foregroundStyle(Color(hex: theme.palette.canvas.dark))
                Spacer(minLength: 0)
                if chosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: TVType.caption, weight: .bold))
                        .foregroundStyle(Color(hex: theme.palette.canvas.dark))
                }
            }
            .padding(22)
        }
        .aspectRatio(1.25, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous))
        .tvFocus(focused, radius: TVMetric.tileRadius)
    }
}
