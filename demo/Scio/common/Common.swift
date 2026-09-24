//
//  Common.swift
//  MCCodeScanner
//
//  Created by apple on 2026/6/29.
//

import Foundation
import UIKit
import SwiftUI

// 隐私协议
let kPrivacy = "https://www.xgmc.top/sciomc_privacy_policy.html"//MCManager.shared.privateIos()
// 自动续费协议
let kDdeduct = "https://www.xgmc.top/sciomc_user_terms.html"//MCManager.shared.deductIos()

let kAppID = 6791875549

let kWeekly = "com.xgmc.Scio.weekly.free.9.99"
let kYealy = "com.xgmc.Scio.yearly.59.99"
let kMonthly = "com.xgmc.monthly.free.9.99"

let kAppStoreUrl = "https://apps.apple.com/app/id\(kAppID)"
let kAppStoreUrlReview = "https://apps.apple.com/app/id\(kAppID)?action=write-review"

var kScreenWidth: CGFloat {
    return UIScreen.main.bounds.size.width
}

var kScreenHeight: CGFloat {
    return UIScreen.main.bounds.size.height
}

var kScreenScale: CGFloat {
    let screenWidth = (kScreenWidth > kScreenHeight) ? kScreenHeight : kScreenWidth
    return screenWidth/375.0
}

let kBundleID : String = Bundle.main.bundleIdentifier ?? ""


