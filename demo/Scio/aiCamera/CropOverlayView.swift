//
//  CropOverlayView.swift
//  Scio
//
//  Created by 冷兔 on 2026/7/17.
//

import Foundation
import SwiftUI

struct CropOverlayView: View {

    enum Corner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let imageSize: CGSize

    @Binding var cropRect: CGRect
    @Binding var showFullImage: Bool
    @State private var dragStartRect: CGRect = .zero
    @State private var resizeStartRect: CGRect = .zero
    @State var showTipView: Bool = true
    
    private let minSize: CGFloat = 50
    private let handleSize: CGFloat = 44 //白色角把手显示多大，不变
    private let cornerHitSize: CGFloat = 70 //手指可以触摸多大的区域
    private let edgeHandleLong: CGFloat = 30
    //边缘手柄
    private let edgeHitLong: CGFloat = 60
    private let edgeHitThickness: CGFloat = 30
    
    var body: some View {
        GeometryReader { geo in
            let scale = min(
                geo.size.width / imageSize.width,
                geo.size.height / imageSize.height
            )

            let displayWidth = imageSize.width * scale
            let displayHeight = imageSize.height * scale

            let offsetX = (geo.size.width - displayWidth) / 2
            let offsetY = (geo.size.height - displayHeight) / 2

            let rect = CGRect(
                x: cropRect.minX * scale + offsetX,
                y: cropRect.minY * scale + offsetY,
                width: cropRect.width * scale,
                height: cropRect.height * scale
            )

            ZStack {
                Path { path in //镂空的矩形遮罩效果
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRoundedRect(
                        in: rect,
                        cornerSize: CGSize(width: 1, height: 1)
                    )
                }
                .fill(
                    Color.black.opacity(0.3),
                    style: FillStyle(eoFill: true) // 填充规则
                )
                cornerHandle(.topLeft, rect: rect, scale: scale)
                cornerHandle(.topRight, rect: rect, scale: scale)
                cornerHandle(.bottomLeft, rect: rect, scale: scale)
                cornerHandle(.bottomRight, rect: rect, scale: scale)
                if rect.width >= edgeHandleLong {
                    edgeHandle(.top, rect: rect, scale: scale)
                    edgeHandle(.bottom, rect: rect, scale: scale)
                }
                if rect.height >= edgeHandleLong {
                    edgeHandle(.leading, rect: rect, scale: scale)
                    edgeHandle(.trailing, rect: rect, scale: scale)
                }
                
                if showTipView == true{
                    tipTopView
                        .position(x: rect.midX,y: rect.minY - 40)
                    // 下方提示
                    tipDownView
                        .position(x: rect.midX,y: rect.maxY + 28)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        showTipView = false
                        
                        if dragStartRect == .zero {
                            dragStartRect = cropRect
                        }

                        let dx = value.translation.width / scale
                        let dy = value.translation.height / scale

                        cropRect.origin.x = dragStartRect.origin.x + dx
                        cropRect.origin.y = dragStartRect.origin.y + dy

                        cropRect.origin.x = max(0,
                            min(cropRect.origin.x,imageSize.width - cropRect.width)
                        )

                        cropRect.origin.y = max(0,
                            min(cropRect.origin.y,imageSize.height - cropRect.height)
                        )
                    }
                    .onEnded { _ in
                        dragStartRect = .zero
                    }
            )
        }
    }
    
    // MARK: - Tip
        var tipTopView: some View {
                Text("Adjust the frame to include the full question, choices, and instructions")
                    .font(.system(size: 14))
                    .lineLimit(2)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(width: 280,height: 38)
        }
        var tipDownView: some View {
                Text("Crop only one question at a time")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 240,height: 26)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
        }
    
    // MARK: - 角把手
    @ViewBuilder
    private func cornerHandle(_ corner: Corner, rect: CGRect, scale: CGFloat) -> some View {
        ZStack {
            // 实际显示的角把手
            RoundedCornerShape(corner: corner)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: handleSize, height: handleSize)

            // 扩大的点击区域，不影响显示
            Color.clear
                .frame(width: cornerHitSize, height: cornerHitSize)
        }
        .contentShape(Rectangle())
        .position(position(of: corner, rect: rect))
        .gesture(
            DragGesture()
                .onChanged { value in
                    showTipView = false

                    if resizeStartRect == .zero {
                        resizeStartRect = cropRect
                    }

                    resize(
                        corner,
                        translation: value.translation,
                        scale: scale
                    )
                }
                .onEnded { _ in
                    resizeStartRect = .zero
                }
        )
    }
    private func position(of corner: Corner,rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(
                x: rect.minX + (handleSize/2),
                y: rect.minY + (handleSize/2))
        case .topRight:
            return CGPoint(
                x: rect.maxX - (handleSize/2),
                y: rect.minY + (handleSize/2))
        case .bottomLeft:
            return CGPoint(
                x: rect.minX + (handleSize/2),
                y: rect.maxY - (handleSize/2))
        case .bottomRight:
            return CGPoint(
                x: rect.maxX - (handleSize/2),
                y: rect.maxY - (handleSize/2))
        }
    }
    private func resize(_ corner: Corner,translation: CGSize,scale: CGFloat) {

        var rect = resizeStartRect
        let dx = translation.width / scale
        let dy = translation.height / scale

        switch corner {

        case .topLeft:
            rect.origin.x += dx
            rect.origin.y += dy
            rect.size.width -= dx
            rect.size.height -= dy

        case .topRight:
            rect.origin.y += dy

            rect.size.width += dx
            rect.size.height -= dy

        case .bottomLeft:
            rect.origin.x += dx
            rect.size.width -= dx
            rect.size.height += dy

        case .bottomRight:
            rect.size.width += dx
            rect.size.height += dy
        }

        rect.size.width = max(minSize, rect.width)
        rect.size.height = max(minSize, rect.height)

        if rect.minX < 0 {
            rect.origin.x = 0
        }

        if rect.minY < 0 {
            rect.origin.y = 0
        }

        if rect.maxX > imageSize.width {
            rect.size.width = imageSize.width - rect.minX
        }

        if rect.maxY > imageSize.height {
            rect.size.height = imageSize.height - rect.minY
        }

        cropRect = rect
    }
    
    // MARK: - 边缘手柄
    @ViewBuilder
    private func edgeHandle(_ edge: Edge, rect: CGRect, scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(
                    width: edge == .top || edge == .bottom ? edgeHandleLong : 4,
                    height: edge == .leading || edge == .trailing ? edgeHandleLong : 4
                )
            Color.clear
                .frame(
                    width: edge == .top || edge == .bottom ? edgeHitLong : edgeHitThickness,
                    height: edge == .leading || edge == .trailing ? edgeHitLong : edgeHitThickness
                )
        }
        .contentShape(Rectangle())
        .position(edgePosition(edge, rect: rect))
        .gesture(
            DragGesture()
                .onChanged { value in
                    showTipView = false
                    if resizeStartRect == .zero {
                        resizeStartRect = cropRect
                    }
                    resizeEdge(edge, translation: value.translation, scale: scale)
                }
                .onEnded { _ in
                    resizeStartRect = .zero
                }
        )
    }
    private func edgePosition( _ edge: Edge,rect: CGRect) -> CGPoint {
        switch edge {
        case .leading:
            return CGPoint(
                x: rect.minX,
                y: rect.midY
            )
        case .trailing:
            return CGPoint(
                x: rect.maxX,
                y: rect.midY
            )
        case .top:
            return CGPoint(
                x: rect.midX,
                y: rect.minY
            )
        case .bottom:
            return CGPoint(
                x: rect.midX,
                y: rect.maxY
            )
        }
    }
    private func resizeEdge(_ edge: Edge,translation: CGSize,scale: CGFloat) {
        var rect = resizeStartRect
        let dx = translation.width / scale
        let dy = translation.height / scale

        switch edge {
        // 左边拖动
        case .leading:
            rect.origin.x += dx
            rect.size.width -= dx

        // 右边拖动
        case .trailing:
            rect.size.width += dx

        // 上边拖动
        case .top:
            rect.origin.y += dy
            rect.size.height -= dy

        // 下边拖动
        case .bottom:
            rect.size.height += dy
        }
        // 最小尺寸
        rect.size.width = max(minSize, rect.width)
        rect.size.height = max(minSize, rect.height)

        // 边界限制
        if rect.minX < 0 {
            rect.origin.x = 0
            rect.size.width = resizeStartRect.maxX
        }

        if rect.minY < 0 {
            rect.origin.y = 0
            rect.size.height = resizeStartRect.maxY
        }

        if rect.maxX > imageSize.width {
            rect.size.width = imageSize.width - rect.minX
        }

        if rect.maxY > imageSize.height {
            rect.size.height = imageSize.height - rect.minY
        }

        cropRect = rect
    }
}

struct RoundedCornerShape: Shape {
    let corner: CropOverlayView.Corner
    var lineLength: CGFloat = 18
    var cornerRadius: CGFloat = 6
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = cornerRadius
        let len = lineLength
        
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: len, y: 0))
            path.addLine(to: CGPoint(x: r, y: 0))
            //Path.addArc(...) 默认会自动从当前点连接到圆弧起点（如果当前点不在圆弧起点），因此就会多出这一条线
            //修复： startAngle endAngle 先后顺序 然后直接画线 不用移动点位
            path.addArc(
                center: CGPoint(x: r, y: r),
                radius: r,
                startAngle: .degrees(270),
                endAngle: .degrees(180),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: 0, y: len))
            
        case .topRight:
            path.move(to: CGPoint(x: w - len, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addArc(
                center: CGPoint(x: w - r, y: r),
                radius: r,
                startAngle: .degrees(270),
                endAngle: .degrees(360),
                clockwise: false
            )
            path.move(to: CGPoint(x: w, y: r))
            path.addLine(to: CGPoint(x: w, y: len))
            
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: h - len))
            path.addLine(to: CGPoint(x: 0, y: h - r))

            path.addArc(
                center: CGPoint(x: r, y: h - r),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: len, y: h))
            
        case .bottomRight:
            path.move(to: CGPoint(x: w, y: h - len))
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addArc(
                center: CGPoint(x: w - r, y: h - r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.move(to: CGPoint(x: w - r, y: h))
            path.addLine(to: CGPoint(x: w - len, y: h))
        }
        return path
    }
}
