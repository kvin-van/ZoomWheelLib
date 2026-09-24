//
//  CropVC.swift
//  Scio
//
//  Created by 冷兔 on 2026/7/17.
//纠正图片方向

import UIKit
import CoreMotion

class DirectionMonitor {
    private let motionManager = CMMotionManager()
    private var timer: Timer?
    
    var onDirectionChanged: ((UIImage.Orientation) -> Void)?
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("设备不支持运动传感器")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.detectDirection()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func detectDirection() {
        guard let motion = motionManager.deviceMotion else { return }
        
        let gravity = motion.gravity
        let x = gravity.x
        let y = gravity.y
        
        // 【关键修正】调整角度计算方式
        // 使用 -atan2(x, y) 而不是 atan2(y, x)
        // 这样当设备竖屏时，角度为0度对应"向上"
        var angle = -atan2(x, y) * 180.0 / .pi
        
        // 归一化到 0-360 度
        if angle < 0 {
            angle += 360.0
        }
        
        let direction = getDirection(from: angle)
//        print("当前方向: \(direction) | 角度: \(String(format: "%.1f", angle))° | 重力: (x: \(String(format: "%.2f", x)), y: \(String(format: "%.2f", y)))")
        onDirectionChanged?(direction)
    }
    
    private func getDirection(from angle: CGFloat) -> UIImage.Orientation {
        switch angle {
        // 手机顶部朝下
        case 0..<45, 315..<360:
            return .down
        // 手机右侧朝上
        case 45..<135:
            return .left
        // 正常竖屏
        case 135..<225:
            return .up
        // 手机左侧朝上
        case 225..<315:
            return .right
        default:
            return .up
        }
    }
}
