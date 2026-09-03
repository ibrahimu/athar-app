import SwiftUI

/// الحج والعمرة — مربّعان كبيران، كلٌّ يفتح دليلًا مفصّلًا منظّمًا بالأيقونات.
struct HajjView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    /// الشاشة تقرأ ألوان الطابع من Theme ساكنةً ولا تحمل قيمةً تتغيّر معه، فلولا مراقبة
    /// المخزن لبقيت بألوانها القديمة بعد تبديل الطابع من «المظهر» حتى إعادة التشغيل.
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                AtharBackground(tint: Theme.accent(for: "gold"), secondary: Theme.accent(for: "sea"))
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if let umrah = HajjData.umrah {
                            guideSquare(umrah, tint: Theme.accent(for: "sea"), badge: loc("العمرة"))
                                .appearStagger(1)
                        }
                        if let hajj = HajjData.hajj {
                            guideSquare(hajj, tint: Theme.accent(for: "gold"), badge: loc("الحج"))
                                .appearStagger(2)
                        }
                        footer.appearStagger(3)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                    .readableWidth(560)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(loc("الحج والعمرة"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(loc("مناسك بين يديك"))
                .font(Theme.display(23, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(loc("دليل منظّم خطوة بخطوة، بالأدعية المأثورة."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .appearStagger(0)
    }

    private func guideSquare(_ guide: HajjGuide, tint: Color, badge: String) -> some View {
        NavigationLink {
            HajjGuideView(guide: guide, tint: tint)
        } label: {
            AtharCard(padding: 20, elevation: .e2, tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        // رمز مختلف لكل نسك، بلون واحد على دائرة صبغته
                        ZStack {
                            Circle().fill(tint.opacity(0.13))
                            if badge == loc("العمرة") {
                                KaabaMark(color: tint).padding(15)      // العمرة: الكعبة
                            } else {
                                Image(systemName: "mountain.2.fill")     // الحج: عرفة
                                    .font(.system(size: 26)).foregroundStyle(tint)
                            }
                        }
                        .frame(width: 58, height: 58)
                        Spacer()
                        Text(badge)
                            .font(Theme.display(13, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.gradient(for: badge == loc("العمرة") ? "sea" : "gold")))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(guide.title)
                            .font(Theme.display(21, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(guide.subtitle)
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 12, weight: .semibold))
                        Text(loc("%1$@ خطوات", guide.steps.count.counterText))
                            .font(Theme.display(13, weight: .semibold))
                        Spacer()
                        Text(loc("ابدأ الدليل"))
                            .font(Theme.display(13, weight: .semibold))
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .pressable()
    }

    private var footer: some View {
        Text("﴿ وَأَتِمُّوا۟ ٱلْحَجَّ وَٱلْعُمْرَةَ لِلَّهِ ﴾")
            .font(Theme.dhikrFont(size: 16))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

// MARK: - دليل مفصّل منظّم

struct HajjGuideView: View {
    let guide: HajjGuide
    var tint: Color = Theme.gold
    /// الذهبي والحبر يُقرآن ساكنين في الجسد؛ مراقبة المخزن تُعيد رسمهما مع تبديل الطابع.
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.accent(for: "sea"))
            ScrollView {
                VStack(spacing: 14) {
                    // شريط تعريفي بعدد الخطوات
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .font(.system(size: 13))
                        Text(loc("%1$@ خطوات · بالأدعية المأثورة", guide.steps.count.counterText))
                            .font(Theme.display(13, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(tint.opacity(0.12)))
                    .padding(.top, 4)

                    ForEach(Array(guide.steps.enumerated()), id: \.element.id) { i, step in
                        stepCard(index: i + 1, step: step, isLast: i == guide.steps.count - 1)
                            .appearStagger(i)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 34)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func stepCard(index: Int, step: HajjStep, isLast: Bool) -> some View {
        AtharCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // رأس الخطوة: رقم + أيقونة معناها + الاسم، على صبغة لون النسك
                HStack(spacing: 12) {
                    ZStack {
                        EightPointStar().fill(tint.opacity(0.16))
                        EightPointStar().stroke(tint.opacity(0.5), lineWidth: 1)
                        Text(index.counterText)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 40, height: 40)

                    Text(step.name)
                        .font(Theme.display(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

                SettingsDivider()

                // الشرح
                Text(step.detail)
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 12)

                // الذكر المأثور
                if step.hasDua {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hands.and.sparkles.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 2)
                        Text(step.dua)
                            .font(Theme.dhikrFont(size: 17))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(9)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.gold.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.gold.opacity(0.22), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 12).padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)
        }
    }
}
