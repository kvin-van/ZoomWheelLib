//
//  ExString.swift
//  MCCodeScanner
//
//  Created by apple on 2026/6/30.
//

import Foundation
import SwiftUI

extension String {
    
    /// 返回 LocalizedStringKey，用于 SwiftUI Text
    var localizedKey: LocalizedStringKey {
        return LocalizedStringKey(self)
    }
    
    /// 返回本地化后的 String，用于业务逻辑、打印等
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, arguments: arguments)
    }    
}
