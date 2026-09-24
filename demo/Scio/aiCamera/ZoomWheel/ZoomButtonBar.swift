import SwiftUI


public struct ZoomButtonBar: View {

    @Binding var selectedZoom: CGFloat

    let zoomValues: [ZoomStep]


    public init(
        selectedZoom: Binding<CGFloat>,
        zoomValues: [ZoomStep] = ZoomStep.defaultSteps
    ) {
        self._selectedZoom = selectedZoom
        self.zoomValues = zoomValues
    }


    public var body: some View {
        HStack(spacing: 5) {
            zoomButton(
                title: currentOneXValue(),
                active: selectedZoom < 2
            ) {
                withAnimation {
                    selectedZoom = 1.0
                }
            }
            zoomButton(
                title: currentTwoXValue(),
                active: selectedZoom >= 2
            ) {
                withAnimation {
                    selectedZoom = 2.0
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.1))
                .likeGlass(Color.black.opacity(0.1))
        )
    }

    // MARK: - 按钮
    private func zoomButton(
        title: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button {
            action()
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(active ? .yellow : .white)
                .frame(width: 50, height: 34)
                .background(
                    Circle()
                        .fill(
                            active
                            ? Color.black.opacity(0.6)
                            : Color.black.opacity(0.4)
                        )
                )
                .scaleEffect(active ? 1.03 : 0.95)
        }
        .buttonStyle(.plain)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.7),
            value: selectedZoom
        )
    }



    // MARK: - 显示文案
    private func currentOneXValue() -> String {
        if selectedZoom < 2 {
            return format(selectedZoom)
        }
        return "1×"
    }


    private func currentTwoXValue() -> String {
        if selectedZoom >= 2 {
            return format(selectedZoom)
        }
        return "2×"
    }

    private func format(
        _ zoom: CGFloat
    ) -> String {

        Formatters.numberFormatter(
            zoom,
            digits: zoom.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1,
            suffix: "×"
        )
    }
}

public enum Formatters {
    /// 格式化变焦倍数，可指定小数位数和后缀（如 "×"）
    public static func numberFormatter(_ number: CGFloat, digits: Int = 1, suffix: String? = nil) -> String {
        let formatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            return formatter
        }()
        formatter.positiveSuffix = suffix ?? ""
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: number)) ?? ""
    }
}
