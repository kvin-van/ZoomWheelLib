import CoreGraphics
import Foundation

extension CGFloat {

    /// 变焦倍数 → 轮盘角度（对数映射到 45°~135°）
    func toZoomAngle(min: CGFloat = 0.5, max: CGFloat = 10.0) -> CGFloat {
        let logMin = log(min)
        let logMax = log(max)
        let logZoom = log(self)

        let progress = (logZoom - logMin) / (logMax - logMin)
        return 45 + progress * 90
    }

    /// 轮盘角度 → 变焦倍数
    func zoomFromAngle(min: CGFloat = 0.5, max: CGFloat = 10.0) -> CGFloat {
        // 将 45°~135° 归一化为 0~1
        let progress = (self - 45) / 90.0

        let logMin = log(min)
        let logMax = log(max)
        let logZoom = logMin + progress * (logMax - logMin)

        return exp(logZoom)
    }
}
