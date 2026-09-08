import SwiftUI
import UIKit

/// دعاء الختمة: يُفتح عند تمام الختمة، ومن خاتمة الناس في القارئ، ومن باب المصحف.
///
/// ولا يُكتب فيه دعاءٌ يُنسب إلى النبي ﷺ: لم يثبت عنه لفظٌ بعينه يُقال عند الختم،
/// فالمعروض دعاءُ القرآن نفسِه — مواضعُه تُحلّ من `quran.json` بمعرّفاتها (انظر
/// `KhatmahDua`) — والباب مفتوح بعدها لدعاء صاحبه بما شاء.
struct KhatmahDuaView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var copied: String?

    private var tint: Color { Theme.gold }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                intro.appearStagger(0)
                ForEach(Array(KhatmahDua.all.enumerated()), id: \.element.id) { index, dua in
                    card(dua).appearStagger(min(index + 1, 6))
                }
                closing.appearStagger(7)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: tint) }
        .navigationTitle(loc("دعاء الختمة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: التصدير

    /// يُقال ما لا يُعرف: من فتح الصفحة ينتظر الدعاء المطبوع في آخر المصحف، فيُخبَر
    /// لِمَ لم يجده — بلا تهوين ولا تشنيع، وبلا فتوى: خبرٌ عن ثبوتِ لفظٍ لا حكمٌ على قائله.
    private var intro: some View {
        AtharCard(padding: 18, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconChip(icon: "hands.sparkles.fill", tint: tint)
                    Text(loc("تقبّل الله ختمتك"))
                        .font(Theme.display(18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text(loc("لم يثبت عن النبي ﷺ دعاءٌ بلفظٍ معيّن يُقال عند ختم القرآن، والمطبوع في أواخر المصاحف لا يصحّ رفعُه إليه — فلم نكتبه هنا."))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text(loc("وهذه مواضع الدعاء في القرآن نفسه، تدعو بها بلفظٍ لا يُخشى عليه — تامّةً كما في المصحف، لا يُقتطع منها."))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: الدعاء

    private func card(_ dua: KhatmahDua) -> some View {
        let text = dua.text
        return AtharCard(padding: 18, elevation: .e1, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(dua.theme))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)

                // النصّ الشرعي بخط النسخ دائمًا — لا يتبع خطّ الواجهة المختار.
                Text(text)
                    .font(Theme.dhikrFont(size: 20))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(10)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Text(dua.source)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                    Spacer(minLength: 0)
                    Button {
                        UIPasteboard.general.string = "\(text)\n\(dua.source)"
                        Haptics.tap(enabled: store.hapticsEnabled)
                        withAnimation(Motion.smooth) { copied = dua.id }
                    } label: {
                        Label(copied == dua.id ? loc("نُسخت") : loc("نسخ"),
                              systemImage: copied == dua.id ? "checkmark" : "doc.on.doc")
                            .font(Theme.display(12, weight: .semibold))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(tint)
                    }
                    .pressable()
                    .accessibilityLabel(loc("نسخ الدعاء"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // النصّ والعزو صوتٌ واحد: لا يُقرأ الدعاء ثم يُعاد اسمُ سورته منفصلًا.
        .accessibilityElement(children: .combine)
    }

    private var closing: some View {
        Text(loc("ثمّ ادعُ بما شئت من خير لنفسك ولوالديك وللمسلمين."))
            .font(Theme.display(12))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}
