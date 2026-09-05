import WidgetKit
import SwiftUI

@main
struct AtharWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
        DhikrWidget()
        AtharProgressWidget()
        KhatmahWidget()
        HadithWidget()
        NameWidget()
        SunnahWidget()
        // النشاط الحيّ للصلاة القادمة. هدف النشر iOS 17 فلا يلزم #available(iOS 16.2)،
        // ويكفي التحقق من توفّر ActivityKit كما في تعريف السمات المشترك.
        #if canImport(ActivityKit)
        NextPrayerActivity()
        #endif
    }
}
