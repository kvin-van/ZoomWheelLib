import SwiftUI

/// 弧形变焦滑杆：45°~135° 圆弧 + 对数分布刻度 + 顶部固定指示针
public struct ZoomWheel: View {
    /// 当前变焦倍数
    @Binding var zoomLevel: CGFloat

    /// 最小变焦倍数，取第一个档位
    var minZoomLevel: CGFloat {
        zoomSteps.first!.zoom
    }

    /// 最大变焦倍数，取最后一个档位
    var maxZoomLevel: CGFloat {
        zoomSteps.last!.zoom
    }

    /// 变焦档位，用于刻度和磁吸
    let zoomSteps: [ZoomStep]

    let configuration: ZoomWheelConfiguration

    @State private var wheelRotation: CGFloat = 0
    @State private var targetRotation: CGFloat = 0

    @State private var cachedTickMarks: [CGFloat] = []
    @State private var cachedTickAngles: [CGFloat] = []

    @State private var minRotation: CGFloat = 0
    @State private var maxRotation: CGFloat = 0

    public init(
        zoomLevel: Binding<CGFloat>,
        zoomSteps: [ZoomStep],
        configuration: ZoomWheelConfiguration = .init()
    ) {
        self._zoomLevel = zoomLevel
        self.zoomSteps = zoomSteps
        self.configuration = configuration
    }

    /// 由弦长（宽）和弧高反推半径：r = 弦长²/(8×弧高) + 弧高/2
    private func radius(width: CGFloat) -> CGFloat {
        let chord = width
        let segmentHeight = configuration.height
        return (chord * chord) / (8 * segmentHeight) + (segmentHeight / 2)
    }

    /// 圆心 Y，使可见弧高恰好为 configuration.height
    private func centerY(width: CGFloat) -> CGFloat {
        return radius(width: width) - configuration.height
    }

    @ViewBuilder //刻度线
    private func tickMarks(width: CGFloat) -> some View {
        // 精细刻度（间距 0.1）
        ForEach(Array(zip(cachedTickMarks, cachedTickAngles).enumerated()), id: \.offset) { index, tickData in
            let (tickZoom, angle) = tickData
            let isMainTick = tickZoom == minZoomLevel || tickZoom.truncatingRemainder(dividingBy: 1) == 0

            Rectangle()
                .fill(Color.white.opacity(isMainTick ? 1 : 0.3))
                .frame(
                    width: 1,
                    height: 17
                )
                .offset(y: -radius(width: width) + 13)
                .rotationEffect(.degrees(angle))
        }
    }

    @ViewBuilder
    private func markings(width: CGFloat) -> some View {
        // 变焦档位主标记（按对数分布）
        ForEach(Array(zoomSteps.enumerated()), id: \.offset) { index, step in
            let angle = step.zoom.toZoomAngle(min: minZoomLevel, max: maxZoomLevel)
            let distanceToCenter = abs(angle + wheelRotation - 0)
            let normalizedDistance = min(distanceToCenter / 15.0, 1.0) // 以距中心 15° 为满量程

            let isActive = normalizedDistance < 0.3

            // 按距中心的距离计算缩放与透明度
            let scale =  (0.3 + 0.7 * normalizedDistance)
            let opacity = normalizedDistance

            Group {
                if step.type == .focalLength || step.type == .value || isActive {
                    VStack(spacing: 0) {
                        Text(formatZoomValue(step.zoom))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(isActive ? .yellow : .white)
                            .scaleEffect(scale)
                            .opacity(opacity)
                        if configuration.displayFocalLength, step.type == .focalLength, let unit = step.focalLength {
                            Text(unit)
                                .font(.caption2)
                                .scaleEffect(1)
                                .foregroundColor(isActive ? .yellow.opacity(0.9) : .white.opacity(0.5))
                        }
                    }
                    .offset(y: -radius(width: width) + 40)
                } else if step.type == .dot {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 3, height: 3)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(y: -radius(width: width) + 37)
                }
            }
            .rotationEffect(.degrees(angle))
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack {
                // 可旋转的刻度轮盘
                ZStack {
                    tickMarks(width: width)
                    markings(width: width)
                }
                .rotationEffect(.degrees(wheelRotation))
                .position(x: width / 2, y: configuration.height + centerY(width: width))
                .clipped() // 只显示弧内区域
            }
            .circleSegment(width: width, height: configuration.height)
            .overlay {
                // 顶部固定的黄色指示针
                Group {
                    Triangle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 14)
                        .rotationEffect(.degrees(180))
                        .position(x: width / 2, y: 8)

                    // 中间的当前倍数值
                    Text("\(formatZoomValue(zoomLevel, suffix: "×"))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .position(x: width / 2, y: 35)
                }

            }
        }
        .frame(height: configuration.height)
        .task {
            cachedTickMarks = generateTickMarks()
            cachedTickAngles = cachedTickMarks.map { $0.toZoomAngle(min: minZoomLevel, max: maxZoomLevel) }

            minRotation = -maxZoomLevel.toZoomAngle(min: minZoomLevel, max: maxZoomLevel)
            maxRotation = -minZoomLevel.toZoomAngle(min: minZoomLevel, max: maxZoomLevel)
        }
        .onAppear {
            // 初始旋转：让当前倍数对准顶部 90° 的指示针
            let currentZoomAngle = zoomLevel.toZoomAngle(min: minZoomLevel, max: maxZoomLevel)
            wheelRotation = -currentZoomAngle
            targetRotation = -currentZoomAngle

        }
        .onChange(of: zoomLevel) { oldValue, newValue in
            let currentZoomAngle = newValue.toZoomAngle(min: minZoomLevel, max: maxZoomLevel)
            targetRotation = -currentZoomAngle

            // 平滑插值
            func lerp(from: CGFloat, to: CGFloat, factor: CGFloat) -> CGFloat {
                return from + (to - from) * factor
            }
            wheelRotation = lerp(from: wheelRotation, to: targetRotation, factor: 0.6)
        }
    }

    private func generateTickMarks() -> [CGFloat] {
        var ticks: [CGFloat] = []

        // 在最小~最大倍数之间生成刻度
        var currentZoom = minZoomLevel

        while currentZoom <= maxZoomLevel {
            ticks.append(currentZoom)

            // 根据倍数区间选择刻度间距
            let stepSize: CGFloat
            if currentZoom < 1.0 {
                stepSize = 0.1  // 1× 以下，步长 0.1
            } else if currentZoom < 10.0 {
                stepSize = 0.1  // 1×~10×，步长 0.1
            } else {
                stepSize = 1.0  // 10× 以上，步长 1.0
            }

            currentZoom += stepSize

            // 取整避免浮点误差
            currentZoom = (currentZoom * 10).rounded() / 10
        }

        return ticks.filter { $0 >= minZoomLevel && $0 <= maxZoomLevel }
    }

    private func formatZoomValue(_ zoom: CGFloat, suffix: String? = nil) -> String {
        Formatters.numberFormatter(zoom, digits: zoom.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1, suffix: suffix)
    }
}
