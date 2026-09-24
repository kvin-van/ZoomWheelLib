//
//  EXView.swift
//  MCCodeScanner
//
//  Created by apple on 2026/6/29.
//

import Foundation
import SwiftUI
struct RoundedCorners: Shape {
    var radius: CGFloat = 10
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension UIImage {

    /// 压缩到指定 KB 以内（先缩尺寸，再降质量）
    /// - Parameter maxSize: 目标大小，单位 KB
    /// - Returns: 压缩后的 JPEG Data
    func imageToMaxSize(maxSize: Int) -> Data? {
        let maxBytes = maxSize * 1024

        // ── Step 1: 缩小尺寸 ──────────────────────────────
        // 如果图片最长边超过这个阈值，就先按比例缩小
        let maxDimension: CGFloat = 2048
        let resized: UIImage = {
            let longestSide = max(size.width, size.height)
            guard longestSide > maxDimension else { return self }

            let scale = maxDimension / longestSide
            let newWidth = size.width * scale
            let newHeight = size.height * scale

            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: newWidth, height: newHeight)
            )
            return renderer.image { _ in
                self.draw(in: CGRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight)))
            }
        }()

        // ── Step 2: 质量压缩 ──────────────────────────────
        var quality: CGFloat = 0.9
        let step: CGFloat = 0.1

        guard var data = resized.jpegData(compressionQuality: quality) else {
            return nil
        }

        // 如果缩小尺寸后已经满足，直接返回
        if data.count <= maxBytes {
            return data
        }

        // 否则逐步降质量
        while data.count > maxBytes && quality > step {
            quality -= step
            guard let newData = resized.jpegData(compressionQuality: quality) else { break }
            data = newData
        }

        // ── Step 3: 如果降质量还不够，进一步缩小尺寸再试 ──
        if data.count > maxBytes {
            let furtherScale: CGFloat = 0.5
            let smallerSize = CGSize(
                width: resized.size.width * furtherScale,
                height: resized.size.height * furtherScale
            )
            let renderer = UIGraphicsImageRenderer(size: smallerSize)
            let smaller = renderer.image { _ in
                resized.draw(in: CGRect(origin: .zero, size: smallerSize))
            }
            if let smallerData = smaller.jpegData(compressionQuality: quality) {
                data = smallerData
            }
        }

        return data
    }
}

extension View {
    /// iOS 18+ 标记 zoom 转场的源视图，低版本无效果
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// iOS 18+ 应用 zoom 转场，低版本保持默认（底部弹出）
    @ViewBuilder
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
