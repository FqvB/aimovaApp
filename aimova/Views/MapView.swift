import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var bagViewModel: BagViewModel
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: LocationManager.augustaNational,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var visibleCenter: CLLocationCoordinate2D = LocationManager.augustaNational
    @State private var showQuickLog = false

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $position) {}
                    .mapStyle(.imagery(elevation: .realistic))
                    .ignoresSafeArea()
                    .onMapCameraChange { context in
                        visibleCenter = context.region.center
                    }
            }

            crosshair

            VStack {
                Spacer()
                HStack {
                    coordinateLabel
                    Spacer()
                    VStack(spacing: 12) {
                        quickLogButton
                        recenterButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onReceive(locationManager.$userLocation) { location in
            guard let location else { return }
            position = .region(
                MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
        .sheet(isPresented: $showQuickLog) {
            QuickLogView()
                .environmentObject(bagViewModel)
        }
    }

    private var crosshair: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 1, height: 28)
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 28, height: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 2)
    }

    private var coordinateLabel: some View {
        Text(String(format: "%.5f, %.5f", visibleCenter.latitude, visibleCenter.longitude))
            .font(.caption2.monospaced())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private var quickLogButton: some View {
        Button {
            showQuickLog = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.6), in: Circle())
        }
    }

    private var recenterButton: some View {
        Button {
            recenter()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.6), in: Circle())
        }
    }

    private func recenter() {
        let target = locationManager.userLocation ?? LocationManager.augustaNational
        withAnimation {
            position = .region(
                MKCoordinateRegion(
                    center: target,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }
}

#Preview {
    MapView()
}
