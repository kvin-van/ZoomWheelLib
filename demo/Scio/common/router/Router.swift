//
//  Router.swift
//  MCCodeScanner
//
//  Created by apple on 2026/6/30.
//

import Foundation
import Combine
import SwiftUI
@MainActor
final class Router: ObservableObject {
    
    @Published var path: [AppRoute] = []
    
    
    
    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop(_ count: Int = 1) {
        guard count > 0 else { return }
        let removeCount = min(count, path.count)
        path.removeLast(removeCount)
    }

    func safePush(_ route: AppRoute, when condition: @autoclosure () -> Bool) {
           guard condition() else { return }
           path.append(route)
       }
    func popToRoot() {
        path.removeAll()
    }

    func replace(_ route: AppRoute) {
        _ = path.popLast()
        path.append(route)
    }
}

extension Router {
    // 当前页面的上一页
    var previousRoute: AppRoute? {
        guard path.count >= 2 else { return nil }
        return path[path.count - 2]
    }
}
