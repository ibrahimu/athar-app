import SwiftUI
import UIKit

/// ورقة المشاركة للملفات (ShareLink لا يقبل ملفًا مؤقتًا بمعاينة مناسبة).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }
