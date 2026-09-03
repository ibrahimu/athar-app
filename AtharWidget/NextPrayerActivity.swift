import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

// MARK: - النشاط الحيّ: الصلاة القادمة

/// الصلاة القادمة بعدٍّ تنازلي في Dynamic Island وشاشة القفل.
/// الألوان من هوية الويدجت (AtharStyle) لا من طابع التطبيق: شاشة القفل لا تعرف الطابع
/// المختار ولا تُعاد رسمها عند تبديله، فتبقى لوحة الأوقات الثابتة أصدق.
/// هدف النشر iOS 17، فواجهات ActivityKit (iOS 16.2) متاحة بلا حراسة #available.
struct NextPrayerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NextPrayerAttributes.self) { context in
            let look = NextPrayerLook(context: context)
            NextPrayerLockScreenView(look: look)
                .activityBackgroundTint(look.moment.gradient.first)
                .activitySystemActionForegroundColor(look.moment.ink)
        } dynamicIsland: { context in
            let look = NextPrayerLook(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: look.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(look.tint)
                        Text(look.state.prayerTitle)
                            .font(.system(size: 17, weight: .bold))
                            .lineLimit(1)
                    }
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: look.range, countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(look.tint)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 82, alignment: .trailing)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(timerInterval: look.range, countsDown: false)
                            .progressViewStyle(.linear)
                            .tint(look.tint)
                        HStack {
                            Text(look.state.place)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(look.clock)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: look.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(look.tint)
            } compactTrailing: {
                Text(timerInterval: look.range, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(look.tint)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.7)
                    .frame(width: 54, alignment: .trailing)
            } minimal: {
                Image(systemName: look.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(look.tint)
            }
            .keylineTint(look.tint)
        }
    }
}

// MARK: - شاشة القفل / اللافتة

private struct NextPrayerLockScreenView: View {
    let look: NextPrayerLook

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: look.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(look.tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(look.tint.opacity(0.16)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(look.state.prayerTitle)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(look.moment.ink)
                        .lineLimit(1)
                    Text(look.state.place)
                        .font(.system(size: 12))
                        .foregroundStyle(look.moment.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(timerInterval: look.range, countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(look.tint)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(look.clock)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(look.moment.inkSoft)
                }
            }

            // خط تقدّم رفيع: يمتلئ من بدء النشاط حتى الأذان.
            ProgressView(timerInterval: look.range, countsDown: false)
                .progressViewStyle(.linear)
                .tint(look.tint)
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - المظهر

/// ما يُشتق من حالة النشاط لعرضه: الأيقونة واللون والمدى الزمني وساعة الأذان.
private struct NextPrayerLook {
    let state: NextPrayerAttributes.ContentState
    let startedAt: Date

    init(context: ActivityViewContext<NextPrayerAttributes>) {
        state = context.state
        startedAt = context.attributes.startedAt
    }

    private var prayer: Prayer { Prayer(rawValue: state.prayerKey) ?? .isha }

    var icon: String { prayer.icon }

    /// لحظة الويدجت المقابلة للصلاة — لونها هويّتها الثابتة (فجر بنفسجي، مغرب وردي…).
    var moment: AtharStyle.Moment {
        switch prayer {
        case .fajr, .sunrise: return .dawn
        case .dhuhr:          return .noon
        case .asr:            return .afternoon
        case .maghrib:        return .sunset
        case .isha:           return .night
        }
    }

    var tint: Color { moment.tint }

    /// من بدء النشاط إلى الأذان. الحدّ الأدنى لا يتجاوز الأعلى أبدًا — وإلا انهار
    /// ClosedRange عند التشغيل (يحدث لو انقضى الموعد قبل أن يُنهي التطبيق النشاط).
    var range: ClosedRange<Date> { min(startedAt, state.time)...state.time }

    /// ساعة الأذان بأرقام غربية وبمنطقة المكان المختار لا الجهاز — كما في ويدجت الأوقات.
    var clock: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm a"
        f.timeZone = AtharStore.shared.placeTimeZone
        return f.string(from: state.time)
    }
}
#endif
