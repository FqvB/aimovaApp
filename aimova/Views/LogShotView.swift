import SwiftUI

struct LogShotView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var shotViewModel: ShotViewModel
    var onShotLogged: (() -> Void)?

    @State private var shape: ShotShape = .straight
    @State private var carryText = ""
    @State private var offlineYards: Double = 0
    @State private var totalText = ""
    @State private var notes = ""
    @State private var loggedAt = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var carryValue: Double? { Double(carryText) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    shapePicker
                    carryInput
                    offlineInput
                    optionalFields
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(carryValue == nil || isSaving)
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
    }

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shape")
                .font(.headline)
                .padding(.horizontal)
            Picker("Shape", selection: $shape) {
                ForEach(ShotShape.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    private var carryInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Carry (yards)")
                .font(.headline)
                .padding(.horizontal)
            TextField("150", text: $carryText)
                .keyboardType(.numberPad)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
        }
    }

    private var offlineInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offline (yards)")
                .font(.headline)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Group {
                    stepButton("−5") { offlineYards -= 5 }
                    stepButton("−1") { offlineYards -= 1 }
                }
                VStack(spacing: 2) {
                    Text("\(abs(Int(offlineYards)))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text(offlineSideLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 80)
                Group {
                    stepButton("+1") { offlineYards += 1 }
                    stepButton("+5") { offlineYards += 5 }
                }
            }
            .padding(.horizontal)
        }
    }

    private var optionalFields: some View {
        VStack(spacing: 0) {
            GroupBox {
                VStack(spacing: 12) {
                    HStack {
                        Text("Total distance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Optional", text: $totalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("yds").foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Notes")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Optional", text: $notes)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                    DatePicker("Date", selection: $loggedAt, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .padding(.horizontal)
        }
    }

    private var offlineSideLabel: String {
        if offlineYards < 0 { return "Left" }
        if offlineYards > 0 { return "Right" }
        return "On line"
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

    private func save() {
        guard let carry = carryValue else { return }
        isSaving = true
        Task {
            do {
                try await shotViewModel.logShot(
                    shape: shape,
                    carry: carry,
                    offline: offlineYards,
                    total: Double(totalText),
                    notes: notes,
                    loggedAt: loggedAt
                )
                onShotLogged?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
