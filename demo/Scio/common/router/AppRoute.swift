//
//  AppRoute.swift
//  Scio
//

import Foundation
import SwiftUI
import UIKit

enum AppRoute {
    case cropVC(image: UIImage, recognizeText: String?)
}

// MARK: - Hashable
extension AppRoute: Hashable {

    func hash(into hasher: inout Hasher) {
        switch self {
        case .cropVC(let image, _):
            hasher.combine("cropVC")
            hasher.combine(ObjectIdentifier(image))   // UIImage 是 class
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.cropVC(let a, _), .cropVC(let b, _)):
            return a === b
        }
    }
}

extension AppRoute {

    var pageName: String {
        switch self {
        case .cropVC:
            return "cropVC"
        }
    }
}

extension AppRoute {

    @ViewBuilder
    func destination() -> some View {
        switch self {
        case .cropVC(let image, let recognizeText):
            CropVC(image: image, text: recognizeText)
        }
    }
}
