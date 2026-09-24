import SwiftUI

/// 变焦控件：按钮栏（点选）与弧形滑杆（长按后拖拽）两种模式，
/// 拖拽带档位磁吸和触觉反馈，松手后滑杆自动隐藏
@MainActor
public struct ZoomControl: View {
    /// 当前变焦倍数
    @Binding var zoomLevel: CGFloat

    /// 变焦档位，决定按钮取值和磁吸点
    let zoomSteps: [ZoomStep]

    /// 外观与行为配置
    let configuration: ZoomWheelConfiguration

    /// 最小变焦倍数，取第一个档位
    var minZoomLevel: CGFloat {
        zoomSteps.first!.zoom
    }

    /// 最大变焦倍数，取最后一个档位
    var maxZoomLevel: CGFloat {
        zoomSteps.last!.zoom
    }

    @State private var showSlider = false
    @State private var longPressTimer: Timer?
    @State private var hideTimer: Timer?
    @State private var isLongPressing = false
    @State private var isAnimatingSlider = false

    @State private var previousDragLocation: CGPoint?
    @State private var sliderIsDragging = false  // 滑杆正在拖拽
    @State private var lastSnappedZoom: CGFloat = 0  // 上次吸附的档位，用于触发触觉反馈

    public init(
        zoomLevel: Binding<CGFloat>,
        steps: [ZoomStep] = ZoomStep.defaultSteps,
        configuration: ZoomWheelConfiguration = .init()
    ) {
        self._zoomLevel = zoomLevel
        self.zoomSteps = steps
        self.configuration = configuration
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            if showSlider {
                // 弧形变焦滑杆
                ZoomWheel(
                    zoomLevel: $zoomLevel,
                    zoomSteps: zoomSteps,
                    configuration: configuration
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
            } else {
                // 变焦按钮栏
                ZoomButtonBar(
                    selectedZoom: $zoomLevel,
                    zoomValues: zoomSteps
                )
                .padding(.bottom)
                .offset(y: configuration.buttonOffset)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSlider)
        .sensoryFeedback(.increase, trigger: lastSnappedZoom)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if showSlider {
                        // 滑杆已显示：转发拖拽事件
                        sliderIsDragging = true
                        handleSliderDrag(value)
                    } else {
                        // 按钮栏状态：启动长按计时
                        startLongPress()
                    }
                }
                .onEnded { _ in
                    if showSlider {
                        // 结束滑杆拖拽
                        sliderIsDragging = false
                        endSliderDrag()
                    } else {
                        // 结束长按
                        endLongPress()
                    }
                }
        )
    }

    func zoomItem(title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 30)
            .background {
                if selected {
                    Capsule()
                        .fill(.white.opacity(0.4))
                        .background(.ultraThinMaterial) //毛玻璃
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selected)
    }


    private func animateSlider(show: Bool) {
        isAnimatingSlider = true
        showSlider = show

        // 动画结束后解除拖拽屏蔽
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            MainActor.assumeIsolated { [self] in
                isAnimatingSlider = false
            }
        }
    }

    // 长按不是用 LongPressGesture，而是用 DragGesture + Timer 模拟
    private func startLongPress() {
        guard !isLongPressing else { return }

        longPressTimer?.invalidate()

        // 按住 0.1 秒后切换为滑杆模式
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            MainActor.assumeIsolated { [self] in
                isLongPressing = true
                // 进入滑杆模式时清空上次位置
                previousDragLocation = nil
                animateSlider(show: true)
            }
        }
    }

    private func endLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil

        hideSlider()
    }

    private func hideSlider() {
        hideTimer?.invalidate()
        hideTimer = nil

        // 松手后延迟 1 秒隐藏滑杆
        if isLongPressing, !sliderIsDragging {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                MainActor.assumeIsolated { [self] in
                    isLongPressing = false

                    animateSlider(show: false)

                    hideTimer?.invalidate()
                    hideTimer = nil
                }
            }
        }
    }

    // MARK: - 滑杆拖拽
    private func handleSliderDrag(_ value: DragGesture.Value) {
        // 滑杆展开动画期间忽略拖拽
        guard !isAnimatingSlider else { return }

        hideTimer?.invalidate()
        hideTimer = nil

        // 用相邻两次事件的位置差计算增量
        if let previousLocation = previousDragLocation {
            let deltaX = value.location.x - previousLocation.x
            updateZoomFromDrag(deltaX)
        }

        // 记录本次位置，供下次计算差值
        previousDragLocation = value.location
    }

    private func endSliderDrag() {
        previousDragLocation = nil
        // 松手时吸附到最近档位，再安排隐藏
        snapToNearestZoomStep()
        hideSlider()
   }

    // 复用 ZoomWheel 的对数映射，保证角度与倍数换算一致
    private func updateZoomFromDrag(_ deltaX: CGFloat) {
        let currentAngle = zoomLevel.toZoomAngle(min: minZoomLevel, max: maxZoomLevel)

        let sensitivity: CGFloat = 0.5 // 灵敏度，越小越平滑
        let angleDelta = -CGFloat(deltaX) * sensitivity // 取反保证拖拽方向正确

        let newAngle = currentAngle + angleDelta
        let boundedAngle = max(45.0, min(135.0, newAngle)) // 限制在 45°~135°
        let newZoomLevel = boundedAngle.zoomFromAngle(min: minZoomLevel, max: maxZoomLevel)

        let snappedZoomLevel = applyDragSnapping(newZoomLevel)
        zoomLevel = max(minZoomLevel, min(maxZoomLevel, snappedZoomLevel))
    }

    // MARK: - 档位磁吸
    private func applyDragSnapping(_ targetZoom: CGFloat) -> CGFloat {
        let snapThreshold: CGFloat = 0.05 // 进入吸附的阈值

        let snapPoints = zoomSteps.map { $0.zoom }

        if let nearestSnap = snapPoints.min(by: { abs($0 - targetZoom) < abs($1 - targetZoom) }) {
            let distance = abs(nearestSnap - targetZoom)

            if distance < snapThreshold {
                if abs(nearestSnap - lastSnappedZoom) > 0.01 {
                    lastSnappedZoom = nearestSnap
                }

                let snapStrength: CGFloat = 0.2 // 吸附强度（0~1）
                return targetZoom + (nearestSnap - targetZoom) * snapStrength
            }
        }

        return targetZoom
    }

    private func snapToNearestZoomStep() {
        let snapThreshold: CGFloat = 0.05

        let snapPoints = zoomSteps.map { $0.zoom }

        if let nearestStep = snapPoints.min(by: { abs($0 - zoomLevel) < abs($1 - zoomLevel) }) {
            let distance = abs(nearestStep - zoomLevel)

            if distance < snapThreshold {
                zoomLevel = nearestStep
            }
        }
    }
}
