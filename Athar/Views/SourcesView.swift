import SwiftUI

/// المصادر والحقوق — إسناد كل محتوى إلى أهله، ووفاءً بشروط تراخيصه.
struct SourcesView: View {
    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 22) {
                    block(
                        icon: "book.pages.fill",
                        title: loc("نص المصحف"),
                        body: loc("النص بالرسم العثماني من **مشروع تنزيل (Tanzil Project)**، مُدقَّق على مصحف المدينة النبوية، ومنقول كما هو دون أي تغيير — بما فيه علامات الوقف والسجدات."),
                        linkTitle: "tanzil.net",
                        url: "https://tanzil.net",
                        note: loc("تشترط رخصة المشروع إظهار المصدر بوضوح مع رابط إليه، وعدم تغيير النص.")
                    )

                    block(
                        icon: "text.book.closed.fill",
                        title: loc("الأذكار"),
                        body: loc("الأذكار من القرآن الكريم والسنة النبوية الصحيحة، وكل ذكر مقترن بتخريجه من مصادره: البخاري، ومسلم، وأبي داود، والترمذي، والنسائي، وابن ماجه، وأحمد."),
                        linkTitle: nil, url: nil,
                        note: loc("نصوص الوحي وأحاديث الكتب الستة تراث عام.")
                    )

                    block(
                        icon: "textformat",
                        title: loc("الخط"),
                        body: loc("خط **Noto Naskh Arabic** من مشروع Noto، مرخّص برخصة الخطوط المفتوحة SIL Open Font License 1.1 التي تتيح التضمين في التطبيقات."),
                        linkTitle: "notofonts.github.io",
                        url: "https://notofonts.github.io",
                        note: nil
                    )

                    block(
                        icon: "function",
                        title: loc("أوقات الصلاة والقبلة"),
                        body: loc("تُحسب على جهازك بالخوارزمية الفلكية القياسية، بلا اتصال بأي خادم. واتجاه القبلة بحساب الدائرة العظمى إلى الكعبة."),
                        linkTitle: nil, url: nil,
                        note: loc("الأوقات تقريبية وقد تختلف دقائق عن تقويم مسجد حيّك.")
                    )

                    Text(loc("إن رأيت خطأً في نصّ أو إسناد، فأخبرنا — تصحيح النص الشرعي أولى من كل شيء."))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("المصادر والحقوق"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func block(icon: String, title: String, body: String,
                       linkTitle: String?, url: String?, note: String?) -> some View {
        AtharCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.accentSoft))
                    Text(title)
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }

                Text(.init(body))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let linkTitle, let url, let u = URL(string: url) {
                    Link(destination: u) {
                        HStack(spacing: 4) {
                            Text(linkTitle).font(Theme.display(13, weight: .medium))
                            Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                }

                if let note {
                    Text(note)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
