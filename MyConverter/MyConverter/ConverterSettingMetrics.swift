import SwiftUI

struct ConverterSettingMetrics {
    let rowCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let rowHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let controlHorizontalPadding: CGFloat
    let controlVerticalPadding: CGFloat
    let controlColumnWidth: CGFloat
    let sectionSpacing: CGFloat
    let hintVerticalPadding: CGFloat
    let folderIconSize: CGFloat
    let folderIconCornerRadius: CGFloat
    let chooseButtonHorizontalPadding: CGFloat
    let chooseButtonVerticalPadding: CGFloat
    let rowSpacing: CGFloat
    let stacksControlsVertically: Bool

    static let regular = ConverterSettingMetrics(
        rowCornerRadius: 18,
        controlCornerRadius: 12,
        rowHorizontalPadding: 16,
        rowVerticalPadding: 14,
        controlHorizontalPadding: 12,
        controlVerticalPadding: 9,
        controlColumnWidth: 248,
        sectionSpacing: 14,
        hintVerticalPadding: 12,
        folderIconSize: 28,
        folderIconCornerRadius: 10,
        chooseButtonHorizontalPadding: 16,
        chooseButtonVerticalPadding: 8,
        rowSpacing: 16,
        stacksControlsVertically: false
    )

    static let compact = ConverterSettingMetrics(
        rowCornerRadius: 17,
        controlCornerRadius: 11,
        rowHorizontalPadding: 15,
        rowVerticalPadding: 12,
        controlHorizontalPadding: 11,
        controlVerticalPadding: 8,
        controlColumnWidth: 236,
        sectionSpacing: 12,
        hintVerticalPadding: 11,
        folderIconSize: 26,
        folderIconCornerRadius: 9,
        chooseButtonHorizontalPadding: 14,
        chooseButtonVerticalPadding: 7,
        rowSpacing: 14,
        stacksControlsVertically: false
    )

    static let phone = ConverterSettingMetrics(
        rowCornerRadius: 16,
        controlCornerRadius: 11,
        rowHorizontalPadding: 14,
        rowVerticalPadding: 12,
        controlHorizontalPadding: 12,
        controlVerticalPadding: 10,
        controlColumnWidth: 236,
        sectionSpacing: 12,
        hintVerticalPadding: 11,
        folderIconSize: 24,
        folderIconCornerRadius: 8,
        chooseButtonHorizontalPadding: 14,
        chooseButtonVerticalPadding: 8,
        rowSpacing: 10,
        stacksControlsVertically: true
    )
}

private struct ConverterSettingMetricsKey: EnvironmentKey {
    static let defaultValue = ConverterSettingMetrics.regular
}

extension EnvironmentValues {
    var converterSettingMetrics: ConverterSettingMetrics {
        get { self[ConverterSettingMetricsKey.self] }
        set { self[ConverterSettingMetricsKey.self] = newValue }
    }
}

extension View {
    func converterSettingMetrics(_ metrics: ConverterSettingMetrics) -> some View {
        environment(\.converterSettingMetrics, metrics)
    }
}
