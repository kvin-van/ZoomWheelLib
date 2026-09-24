//
//  ExImage.swift
//  Scio
//
//  Created by 冷兔 on 2026/8/10.
//

import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

extension UIImage {
    //按比例裁剪
    func croppedToAspectRatio(_ aspectRatio: CGFloat) -> UIImage {
        guard let cgImage = cgImage else { return self }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let imageRatio = width / height

        var cropRect: CGRect

        if imageRatio > aspectRatio {
            // 图片太宽，裁左右
            let cropWidth = height * aspectRatio
            cropRect = CGRect(
                x: (width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: height
            )
        } else {
            // 图片太高，裁上下
            let cropHeight = width / aspectRatio
            cropRect = CGRect(
                x: 0,
                y: (height - cropHeight) / 2,
                width: width,
                height: cropHeight
            )
        }

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return self
        }

        return UIImage(cgImage: croppedCGImage,scale: scale,orientation: self.imageOrientation)
    }
    
    // 等比缩放，使长边不超过 maxDimension；已满足时原样返回
    func scaledDowns(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let longer = max(size.width, size.height)
        guard longer > maxDimension else { return self }

        let scales = maxDimension / longer
        let newSize = CGSize(width: (size.width  * scales).rounded(),
                             height: (size.height * scales).rounded())

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    //清晰度 评分
    func blurScore() -> Double {
        guard let cgImage else { return 0 }

        let maxSize: CGFloat = 1000 //尺寸固定
        let scale = min(1,maxSize / CGFloat(max(cgImage.width, cgImage.height)))
        let width = max(1, Int(CGFloat(cgImage.width) * scale))
        let height = max(1, Int(CGFloat(cgImage.height) * scale))
        let ciImage = CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(
                scaleX: CGFloat(width) / CGFloat(cgImage.width),
                y: CGFloat(height) / CGFloat(cgImage.height)
            ))
        let context = CIContext()
        let filter = CIFilter.convolution3X3()
        filter.inputImage = ciImage
        filter.weights = CIVector(values: [
            0, -1, 0,
            -1, 4, -1,
            0, -1, 0
        ], count: 9)

        guard let output = filter.outputImage,
              let result = context.createCGImage(
                output,
                from: output.extent
              ) else {
            return 0
        }

        guard let data = result.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0
        }

        let bytesPerPixel = result.bitsPerPixel / 8
        let rowBytes = result.bytesPerRow

        var sum = 0.0
        var sum2 = 0.0
        var count = 0.0

        let step = 2

        for y in stride(from: 1, to: result.height - 1, by: step) {
            for x in stride(from: 1, to: result.width - 1, by: step) {
                let offset = y * rowBytes + x * bytesPerPixel

                let value = Double(bytes[offset])

                sum += value
                sum2 += value * value
                count += 1
            }
        }

        guard count > 0 else { return 0 }

        let mean = sum / count
        let variance = max(0, sum2 / count - mean * mean)

        return variance
    }
}
