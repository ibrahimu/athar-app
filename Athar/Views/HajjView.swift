import SwiftUI

/// الحج والعمرة — مربّعان كبيران فوق بعض، كلٌّ يفتح دليلًا مفصّلًا متحقَّقًا شرعيًّا.
struct HajjView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.gold, secondary: Theme.accent)
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if let umrah = HajjData.umrah {
                            guideSquare(umrah, tint: Theme.accent(for: "sea"), badge: "العمرة")
                                .appearStagger(1)
                        }
                        if let hajj = HajjData.hajj {
                            guideSquare(hajj, tint: Theme.gold, badge: "الحج")
                                .appearStagger(2)
                        }
                        footer.appearStagger(3)
                    }
                    .padding(.horizontal, 18)
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
                .font(Theme.display(22, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(loc("دليل متحقَّق، خطوة بخطوة، على ما عليه العمل في الحرمين."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .appearStagger(0)
    }

    /// مربّع كبير لكل نسك.
    private func guideSquare(_ guide: HajjGuide, tint: Color, badge: String) -> some View {
        NavigationLink {
            HajjGuideView(guide: guide, tint: tint)
        } label: {
            AtharCard(padding: 20, elevation: .e2, tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(badge)
                            .font(Theme.display(12, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(Theme.gradient(for: tint == Theme.gold ? "gold" : "sea")))
                        Spacer()
                        Image(systemName: guide.icon)
                            .font(.system(size: 30))
                            .foregroundStyle(tint)
                            .frame(width: 58, height: 58)
                            .background(
                                Circle().fill(tint.opacity(0.13))
                                    .overlay(EightPointStar().fill(tint.opacity(0.06)).padding(8))
                            )
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(guide.title)
                            .font(Theme.display(21, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(guide.subtitle)
                            .font(Theme.display(12.5))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "list.number")
                            .font(.system(size: 12, weight: .semibold))
                        Text(loc("\(guide.steps.count.counterText) خطوة"))
                            .font(Theme.display(13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 13, weight: .semibold))
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

// MARK: - دليل مفصّل لنسك

struct HajjGuideView: View {
    let guide: HajjGuide
    var tint: Color = Theme.gold

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.accent)
            ScrollView {
                VStack(spacing: 14) {
                    Text(guide.subtitle)
                        .font(Theme.display(13))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    ForEach(Array(guide.steps.enumerated()), id: \.element.id) { i, step in
                        stepCard(index: i + 1, step: step)
                            .appearStagger(i)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func stepCard(index: Int, step: HajjStep) -> some View {
        AtharCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 11) {
                    // رقم الخطوة في ميدالية نجمية
                    ZStack {
                        EightPointStar().fill(tint.opacity(0.14))
                        EightPointStar().stroke(tint.opacity(0.5), lineWidth: 1)
                        Text(index.counterText)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 38, height: 38)

                    Text(step.name)
                        .font(Theme.display(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                Text(step.detail)
                    .font(Theme.display(14.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if step.hasDua {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "hands.and.sparkles.fill")
                                .font(.system(size: 11))
                            Text(loc("الذكر"))
                                .font(Theme.display(11, weight: .semibold))
                        }
                        .foregroundStyle(tint)
                        // النص المأثور — بخطّ النسخ، حِبرًا مهيبًا
                        Text(step.dua)
                            .font(Theme.dhikrFont(size: 18))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(9)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(tint.opacity(0.08))
                            .overlay(alignment: .top) {
                                Capsule().fill(Theme.goldGradient).frame(width: 40, height: 3).opacity(0.7)
                                    .padding(.top, 6)
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
