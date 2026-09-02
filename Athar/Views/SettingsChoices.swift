import Foundation

// المطابقة هنا لا في الملف المشترك: `SettingsChoice` بروتوكول واجهة،
// و PrayerTimes.swift يُبنى داخل الويدجت أيضًا حيث لا وجود له.

extension CalculationMethod: SettingsChoice {}
extension AsrMethod: SettingsChoice {}
extension CountTapArea: SettingsChoice {}
