import SwiftUI

/// 圆弧扇形修饰器：把内容约束在圆弧区域内，并叠加半透明玻璃背景
public struct CircleSegmentModifier: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let segment : CircularSegment

    public init(width: CGFloat, height: CGFloat, color: Color = .black.opacity(0.4)) {
        self.width = width
        self.height = height
        self.segment = CircularSegment(width: width, height: height)
        self.color = color
    }

    public func body(content: Content) -> some View {
            content
                .frame(width: width, height: height)
                .contentShape(segment)
                .background {
                    segment
                        .fill(color)
                        .frame(width: width, height: height)
                        .clipped()

                }
                .likeGlass(color, shape: segment)
    }
}

extension View {
    /// 将视图包裹进圆弧扇形背景中
    public func circleSegment(width: CGFloat, height: CGFloat, color: Color = .black.opacity(0.4)) -> some View {
        modifier(CircleSegmentModifier(width: width, height: height, color: color))
    }
}

#Preview {
    VStack {
        Spacer()

        Text("Hello, World!")
            .font(.largeTitle)
            .foregroundStyle(.white)
            .circleSegment(width: UIScreen.main.bounds.width, height: 130, color: .blue.opacity(0.4))
    }
    .ignoresSafeArea()
}
