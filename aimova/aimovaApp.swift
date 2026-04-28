//
//  aimovaApp.swift
//  aimova
//
//  Created by egsango on 27/04/2026.
//

import SwiftUI

@main
struct aimovaApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
