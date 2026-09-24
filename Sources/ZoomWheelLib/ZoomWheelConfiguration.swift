import SwiftUI

/// 变焦组件的外观与行为配置
public struct ZoomWheelConfiguration: Sendable {
    /// 按钮栏的垂直偏移，正值下移、负值上移
    let buttonOffset: CGFloat

    /// 滑杆弧高（点），影响弧度和可交互弧长
    let height: CGFloat

    /// 是否显示焦距文案；false 时只显示倍数
    let displayFocalLength: Bool

    public init(
        buttonOffset: CGFloat = 0,
        height: CGFloat = 130,
        displayFocalLength: Bool = true
    ) {
        self.buttonOffset = buttonOffset
        self.height = height
        self.displayFocalLength = displayFocalLength
    }
}
