import SwiftUI

/// الحج والعمرة — المحتوى قيد التحقق، والهيكل جاهز.
struct HajjView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground()
                ContentUnavailableView(loc("قريبًا"), systemImage: "building.columns.fill",
                                       description: Text(loc("دليل الحج والعمرة قيد الإعداد.")))
            }
            .navigationTitle(loc("الحج والعمرة"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
