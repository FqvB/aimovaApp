import SwiftUI

struct BagView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var bagViewModel: BagViewModel
    @State private var showAddClub = false

    var body: some View {
        NavigationStack {
            Group {
                if bagViewModel.isLoading && bagViewModel.activeClubs.isEmpty && bagViewModel.inactiveClubs.isEmpty {
                    ProgressView("Loading bag…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    clubList
                }
            }
            .navigationTitle("My Bag")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddClub = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        authViewModel.signOut()
                    } label: {
                        Text("Sign Out")
                            .font(.footnote)
                    }
                }
            }
            .sheet(isPresented: $showAddClub) {
                AddClubView()
                    .environmentObject(bagViewModel)
            }
            .task {
                await bagViewModel.loadClubs()
            }
            .alert("Error", isPresented: Binding(
                get: { bagViewModel.errorMessage != nil },
                set: { if !$0 { bagViewModel.errorMessage = nil } }
            )) {
                Button("OK") { bagViewModel.errorMessage = nil }
            } message: {
                Text(bagViewModel.errorMessage ?? "")
            }
        }
    }

    private var clubList: some View {
        List {
            Section("Active Clubs") {
                if bagViewModel.activeClubs.isEmpty {
                    ContentUnavailableView(
                        "No Clubs Yet",
                        systemImage: "figure.golf",
                        description: Text("Tap + to add your first club.")
                    )
                } else {
                    ForEach(bagViewModel.activeClubs) { club in
                        NavigationLink(destination: ShotHistoryView(club: club).environmentObject(bagViewModel)) {
                            ClubRow(club: club)
                        }
                    }
                    .onMove { from, to in
                        Task { await bagViewModel.reorderClubs(fromOffsets: from, toOffset: to) }
                    }
                    .onDelete { indexSet in
                        Task {
                            for idx in indexSet {
                                await bagViewModel.deactivateClub(id: bagViewModel.activeClubs[idx].id)
                            }
                        }
                    }
                }
            }

            if !bagViewModel.inactiveClubs.isEmpty {
                Section("Inactive Clubs") {
                    ForEach(bagViewModel.inactiveClubs) { club in
                        ClubRow(club: club)
                            .swipeActions(edge: .leading) {
                                Button("Reactivate") {
                                    Task { await bagViewModel.reactivateClub(id: club.id) }
                                }
                                .tint(.green)
                            }
                    }
                }
            }
        }
    }
}

private struct ClubRow: View {
    let club: Club

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(club.clubType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !club.shotCounts.displayString.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(club.shotCounts.displayString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let loft = club.loftDegrees {
                Text(loft.formatted(.number.precision(.fractionLength(0))) + "°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    BagViewPreviewContainer()
}

private struct BagViewPreviewContainer: View {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var bagViewModel: BagViewModel

    init() {
        let bagViewModel = BagViewModel()
        let now = Date()
        bagViewModel.activeClubs = [
            Club(
                id: "club-1",
                userId: "user-1",
                name: "Titleist TSR2",
                clubType: .driver,
                loftDegrees: 10.0,
                displayOrder: 0,
                isActive: true,
                shotCounts: ShotCounts(fade: 4, draw: 2, straight: 6),
                createdAt: now,
                updatedAt: now
            ),
            Club(
                id: "club-2",
                userId: "user-1",
                name: "Mizuno JPX 7i",
                clubType: .iron,
                loftDegrees: 32.0,
                displayOrder: 1,
                isActive: true,
                shotCounts: ShotCounts(fade: 1, draw: 0, straight: 5),
                createdAt: now,
                updatedAt: now
            )
        ]
        bagViewModel.inactiveClubs = [
            Club(
                id: "club-3",
                userId: "user-1",
                name: "Vokey SM9 56",
                clubType: .wedge,
                loftDegrees: 56.0,
                displayOrder: 2,
                isActive: false,
                shotCounts: .empty,
                createdAt: now,
                updatedAt: now
            )
        ]
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _bagViewModel = StateObject(wrappedValue: bagViewModel)
    }

    var body: some View {
        BagView()
            .environmentObject(authViewModel)
            .environmentObject(bagViewModel)
    }
}
