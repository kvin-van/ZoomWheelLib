//
//  ExFont.swift
//  MCCodeScanner
//
//  Created by apple on 2026/6/29.
//

import Foundation
import SwiftUI

extension View {
    func reqularFont(size: CGFloat, color: String) -> some View {
        self.font(Font.system(size: size))
            .fontWeight(.regular)
            .lineSpacing(0)
            .foregroundColor(Color(hex: color))
    }
    func mediumFont(size: CGFloat, color: String) -> some View {
        self.font(Font.system(size: size))
            .fontWeight(.medium)
            .lineSpacing(0)
            .foregroundColor(Color(hex: color))
    }
    func boldFont(size: CGFloat, color: String) -> some View {
        self.font(Font.system(size: size))
            .fontWeight(.bold)
            .lineSpacing(0)
            .foregroundColor(Color(hex: color))
    }
    func heavyFont(size: CGFloat, color: String) -> some View {
        self.font(Font.system(size: size))
            .fontWeight(.heavy)
            .lineSpacing(0)
            .foregroundColor(Color(hex: color))
    }
}
