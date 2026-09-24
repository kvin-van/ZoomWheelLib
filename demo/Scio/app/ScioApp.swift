//
//  ScioApp.swift
//  Scio
//

import SwiftUI

@main
struct ScioApp: App {
    @StateObject private var router = Router()

    init() {}

    var body: some Scene {
        WindowGroup {
                    NavigationStack(path: $router.path) {
                        CameraViewVC()
                            .navigationDestination(for: AppRoute.self) { route in
                                route.destination()
                            }
                    }
                    .environmentObject(router)
                }
    }
}
