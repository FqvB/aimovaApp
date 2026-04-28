import SwiftUI

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bagViewModel: BagViewModel

    @State private var selectedClub: Club?
    @State private var shotViewModel: ShotViewModel?

    @State private var shape: ShotShape = .straight
    @State private var carryText = ""
    @State private var offlineYards: Double = 0
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var carryValue: Double? { Double(carryText) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                clubPicker
                if selectedClub != nil {
                    shapePicker
                    carryInput
                    offlineInput
                }
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedClub == nil || carryValue == nil || isSaving)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear { restoreLastClub() }
    }

    private var clubPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Club")
                .font(.headline)
                .padding(.horizontal)
            Picker("Club", selection: $selectedClub) {
                Text("Select a club").tag(Optional<Club>.none)
                ForEach(bagViewModel.activeClubs) { club in
                    Text(club.name).tag(Optional(club))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .onChange(of: selectedClub) { _, club in
                guard let club else { return }
                shotViewModel = ShotViewModel(clubId: club.id, clubName: club.name)
                UserDefaults.standard.set(club.id, forKey: "lastUsedClubId")
            }
        }
    }

    private var shapePicker: some View {
        Picker("Shape", selection: $shape) {
            ForEach(ShotShape.allCases, id: \.self) { s in
                Text(s.displayName).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var carryInput: some View {
        TextField("Carry (yards)", text: $carryText)
            .keyboardType(.numberPad)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
    }

    private var offlineInput: some View {
        HStack(spacing: 12) {
            stepButton("−5") { offlineYards -= 5 }
            stepButton("−1") { offlineYards -= 1 }
            VStack(spacing: 2) {
                Text("\(abs(Int(offlineYards)))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(offlineYards < 0 ? "Left" : offlineYards > 0 ? "Right" : "On line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 80)
            stepButton("+1") { offlineYards += 1 }
            stepButton("+5") { offlineYards += 5 }
        }
        .padding(.horizontal)
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(width: 52, height: 52)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func restoreLastClub() {
        let lastId = UserDefaults.standard.string(forKey: "lastUsedClubId")
        selectedClub = bagViewModel.activeClubs.first { $0.id == lastId }
            ?? bagViewModel.activeClubs.first
        if let club = selectedClub {
            shotViewModel = ShotViewModel(clubId: club.id, clubName: club.name)
        }
    }

    private func save() {
        guard let carry = carryValue, let vm = shotViewModel else { return }
        isSaving = true
        Task {
            do {
                try await vm.logShot(
                    shape: shape,
                    carry: carry,
                    offline: offlineYards,
                    total: nil,
                    notes: nil,
                    loggedAt: Date()
                )
                await bagViewModel.loadClubs()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
