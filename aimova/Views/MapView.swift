import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var mapViewModel = MapViewModel()
    @EnvironmentObject var bagViewModel: BagViewModel

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: LocationManager.augustaNational,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var visibleCenter: CLLocationCoordinate2D = LocationManager.augustaNational
    @State private var showQuickLog = false
    @State private var hasInitialLocation = false

    // Pre-computed each render so Map content stays simple
    private var currentOverlays: [EllipseOverlay] {
        mapViewModel.ellipseOverlays(pin: visibleCenter)
    }
    private var currentAimLine: [CLLocationCoordinate2D]? {
        mapViewModel.aimLineCoordinates(pin: visibleCenter)
    }

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let coords = currentAimLine {
                        MapPolyline(coordinates: coords)
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    }
                    ForEach(currentOverlays) { overlay in
                        MapPolygon(coordinates: overlay.coordinates)
                            .foregroundStyle(overlay.color.opacity(overlay.fillOpacity))
                            .stroke(overlay.color.opacity(overlay.strokeOpacity), lineWidth: 1)
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .ignoresSafeArea()
                .onMapCameraChange { context in
                    visibleCenter = context.region.center
                }
                .onTapGesture { location in
                    if let coord = proxy.convert(location, from: .local) {
                        mapViewModel.aimCoordinate = coord
                    }
                }
            }

            crosshair

            VStack(spacing: 0) {
                Spacer()

                HStack(alignment: .bottom) {
                    coordinateLabel
                    Spacer()
                    VStack(spacing: 12) {
                        quickLogButton
                        recenterButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if mapViewModel.selectedClubId != nil {
                    shapeToggleRow
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                }

                clubSelectorStrip
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onReceive(locationManager.$userLocation) { location in
            guard let location, !hasInitialLocation else { return }
            hasInitialLocation = true
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

    // MARK: - Crosshair

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

    // MARK: - Floating controls

    private var coordinateLabel: some View {
        Text(String(format: "%.5f, %.5f", visibleCenter.latitude, visibleCenter.longitude))
            .font(.caption2.monospaced())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private var quickLogButton: some View {
        Button { showQuickLog = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.6), in: Circle())
        }
    }

    private var recenterButton: some View {
        Button { recenter() } label: {
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

    // MARK: - Shape toggles

    private var shapeToggleRow: some View {
        HStack(spacing: 8) {
            ForEach(ShotShape.allCases, id: \.self) { shape in
                shapeToggleButton(shape)
            }
            Spacer()
            if mapViewModel.isLoadingDispersion {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    private func shapeToggleButton(_ shape: ShotShape) -> some View {
        let isActive = mapViewModel.activeShapes.contains(shape)
        let countLabel = mapViewModel.shotCountLabel(for: shape)

        return Button {
            mapViewModel.toggleShape(shape)
        } label: {
            VStack(spacing: 2) {
                Text(shape.abbreviation)
                    .font(.system(size: 15, weight: .bold))
                if let count = countLabel {
                    Text(count)
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(isActive ? .white : shape.overlayColor)
            .frame(width: 44, height: countLabel != nil ? 44 : 36)
            .background(
                isActive ? shape.overlayColor : shape.overlayColor.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(shape.overlayColor.opacity(0.6), lineWidth: 1)
            )
        }
    }

    // MARK: - Club selector strip

    private var clubSelectorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if bagViewModel.activeClubs.isEmpty {
                    Text("Add clubs in the Bag tab")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                } else {
                    ForEach(bagViewModel.activeClubs) { club in
                        clubChip(club)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func clubChip(_ club: Club) -> some View {
        let isSelected = mapViewModel.selectedClubId == club.id

        return Button {
            Task { await mapViewModel.toggleClub(club.id) }
        } label: {
            Text(club.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                    in: Capsule()
                )
        }
    }
}
