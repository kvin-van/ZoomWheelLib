//
//  CameraManager.swift
//  Scio
//
//  Created by 冷兔 on 2026/7/16.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

final class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?
    private var systemPreferredCamera : AVCaptureDevice?
    private var directionMonitor: DirectionMonitor?
    private var imgOrientation: UIImage.Orientation = .up
    
    @Published var previewAspectSize: CGSize = .zero //为了裁剪
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var torchOn = false //手电筒打开
    @Published var currentZoom: CGFloat = 1 //焦距
    /// 模拟器没有可用相机（部分环境下 startRunning 会直接抛 NSException），
    /// 真机不受影响。
    private static var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    override init() {
        super.init()
        checkPermission()
    }

    deinit {
          stop()
       }

    func start() {
           guard Self.isCameraAvailable else {
               return
           }
           guard !captureSession.isRunning else {
               return
           }

           DispatchQueue.global(qos: .userInitiated).async {
               self.captureSession.startRunning()
           }
        DispatchQueue.main.async {
            self.directionMonitor = DirectionMonitor()
            self.directionMonitor?.onDirectionChanged = { direction in
                // 在这里处理方向变化，比如更新UI
//                print("方向变化: \(direction)")
                self.imgOrientation = direction
            }
            // 开始监听
            self.directionMonitor?.startMonitoring()
           }
       }
    
    func stop() {
           guard captureSession.isRunning else {
               return
           }

           DispatchQueue.global(qos: .userInitiated).async {
               self.captureSession.stopRunning()
           }
        DispatchQueue.main.async {
               self.directionMonitor?.stopMonitoring()
               self.directionMonitor = nil
           }
       }
    
    public func toggleFlash() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        
        try? device.lockForConfiguration()
        if device.torchMode == .on {
            device.torchMode = .off
            flashMode = .off
        } else {
            try? device.setTorchModeOn(level: 1.0)
            flashMode = .on
        }
        device.unlockForConfiguration()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setup()
                    }
                }
            }
        default:
            break
        }
    }

    func setup() {
        guard captureSession.inputs.isEmpty else { return }
        captureSession.beginConfiguration()

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video,position: .back),
            let input = try? AVCaptureDeviceInput(device: camera)
        else {
            return
        }
        systemPreferredCamera = camera
        
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()
        start()
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        guard Self.isCameraAvailable else {
            completion(nil)
            return
        }

        self.completion = completion
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
               settings.flashMode = flashMode
           }
        if #available(iOS 18.0, *) { // 静音拍摄
            settings.isShutterSoundSuppressionEnabled = true
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,didFinishProcessingPhoto photo: AVCapturePhoto,error: Error?) {
        guard let originalData = photo.fileDataRepresentation()else {
            return
        }
        stop()
//        print(MCTools.imageSizeMB(image: UIImage(data: originalData)!))
        DispatchQueue.global(qos: .userInitiated).async {
            if let imageData = MCTools.compressDataWithoutUIImage(data: originalData, quality: 0.3),var resultImage = UIImage(data: imageData){
//                            print(MCTools.imageSizeMB(image: resultImage))
                if self.imgOrientation == .left{
                        if let cgImage = resultImage.cgImage {
                            resultImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                            }
                        }
                else if self.imgOrientation == .right{
                            if let cgImage = resultImage.cgImage {
                                resultImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .down)
                            }
                        }
                        else{
                        }
                
                        // 裁剪成和预览区域一样的比例
                resultImage = resultImage.croppedToAspectRatio(self.previewAspectSize.height/self.previewAspectSize.width)
                self.completion?(resultImage)
//                self.completion?(UIImage(named: "guide_31"))
            }
        }
    }
}

extension CameraManager {

    func toggleTorch() {
        guard let device = systemPreferredCamera else { return }
        guard device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                torchOn = false
            } else {
                try device.setTorchModeOn(level: 1)
                torchOn = true
            }
            device.unlockForConfiguration()

        } catch {

        }
    }
}

extension CameraManager { //焦距
    func setZoomValue(_ zoom: CGFloat) {
        // MARK: - 切换镜头
        if zoom < 1 {
            if systemPreferredCamera?.deviceType != .builtInUltraWideCamera {
                if AVCaptureDevice.default(.builtInUltraWideCamera,for: .video,position: .back) != nil {
                    switchCamera(to: .builtInUltraWideCamera)
                }
            }
        } else {
            if systemPreferredCamera?.deviceType != .builtInWideAngleCamera {
                switchCamera(to: .builtInWideAngleCamera)
            }
        }
        // MARK: - 重新获取最新 Camera
        guard let device = systemPreferredCamera else {
            return
        }
        do {
            try device.lockForConfiguration()
            var finalZoom = zoom
            // 超广角倍率修正
            if device.deviceType == .builtInUltraWideCamera {
                finalZoom = zoom * 2
            }
            finalZoom = min(max(finalZoom, device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            // 注意这里不要用 ramp
            device.videoZoomFactor = finalZoom
            DispatchQueue.main.async {
                self.currentZoom = zoom
            }
            device.unlockForConfiguration()
        } catch {
            print("变焦相机错误:", error)
        }
    }

    private func switchCamera(to type: AVCaptureDevice.DeviceType) {
        guard let newCamera = AVCaptureDevice.default(
            type,
            for: .video,
            position: .back
        ),
        let newInput = try? AVCaptureDeviceInput(device: newCamera)
        else {
            return
        }
        captureSession.beginConfiguration()
        if let oldInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(oldInput)
        }
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            systemPreferredCamera = newCamera
        }
        captureSession.commitConfiguration()
    }

    //    func setZoomValue(_ zoom: CGFloat) {
    //        guard let device = systemPreferredCamera else { return }
    //        guard zoom >= device.minAvailableVideoZoomFactor else { return }
    //        guard zoom <= device.maxAvailableVideoZoomFactor else { return }
    //
    //        do {
    //            try device.lockForConfiguration()
    //            device.ramp(toVideoZoomFactor: zoom, withRate: 4)
    //            currentZoom = zoom
    //            device.unlockForConfiguration()
    //        } catch {
    //            print("变焦相机错误: \(error)")
    //        }
    //    }
    
    func pinchZoom(scale: CGFloat) {
        let zoom = currentZoom * scale
        setZoomValue(zoom)
    }
}
