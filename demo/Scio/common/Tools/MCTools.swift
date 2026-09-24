//
//  MCTools.swift
//  MCCodeScanner
//
//  Created by 冷兔 on 2026/7/3.
//

import Foundation
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers


class MCTools {
    public static let shared = MCTools()

    // MARK: - 日期
    /// 获取当前时间戳字符串（毫秒级）
    static func currentTimestamp() -> String {
        let timestamp = Date().timeIntervalSince1970 * 1000
        return String(Int64(timestamp))
    }

    // MARK: - 图片压缩
    static func compressDiagnosticImage(_ image: UIImage) -> Data? { //比较耗时暂时舍弃
        let targetBytes = 1_000_000   // 1m

        // 档位从 320 往下，极限到 24px
        // JPEG 固定开销约 400 字节，32px 以下才有把握稳定进 1KB
        let maxDimensions: [CGFloat] = [640, 320, 160, 80, 48, 32, 24]

        for maxDim in maxDimensions {
            let scaled = image.scaledDowns(toMaxDimension: maxDim)

            // quality=0 仍超限 → 换更小档位
            guard let floorData = scaled.jpegData(compressionQuality: 0),
                  floorData.count <= targetBytes else {
                let floorKB = scaled.jpegData(compressionQuality: 0).map {
                    String(format: "%.2f", Double($0.count) / 1000)
                } ?? "?"
                print("[Diagnostic] \(Int(maxDim))px quality=0 = \(floorKB) KB, too large → try smaller")
                continue
            }

            // 二分搜索：找当前档位下最高可用 quality
            var lo: CGFloat = 0.0
            var hi: CGFloat = 0.8
            var bestData: Data = floorData

            for _ in 0..<12 {              // 12次二分，精度 ≈ 0.0002
                let mid = (lo + hi) / 2
                guard let candidate = scaled.jpegData(compressionQuality: mid) else { break }
                if candidate.count <= targetBytes {
                    bestData = candidate
                    lo = mid
                } else {
                    hi = mid
                }
            }

            let finalKB  = String(format: "%.2f", Double(bestData.count) / 1000)
            let qualityStr = String(format: "%.3f", lo)
            print("[Diagnostic] ✅ \(Int(scaled.size.width))×\(Int(scaled.size.height))  quality=\(qualityStr)  \(finalKB) KB")
            return bestData
        }

        // 绝对兜底（正常不会到这里）
        print("[Diagnostic] ⚠️ fallback to 24px quality=0")
        return image.scaledDowns(toMaxDimension: 24).jpegData(compressionQuality: 0)
    }
    
    //读取img小大
    static func imageSizeMB(image: UIImage) -> Int {
        // 1. 获取图片数据
        let data = image.pngData()!
        // 2. 将数据转换为 Data 对象
        let imageData = Data(data)
        // 3. 获取字节数
        let byteCount = imageData.count
        // 4. 将字节数转换为兆字节数
        let megabyteCount = byteCount / 1024 / 1024

        return megabyteCount
    }
    
    static func compressDataWithoutUIImage(data: Data, quality: Float = 0.5) -> Data? {
        // 1. 从 Data 创建图像源
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        // 2. 设置压缩参数（只改质量，不改尺寸）
        let options: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: quality
        ]
        // 3. 创建可变 Data 作为输出容器
        let outputData = NSMutableData()
        // 输出为 JPEG
        guard let destination = CGImageDestinationCreateWithData(outputData,
            UTType.jpeg.identifier as CFString,1,nil) else {return nil}
        
        // 4. 添加图像并压缩
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return outputData as Data
    }
    
    //压缩图片
    static func imageCompress(_ image:UIImage) -> UIImage{
        let imageSize = MCTools.imageSize(image, true)
        let reImage = MCTools.scaleToSize(image, imageSize)
        let data = reImage.jpegData(compressionQuality: 0.8)
        let images = UIImage(data: data!)!
        return UIImage(cgImage: images.cgImage!,scale: 1,orientation: images.imageOrientation)
    }
    
    //裁图
    static func scaleToSize(_ image:UIImage,_ size:CGSize) -> UIImage{
        //第一个参数表示区域大小。第二个参数表示是否是非透明的。如果需要显示半透明效果,需要传NO,否则传YES。第三个参数就是屏幕密度了
        UIGraphicsBeginImageContext(size)
        var newImage = UIImage(cgImage: image.cgImage!,scale: 1,orientation: image.imageOrientation)
        newImage.draw(in: CGRectMake(0, 0, size.width, size.height))
        newImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    //获取压缩尺寸
    static func imageSize(_ image:UIImage,_ isSession:Bool) -> CGSize{
        var width = image.size.width;
        var height = image.size.height;
        var boundary:CGFloat = 1280
        
        // width, height <= 1280, Size remains the same
        if (width < boundary && height < boundary) {
            return CGSizeMake(width, height)
        }
        
        // aspect ratio
        let ratio:CGFloat = max(width, height) / min(width, height);
        if (ratio <= 2) {
            let x:CGFloat = max(width, height) / boundary;
            if (width > height) {
                width = boundary
                height = height / x
            } else {
                height = boundary
                width = width / x
            }
        } else {
            // width, height > 1280
            if (min(width, height) >= boundary) {
                boundary = isSession ? 800:1280;
                // Set the smaller value to the boundary, and the larger value is compressed
                let x:CGFloat = min(width, height) / boundary;
                if (width < height) {
                    width = boundary;
                    height = height / x;
                } else {
                    height = boundary;
                    width = width / x;
                }
            }
        }
        return CGSizeMake(width, height);
    }
    
    // MARK: - 图片存储

    /// CropImages 文件夹路径（实时获取，避免沙箱 UUID 变化导致路径失效）
    static var cropImagesFolder: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取Documents目录")
            return nil
        }
        return documentsDirectory.appendingPathComponent("CropImages")
    }

    /// 根据文件名解析出当前沙箱下的完整 URL
    static func url(forImageName name: String) -> URL? {
        cropImagesFolder?.appendingPathComponent(name)
    }

    /// 保存图片到 CropImages
    /// - Parameters:
    ///   - image: 要保存的图片
    ///   - uuid: 可选的图片唯一标识。
    ///          传入后使用 "\(uuid).png" 作为文件名。
    ///          如果文件已存在则覆盖，不存在则创建。
    /// - Returns: (图片名称, 完整URL路径)，失败返回 nil
    static func saveImage(_ image: UIImage,_ uuid: String? = nil) -> (name: String, url: URL)? {
        // 1. 获取 Documents/CropImages
        guard let folderURL = cropImagesFolder else {
            print("无法获取Documents目录")
            return nil
        }

        // 2. 创建文件夹
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: folderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("创建文件夹失败: \(error.localizedDescription)")
                return nil
            }
        }

        // 3. 根据 uuid 决定文件名
        let fileName: String

        if let uuid = uuid, !uuid.isEmpty {
            fileName = "\(uuid).png"
        } else {
            let timestamp = MCTools.currentTimestamp()
            let randomSuffix = Int.random(in: 1000...9999)
            fileName = "\(timestamp)_\(randomSuffix).png"
        }

        let fileURL = folderURL.appendingPathComponent(fileName)

        // 4. 转换 PNG
        guard let imageData = image.pngData() else {
            print("图片转换为PNG数据失败")
            return nil
        }

        // 5. 写入文件
        // Data.write 默认会覆盖同名文件，所以 uuid 存在时会自动替换
        do {
            try imageData.write(to: fileURL, options: .atomic)
            print("图片保存成功: \(fileURL.path)")
            return (fileName, fileURL)
        } catch {
            print("保存图片失败: \(error.localizedDescription)")
            return nil
        }
    }
    /// 从沙盒加载图片（通过完整URL）
    /// - Parameter url: 图片的完整URL
    /// - Returns: UIImage?，失败返回nil
    static func loadImage(from url: URL) -> UIImage? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("加载图片文件不存在: \(url.path)")
            return nil
        }
        guard let image = UIImage(contentsOfFile: url.path) else {
            print("加载图片失败: \(url.path)")
            return nil
        }
        return image
    }

    /// 从沙盒加载图片（通过文件名，实时拼 Documents/CropImages 路径，避免沙箱 UUID 变化）
    /// - Parameter name: 图片文件名（如 "1784541426.2880158_6853.png"）
    /// - Returns: UIImage?，失败返回nil
    static func loadImage(fromName name: String) -> UIImage? {
        guard let url = url(forImageName: name) else { return nil }
        return loadImage(from: url)
    }
    
    /// 删除沙盒中的图片（通过URL）
    /// - Parameter url: 图片的完整URL
    /// - Returns: Bool，是否删除成功
    static func deleteImage(at name: String) -> Bool {
        guard let url = url(forImageName: name) else { return false }
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("删除文件不存在: \(url.path)")
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            print("删除图片成功: \(url.path)")
            return true
        } catch {
            print("删除图片失败: \(error.localizedDescription)")
            return false
        }
    }
    static func dateToPStr(_ date: Date) -> String {
        let formatter = DateFormatter()
           formatter.locale = Locale.current
           formatter.dateStyle = .medium
           formatter.timeStyle = .none
           return formatter.string(from: date)
    }
    
}
