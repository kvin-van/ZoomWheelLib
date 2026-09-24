import SwiftUI

/// 变焦轮的弧形背景，通过弦高公式计算圆弧几何
public struct CircularSegment: Shape {
    /// 弦长（弧的宽度）
    let width: CGFloat

    /// 可见弧高
    let height: CGFloat

    /// 由弦长和弧高反推半径：r = 弦长²/(8×弧高) + 弧高/2
    private var radius: CGFloat {
        let chord = width
        let segmentHeight = height
        return (chord * chord) / (8 * segmentHeight) + (segmentHeight / 2)
    }

    private var centerY: CGFloat {
        return radius - height
    }

    /// 圆心角的一半：α = arccos((r - h) / r)
    private var segmentAngle: CGFloat {
        let alpha = acos((radius - height) / radius)
        return alpha * 180 / CGFloat.pi
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: width / 2, y: height + centerY)
        let startAngle = 90 - segmentAngle
        let endAngle = 90 + segmentAngle

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: true
        )
        return path
    }
}
