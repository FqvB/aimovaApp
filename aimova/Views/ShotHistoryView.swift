import SwiftUI

struct ShotHistoryView: View {
    let club: Club
    @EnvironmentObject var bagViewModel: BagViewModel
    @StateObject private var shotViewModel: ShotViewModel
    @State private var showLogShot = false

    init(club: Club) {
        self.club = club
        _shotViewModel = StateObject(
            wrappedValue: ShotViewModel(clubId: club.id, clubName: club.name)
        )
    }

    var body: some View {
        Group {
            if shotViewModel.isLoading && shotViewModel.shots.isEmpty {
                ProgressView("Loading shots…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if shotViewModel.shots.isEmpty {
                ContentUnavailableView(
                    "No Shots Yet",
                    systemImage: "target",
                    description: Text("Tap + to log your first shot with this club.")
                )
            } else {
                shotList
            }
        }
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showLogShot = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showLogShot) {
            LogShotView(shotViewModel: shotViewModel) {
                Task { await bagViewModel.loadClubs() }
            }
        }
        .task {
            await shotViewModel.loadShots()
        }
        .alert("Error", isPresented: Binding(
            get: { shotViewModel.errorMessage != nil },
            set: { if !$0 { shotViewModel.errorMessage = nil } }
        )) {
            Button("OK") { shotViewModel.errorMessage = nil }
        } message: {
            Text(shotViewModel.errorMessage ?? "")
        }
    }

    private var shotList: some View {
        List {
            ForEach(shotViewModel.shotsByShape, id: \.0) { shape, shots in
                Section("\(shape.displayName)  (\(shots.count))") {
                    ForEach(shots) { shot in
                        ShotRow(shot: shot)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await shotViewModel.deleteShot(id: shot.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

private struct ShotRow: View {
    let shot: Shot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    Label("\(Int(shot.carryYards)) yds", systemImage: "arrow.up.right")
                        .font(.body.monospacedDigit())
                    offlineLabel
                }
                if let notes = shot.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(shot.loggedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var offlineLabel: some View {
        let yards = Int(abs(shot.offlineYards))
        let side = shot.offlineYards < 0 ? "L" : (shot.offlineYards > 0 ? "R" : "—")
        return Text(shot.offlineYards == 0 ? "On line" : "\(yards) yds \(side)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}
