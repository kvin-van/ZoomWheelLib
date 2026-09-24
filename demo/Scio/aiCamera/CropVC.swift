//
//  CropVC.swift
//  Scio
//

import Foundation
import SwiftUI

struct CropVC: View {
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: QuestionCropViewModel
    @State private var didDetect = false

    init(image: UIImage,text:String?) {
        _viewModel = StateObject( wrappedValue: QuestionCropViewModel(image: image,text: text))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            VStack(spacing: 0) {
                imageView
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .task {
            guard !didDetect else { return }
                didDetect = true
            await viewModel.detectQuestion()
            
        }
    }
}

// MARK: - imageView
private extension CropVC {
    var imageView: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Image(uiImage: viewModel.displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width,height: size.height)
                    .background(Color.black.opacity(0.3))

                CropOverlayView(
                    imageSize: viewModel.displayImage.size,
                    cropRect: $viewModel.cropRect,
                    showFullImage: $viewModel.showFullImage
                )
                    .frame(width: size.width,height: size.height)
            }
            .onAppear {
                viewModel.imageViewSize = size
            }
            .onChange(of: size) { _, newValue in
                viewModel.imageViewSize = newValue
            }
        }
    }

}



// MARK: - 底部
private extension CropVC {
    private var bottomBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.white)
                .ignoresSafeArea(edges: .bottom)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 30))
                        .foregroundStyle(.black)
                        .frame(width: 60, height: 60)
                }
                Spacer()
                Button {
                    confirm()
                } label: {
                    Circle()
                        .fill(.blue)
                        .frame(width: 74, height: 74)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
                Spacer()
                Color.clear
                    .frame(width: 60, height: 60)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

// MARK: - Action
private extension CropVC {
    func confirm() {
        let image: UIImage
        if viewModel.showFullImage {
            image = viewModel.displayImage
        } else {
            image = viewModel.cropImage()
        }

        DispatchQueue.main.async {
            router.popToRoot()
        }
    }
}
