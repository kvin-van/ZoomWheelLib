//
//  CameraViewVC.swift
//  Scio
//

import Foundation
import SwiftUI
import PhotosUI

struct CameraViewVC: View {
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()
    @State private var scale: CGFloat = 1
    

    let customSteps: [ZoomStep] = [
        ZoomStep(zoom: 0.5, focalLength: "13mm", type: .focalLength),
        ZoomStep(zoom: 1.0, focalLength: "26mm", type: .focalLength),
        ZoomStep(zoom: 2.0, focalLength: "52mm", type: .value),
        ZoomStep(zoom: 5.0, type: .value)
    ]

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                CameraPreview(session: camera.captureSession)
                    .ignoresSafeArea()
                    .onChange(of: proxy.size) { _, newSize in
                            camera.previewAspectSize = newSize
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / scale
                                scale = value
                                camera.pinchZoom(scale: delta)
                            }
                            .onEnded { _ in
                                scale = 1
                            }
                    )
            }
            overlay
                .padding(.bottom, 24)
        }
        .onAppear{
            DispatchQueue.main.asyncAfter(deadline: .now()+0.4) { //延时
                camera.start()
            }
        }
    }

    func pushImgAction(_ image: UIImage) {
        var passImg = image
        DispatchQueue.global(qos: .userInitiated).async {
            if MCTools.imageSizeMB(image: image) > 2 {
                passImg = MCTools.imageCompress(image)
            }
            DispatchQueue.main.async {
                router.push(.cropVC(image: passImg, recognizeText: nil))
                DispatchQueue.main.asyncAfter(deadline: .now()+0.4) { //延时 //为了结果页面返回 不停留上次拍照结果。
                    camera.start()
                }
            }
        }
    }

    private var overlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                       Text("Take a picture of a question")
                           .font(.system(size: 16, weight: .medium))
                           .foregroundStyle(.white)
                           .shadow(radius: 2)
                       PlusView(size: 24, lineWidth: 5)
                   }
            Spacer()
            ZoomControl(zoomLevel: $camera.currentZoom, steps: customSteps)
                .onChange(of: camera.currentZoom) { _, newValue in
                    camera.setZoomValue(camera.currentZoom)
                }
            bottomButtons
        }


    }


    // MARK: - 底部
    private var bottomButtons: some View {
        HStack {
            Spacer()
            Spacer()
            PulsingButton(camera: camera) { img in
                pushImgAction(img)
            }

            Spacer()
            Button {
                camera.toggleTorch()
            } label: {
                Image(systemName: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .foregroundColor(camera.torchOn ? Color.init(hex: "#FFCF29") : .white)
                    .frame(width:44,height:44)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal,50)
        .padding(.bottom,20)
    }
}

// MARK: - 悬浮+号
struct PlusView: View {
    var size: CGFloat = 24
    var lineWidth: CGFloat = 3.5
    var body: some View {
        ZStack {
            Capsule()
                .fill(.white)
                .frame(width: lineWidth, height: size)
            Capsule()
                .fill(.white)
                .frame(width: size, height: lineWidth)
        }
        .shadow(color: .black.opacity(0.25), radius: 2)
    }
}

struct PulsingButton: View { //动画按钮
    @ObservedObject var camera: CameraManager
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    var pushImgAction: (_ img: UIImage) -> Void

    var body: some View {
        Button {
            guard !isAnimating else { return }
            isAnimating = true
            
            camera.capture { image in
                if let img = image {
                    pushImgAction(img)
                }
            }
        } label: {
            ZStack {
                Image("camera_pai")
                    .frame(width: 78, height: 78)
                if isAnimating {
                    RotatingGlowRing()
                        .frame(width: 75, height: 75)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            rotation = 0
                            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear{
            isAnimating = false
        }
    }
}

struct RotatingGlowRing: View {
    var body: some View {
            Circle()
                .trim(from: 0, to: 0.24)
                .stroke(
                    LinearGradient(
                    colors: [ .blue,.blue,.blue,.blue.opacity(0.7),.blue.opacity(0.4),.blue.opacity(0.1) ],startPoint: .leading,endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
        }
}
