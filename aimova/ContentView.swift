//
//  ContentView.swift
//  aimova
//
//  Created by egsango on 27/04/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var bagViewModel = BagViewModel()

    var body: some View {
        if authViewModel.isAuthenticated {
            TabView {
                MapView()
                    .tabItem { Label("Map", systemImage: "map") }
                    .environmentObject(bagViewModel)

                BagView()
                    .tabItem { Label("Bag", systemImage: "bag") }
                    .environmentObject(bagViewModel)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        } else {
            LoginView()
        }
    }
}

