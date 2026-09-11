import XCTest
import UIKit
import CoreLocation
@testable import Athar

// MARK: - سهمٌ يدور مع الجهاز، واسمٌ لا يكذب

/// حدّان اجتمعا في مزوّدَي الأجهزة: جهةُ القبلة، واسمُ المكان الذي يُكتب تحت المواقيت.
/// كلاهما يخطئ صامتًا — لا انهيار ولا رسالة — والمستخدم يصدّق ما يرى.
final class QiblaOrientationAndPlaceNameTests: XCTestCase {

    // MARK: مرجع البوصلة

    /// كان `headingOrientation` مثبّتًا على الطول، فمن قلب جهازه عَرْضًا — والتطبيق على
    /// الآيباد كما هو على الآيفون — صلّى إلى تسعين درجة عن القبلة وسهمُه واثق. فهذه
    /// الاختبارات تحرس أن كل اتجاهٍ للواجهة يُترجم إلى مرجعه هو، لا إلى الطول.
    func testEveryInterfaceOrientationKeepsItsOwnReference() {
        XCTAssertEqual(HeadingProvider.headingOrientation(for: .portrait), .portrait)
        XCTAssertEqual(HeadingProvider.headingOrientation(for: .portraitUpsideDown), .portraitUpsideDown,
                       "المقلوب رأسًا على عقب اتجاهٌ قائم لا يُردّ إلى الطول")
        XCTAssertEqual(HeadingProvider.headingOrientation(for: .landscapeLeft), .landscapeRight)
        XCTAssertEqual(HeadingProvider.headingOrientation(for: .landscapeRight), .landscapeLeft)
    }

    /// جوهر العلّة: عَرْضٌ يُقرأ طولًا هو تسعون درجة من الخطأ في جهةٍ يُصلَّى إليها.
    func testLandscapeIsNeverReadAsPortrait() {
        for interface in [UIInterfaceOrientation.landscapeLeft, .landscapeRight] {
            let reference = HeadingProvider.headingOrientation(for: interface)
            XCTAssertNotEqual(reference, .portrait, "العَرْض لا يُقرأ طولًا")
            XCTAssertNotEqual(reference, .portraitUpsideDown, "ولا مقلوبًا")
        }
    }

    /// الأربعة تُترجم إلى أربعةٍ متمايزة: لو تصادم اثنان لضاع أحدهما في الآخر.
    func testTheFourReferencesAreDistinct() {
        let all: [UIInterfaceOrientation] = [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]
        let mapped = all.map { HeadingProvider.headingOrientation(for: $0).rawValue }
        XCTAssertEqual(Set(mapped).count, all.count)
    }

    /// ولمَ الانقلاب في العَرْض؟ لأنّ UIKit تعدّ من جهة المحتوى وCoreLocation من جهة
    /// الجهاز — وهو نصٌّ في رأس UIKit. يُثبَّت هنا حتى لا يظنّه قارئٌ لاحقًا خطأً فيقلبه.
    func testInterfaceLandscapeIsTheOppositeOfDeviceLandscape() {
        XCTAssertEqual(UIInterfaceOrientation.landscapeLeft.rawValue, UIDeviceOrientation.landscapeRight.rawValue)
        XCTAssertEqual(UIInterfaceOrientation.landscapeRight.rawValue, UIDeviceOrientation.landscapeLeft.rawValue)
        // وCLDeviceOrientation صورةٌ من UIDeviceOrientation بأرقامها نفسها.
        XCTAssertEqual(Int(CLDeviceOrientation.landscapeRight.rawValue), UIDeviceOrientation.landscapeRight.rawValue)
        XCTAssertEqual(Int(CLDeviceOrientation.portraitUpsideDown.rawValue), UIDeviceOrientation.portraitUpsideDown.rawValue)
    }

    /// مشهدٌ لم يُركَّب بعد لا اتجاه له، فيُعامل معاملة الطول — وهو ما كانت عليه الحال.
    func testUnknownInterfaceFallsBackToPortrait() {
        XCTAssertEqual(HeadingProvider.headingOrientation(for: .unknown), .portrait)
        XCTAssertEqual(HeadingProvider.headingOrientation(for: UIInterfaceOrientation(rawValue: 99) ?? .unknown), .portrait,
                       "قيمةٌ يستحدثها النظام غدًا لا تُسقط المرجع في المجهول")
    }

    // MARK: اسم المكان

    private let suiteName = "athar.tests.qibla.placename"
    /// أبها: خمسُ درجاتٍ من الرياض عرضًا وست غربًا — مواقيتُها ليست مواقيتَها.
    private let abha = CLLocationCoordinate2D(latitude: 18.2164, longitude: 42.5053)

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore() -> AtharStore {
        AtharStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    /// كان المزوّد يمرّر الاسم المحفوظ حين يخيب الجيوكودر، فيبطل حارسُ المخزن ولا يُحسّ:
    /// مسافرٌ بلا شبكة يرى «الرياض» فوق مواقيت أبها ويطمئنّ إليها.
    @MainActor
    func testFailedGeocodingDoesNotKeepThePreviousCityName() {
        let store = makeStore()
        store.placeName = "الرياض"
        let provider = LocationProvider(store: store)

        provider.apply(abha, name: nil)

        XCTAssertEqual(store.placeName, AtharStore.deviceLocationFallbackName,
                       "الاسم الغائب يُكتب مكانه الاسم الاحتياطي، لا اسمُ المدينة السابقة")
        XCTAssertNotEqual(store.placeName, "الرياض")
        XCTAssertTrue(store.usesDeviceLocation)
        XCTAssertEqual(store.coordinate.latitude, abha.latitude, accuracy: 0.0001)
        XCTAssertEqual(store.coordinate.longitude, abha.longitude, accuracy: 0.0001)
    }

    /// وأوّلُ فتحةٍ بلا شبكة: الاسم المبدئي «مكة المكرمة» ليس اسمَ مكانه، فلا يُثبَّت فوق إحداثيّه.
    @MainActor
    func testFirstRunOfflineDoesNotLabelTheUserWithTheDefaultCity() {
        let store = makeStore()
        let initial = store.placeName
        let provider = LocationProvider(store: store)

        provider.apply(abha, name: nil)

        XCTAssertEqual(store.placeName, AtharStore.deviceLocationFallbackName)
        XCTAssertNotEqual(store.placeName, initial)
    }

    /// وحين يجيب الجيوكودر يمرّ جوابه كما هو، بلا لمسٍ ولا حشو.
    @MainActor
    func testResolvedNameIsWrittenAsItCame() {
        let store = makeStore()
        store.placeName = "الرياض"
        let provider = LocationProvider(store: store)

        provider.apply(abha, name: "أبها")

        XCTAssertEqual(store.placeName, "أبها")
        XCTAssertFalse(provider.isResolving, "دوّارةُ الانتظار تقف بوصول الجواب")
    }

    /// جوابٌ فارغ كغيابه: لا يُكتب اسمٌ من فراغ.
    @MainActor
    func testEmptyResolvedNameIsTreatedAsNoName() {
        let store = makeStore()
        store.placeName = "الرياض"
        let provider = LocationProvider(store: store)

        provider.apply(abha, name: "")

        XCTAssertEqual(store.placeName, AtharStore.deviceLocationFallbackName)
    }

    /// ولهذا أثرٌ في الواجهة: ورقةُ الموقع تُغلق على تبدّل `placeName`، فمن كان على موقع
    /// الجهاز أصلًا لم يتبدّل عنده اسمٌ ولا عَلَم، فلا تُغلق الورقة ويظنّ ضغطته ضاعت.
    @MainActor
    func testNameChangesSoTheLocationSheetHasSomethingToObserve() {
        let store = makeStore()
        store.setDeviceLocation(CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753), name: "الرياض")
        let before = store.placeName
        let provider = LocationProvider(store: store)

        provider.apply(abha, name: nil)

        XCTAssertNotEqual(store.placeName, before, "لولا التبدّل لبقيت الورقة مفتوحة بلا خبر")
    }
}
