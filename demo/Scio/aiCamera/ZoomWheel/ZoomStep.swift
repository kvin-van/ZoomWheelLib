import AVFoundation

/// 一个变焦档位：变焦倍数 + 在 UI 上的显示样式
public struct ZoomStep: Sendable {
    /// 变焦倍数（0.5 超广角 / 1.0 主摄 / 2.0 两倍）
    public let zoom: CGFloat

    /// 焦距文案，如 "24mm"，仅 type 为 focalLength 时显示
    public let focalLength: String?

    /// UI 展示样式
    public let type: ZoomStep.DisplayType

    public enum DisplayType: Int, Sendable {
        /// 圆点
        case dot = 0
        /// 倍数文字，如 "2×"
        case value = 1
        /// 焦距文字，如 "24mm"
        case focalLength = 2
    }

    public init(zoom: CGFloat, focalLength: String? = nil, type: ZoomStep.DisplayType = .value) {
        self.zoom = zoom
        self.focalLength = focalLength
        self.type = type
    }
}

extension ZoomStep: Identifiable {
    public var id: Int { zoom.hashValue }
}

extension ZoomStep {
    /// 默认档位：从超广角到 10× 长焦
    public static let defaultSteps: [ZoomStep] = [
        .init(zoom: 0.5, focalLength: "13 mm", type: .focalLength),
        .init(zoom: 1.0, focalLength: "24 mm", type: .focalLength),
        .init(zoom: 1.2, focalLength: "28 mm", type: .dot),
        .init(zoom: 1.5, focalLength: "35 mm", type: .dot),
        .init(zoom: 2.0, focalLength: "48 mm", type: .value),
        .init(zoom: 3.0, focalLength: "77 mm", type: .focalLength),
        .init(zoom: 10.0, type: .value)
    ]
}

extension ZoomStep {
    /// 根据设备实际支持的变焦范围生成可用档位
    public static func zoomSteps(from minZoomFactor: CGFloat, to maxZoomFactor: CGFloat) -> [ZoomStep] {
        var steps: [ZoomStep] = []

        // 支持超广角时添加 0.5×
        if minZoomFactor == 0.5 {
            steps.append(ZoomStep(zoom: 0.5, focalLength: "13 mm", type: .focalLength))
        }

        if maxZoomFactor >= 1.0 {
            // 主摄与中间过渡档位
            steps.append(ZoomStep(zoom: 1.0, focalLength: "24 mm", type: .focalLength))
            steps.append(ZoomStep(zoom: 1.2, focalLength: "28 mm", type: .dot))
            steps.append(ZoomStep(zoom: 1.5, focalLength: "35 mm", type: .dot))
        }

        // 按设备长焦能力逐级添加
        if maxZoomFactor >= 2.0 {
            steps.append(ZoomStep(zoom: 2.0, focalLength: "48 mm", type: minZoomFactor < 1.0 ? .value : .focalLength))
        }
        if maxZoomFactor >= 3.0 {
            steps.append(ZoomStep(zoom: 3.0, focalLength: "77 mm", type: .focalLength))
        }
        if maxZoomFactor >= 5.0 {
            steps.append(ZoomStep(zoom: 5.0, focalLength: "120 mm", type: .value))
        }

        // 超过 10× 时补上最大档位
        if maxZoomFactor > 10.0 {
            steps.append(ZoomStep(zoom: 10.0, focalLength: "240mm", type: .value))
        }

        return steps
    }
}

extension AVCaptureDevice {
    /// 当前摄像头实际可用的变焦档位
    public var zoomSteps: [ZoomStep] {
        return ZoomStep.zoomSteps(from: minAvailableVideoZoomFactor, to: maxAvailableVideoZoomFactor)
    }
}
