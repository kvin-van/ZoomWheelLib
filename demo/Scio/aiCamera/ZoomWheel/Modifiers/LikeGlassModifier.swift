import SwiftUI

/// 类玻璃质感修饰器：半透明填充（iOS 26 glassEffect 的临时替代方案）
public struct LikeGlassModifier<S: Shape>: ViewModifier {
    let color: Color
    let shape: S

    public func body(content: Content) -> some View {
            content
                .background(
                    shape
                        .fill(color.opacity(0.1))
                )
    }
}

extension View {
    /// 应用类玻璃质感背景
    public func likeGlass<S: Shape>(_ color: Color = .white, shape: S = Capsule()) -> some View {
        modifier(LikeGlassModifier(color: color, shape: shape))
    }
}
