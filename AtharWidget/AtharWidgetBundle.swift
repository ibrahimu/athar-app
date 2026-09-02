import WidgetKit
import SwiftUI

@main
struct AtharWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
        DhikrWidget()
        AtharProgressWidget()
        KhatmahWidget()
    }
}
