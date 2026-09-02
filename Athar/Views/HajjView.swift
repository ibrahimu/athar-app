import SwiftUI

/// الحج والعمرة — المحتوى قيد التحقق، والهيكل جاهز.
struct HajjView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground()
                ContentUnavailableView("قريبًا", systemImage: "building.columns.fill",
                                       description: Text("دليل الحج والعمرة قيد الإعداد."))
            }
            .navigationTitle("الحج والعمرة")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
