//
//  QuestionCropViewModel.swift
//  Scio
//
//  Created by 冷兔 on 2026/7/17.
//

import Foundation
import Combine
import SwiftUI
import Vision

@MainActor
final class QuestionCropViewModel: ObservableObject {

    // MARK: - Public

    /// 原始图片（永远保存）
    let originalImage: UIImage
    let recognizeText: String? //识别文字
    /// 当前显示图片（旋转后）
    @Published var displayImage: UIImage
    /// 当前裁剪框（图片坐标）
    @Published var cropRect: CGRect = .zero
    /// 是否保留整张图片
    @Published var showFullImage = false
    /// Image 在 SwiftUI 中显示区域大小
    @Published var imageViewSize: CGSize = .zero
    /// 是否正在识别
    @Published var isDetecting = false
    /// 当前旋转角度
    @Published private(set) var rotation: Int = 0

    let detector = QuestionDetector()

    init(image: UIImage,text:String?) {
        self.originalImage = image
        self.displayImage = image
        self.recognizeText = text
    }
    
    func cropImage() -> UIImage {
        if showFullImage {
            return displayImage
        }
        return displayImage.crop(rect: cropRect)
    }
}

// MARK: - Detect
extension QuestionCropViewModel {
    // 自动识别题目区域
    func detectQuestion() async {
        guard !isDetecting else {
            return
        }
        isDetecting = true
        defer {
            isDetecting = false
        }
      
            print("没找到😭")
            guard let rect = await detector.detectQuestion(in: displayImage) else { //逻辑2
                // 没识别到，给中心默认框
                cropRect = defaultCenterCropRect()
//                print("defaultCenterCropRect",cropRect)
                showFullImage = false   //这是其实是true 没识别出来也假装识别出来了
                return
            }
            cropRect = rect
        
        
        showFullImage = false
    }
    
    private func defaultCenterCropRect() -> CGRect {
        let imageSize = displayImage.size
        // 默认框占图片宽度 80%
        let width = imageSize.width * 0.7
        // 高度按题目比例
        let height = imageSize.height * 0.35
        let x = (imageSize.width - width) / 2
        let y = (imageSize.height - height) / 2
        return CGRect(x: x,y: y,width: width,height: height)
    }
}

// MARK: - Rotate
extension QuestionCropViewModel {
    func rotate() {
        let oldSize = displayImage.size
        displayImage = displayImage.rotate90()
        rotation += 90
        if rotation >= 360 {
            rotation = 0
        }
        if showFullImage {
            cropRect = CGRect(origin: .zero,size: displayImage.size)
            return
        }
        cropRect = cropRect.rotate90(
            imageSize: oldSize
        )
    }
}

// MARK: - Reset
extension QuestionCropViewModel {
    func resetToWholeImage() {
        showFullImage = true
        cropRect = CGRect(
            origin: .zero,
            size: displayImage.size
        )
    }
}

// MARK: - Update Rect
extension QuestionCropViewModel {
    func updateCropRect(_ rect: CGRect) {
        cropRect = limit(rect)
    }

    private func limit(_ rect: CGRect) -> CGRect {
        var rect = rect

        let size = displayImage.size
        if rect.origin.x < 0 {
            rect.origin.x = 0
        }
        if rect.origin.y < 0 {
            rect.origin.y = 0
        }
        if rect.maxX > size.width {
            rect.origin.x = size.width - rect.width
        }
        if rect.maxY > size.height {
            rect.origin.y = size.height - rect.height
        }
        rect.size.width = max(rect.width, 60)
        rect.size.height = max(rect.height, 60)

        return rect
    }
}

// MARK: - extension UIImage
 extension UIImage {
    // 根据图片坐标裁剪图片
     func crop(rect: CGRect) -> UIImage {
         let image = self.normalized()
         guard let cgImage = image.cgImage else {
             return self
         }
         let scaleX = CGFloat(cgImage.width) / size.width
         let scaleY = CGFloat(cgImage.height) / size.height
         
//         print("imageOrientation:",self.imageOrientation.rawValue)
//         print("image size:", size)
//         print("pixel scale:", scaleX, scaleY)

         let pixelRect = CGRect(
             x: rect.origin.x * scaleX,
             y: rect.origin.y * scaleY,
             width: rect.width * scaleX,
             height: rect.height * scaleY
         ).integral

         print("pixel rect:", pixelRect)

         guard let cropped = cgImage.cropping(
             to: pixelRect
         ) else {
             return self
         }

         return UIImage(cgImage: cropped,scale: 1,orientation: self.imageOrientation)
     }
     
     // 将图片真正旋转到 .up，并移除 orientation 信息
         func normalized() -> UIImage {
             guard imageOrientation != .up else {
                 return self
             }

             let renderer = UIGraphicsImageRenderer(size: size)
             return renderer.image { _ in
                 draw(in: CGRect(origin: .zero, size: size))
             }
         }
     
    func rotate90() -> UIImage {
           let renderer = UIGraphicsImageRenderer(
               size: CGSize(width: size.height, height: size.width)
           )
           return renderer.image { context in
               context.cgContext.translateBy(x: size.height / 2, y: size.width / 2)
               context.cgContext.rotate(by: .pi / 2)

               draw(in: CGRect(
                   x: -size.width / 2,
                   y: -size.height / 2,
                   width: size.width,
                   height: size.height
               ))
           }
       }
    
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}

// MARK: - extension CGRect
extension CGRect {
    func rotate90(imageSize: CGSize) -> CGRect {
          return CGRect(x: imageSize.height - maxY,y: minX,width: height,height: width)
       }
    
    func clamped(to size: CGSize) -> CGRect {
        var rect = self
        rect.origin.x = max(0, rect.origin.x)
        rect.origin.y = max(0, rect.origin.y)

        if rect.maxX > size.width {
            rect.size.width = size.width - rect.origin.x
        }
        if rect.maxY > size.height {
            rect.size.height = size.height - rect.origin.y
        }

        return rect
    }
}
