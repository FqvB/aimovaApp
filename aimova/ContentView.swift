//
//  ContentView.swift
//  aimova
//
//  Created by egsango on 27/04/2026.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        Map(position: $position) {}
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
