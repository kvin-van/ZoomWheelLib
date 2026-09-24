//
//  QuestionDetector.swift
//  Scio
//
//  Created by 冷兔 on 2026/7/17.
//问题检测器

import Foundation
import UIKit
@preconcurrency import Vision

final class QuestionDetector {

    /// 检测题目区域
    /// 返回UIImage坐标系(Rect)，不是Vision坐标
    func detectQuestion(in image: UIImage) async -> CGRect? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // 过滤掉特别小的噪点
                let filtered = observations.filter {
                    let rect = $0.boundingBox
                    return rect.width > 0.05 &&
                           rect.height > 0.02
                }
                guard !filtered.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                //靠近中心 文字面积 + 距离图片中心 + 文本密度
                let imageCenter = CGPoint(x: image.size.width / 2,y: image.size.height / 2)
                guard let anchor = filtered.max(by: { a, b in
                    let rectA = Self.convertVisionRect(
                        a.boundingBox,
                        imageSize: image.size
                    )
                    
                    let rectB = Self.convertVisionRect(
                        b.boundingBox,
                        imageSize: image.size
                    )
                    
                    let scoreA = Self.textScore(
                        rect: rectA,
                        imageCenter: imageCenter,
                        imageSize: image.size
                    )
                    
                    let scoreB = Self.textScore(
                        rect: rectB,
                        imageCenter: imageCenter,
                        imageSize: image.size
                    )
                    return scoreA < scoreB
                }) else {
                    continuation.resume(returning: nil)
                    return
                }

                var unionRect = anchor.boundingBox
                let anchorRect = anchor.boundingBox

                for item in filtered {
                    if item == anchor { continue }
                    let rect = item.boundingBox
                    // 水平方向是否接近
                    let horizontalOverlap =
                        min(anchorRect.maxX, rect.maxX) -
                        max(anchorRect.minX, rect.minX)
                    // 垂直距离
                    let verticalGap: CGFloat
                    if rect.minY > anchorRect.maxY {
                        verticalGap = rect.minY - anchorRect.maxY
                    } else if anchorRect.minY > rect.maxY {
                        verticalGap = anchorRect.minY - rect.maxY
                    } else {
                        verticalGap = 0
                    }
                    // 与题干左右对齐，并且距离不要太远
                    if horizontalOverlap > anchorRect.width * 0.4 &&
                        verticalGap < 0.25 {
                        unionRect = unionRect.union(rect)
                    }
                }

                let imageRect = Self.convertVisionRect(
                    unionRect,
                    imageSize: image.size
                )

                // 仅保留少量边距
                var result = imageRect.insetBy(
                    dx: -8,
                    dy: -8
                )
                result = result.clamped(to: image.size)
                // 最小尺寸限制
                let minWidth = image.size.width * 0.2
                let minHeight = image.size.height * 0.05
                if result.width < minWidth || result.height < minHeight {
                    continuation.resume(returning: nil)
                    return
                }
                
                let sixHeight = image.size.height * 0.166
                if image.size.height > image.size.width && result.size.height > sixHeight{ //竖拍 禁止过大
                    print("detectQuestion:",image.size,"=",result)
                    let moreSize = result.size.height - sixHeight
                    result = CGRect(x: result.origin.x, y: result.origin.y+(moreSize/2), width: result.size.width, height: sixHeight)
                    print("=",result)
                }
                
                continuation.resume(
                    returning: result
                )
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeight = 0.02 //设置最小文字高度：过滤掉高度小于图像高度 2% 的微小噪点
            //这里图片方向可能不是 .up
            let handler = VNImageRequestHandler(cgImage: cgImage,orientation: image.cgImageOrientation)

            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
    
    static func textScore(rect: CGRect,imageCenter: CGPoint,imageSize: CGSize) -> CGFloat {
        let rectCenter = CGPoint(x: rect.midX,y: rect.midY)

        // 当前文字框距离图片中心
        let distance = hypot(
            rectCenter.x - imageCenter.x,
            rectCenter.y - imageCenter.y
        )
        // 最大可能距离（图片对角线）
        let maxDistance = hypot(
            imageSize.width,
            imageSize.height
        )
        // 越靠近中心越接近1
        let centerScore = 1 - min(distance / maxDistance, 1)
        // 面积比例
        let areaScore =
            (rect.width * rect.height) /
            (imageSize.width * imageSize.height)
        return centerScore * 0.7 + areaScore * 0.3
    }
    
    // 识别图片中的全部文字
    func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            return ""
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil else {
                        continuation.resume(returning: "")
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation],
                          !observations.isEmpty else {
                        continuation.resume(returning: "")
                        return
                    }

                    let text = observations
                        .compactMap {
                            $0.topCandidates(1).first?.string
                        }
                        .joined(separator: "\n")

                    continuation.resume(returning: text)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: image.cgImageOrientation
                )

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
    func recognizeText2(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            return ""
        }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: "")
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: "")
                    return
                }
                // Vision 默认返回顺序通常就是从上到下
                let text = observations
                    .compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage,orientation: image.cgImageOrientation)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}

//Vision坐标转换
 extension QuestionDetector {

    static func convertVisionRect(_ rect: CGRect,imageSize: CGSize) -> CGRect {
        let x = rect.origin.x * imageSize.width
        let width = rect.width * imageSize.width
        let height = rect.height * imageSize.height
        let y = (1 - rect.origin.y - rect.height) * imageSize.height

        return CGRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
    }
}
