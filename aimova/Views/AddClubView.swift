import SwiftUI

struct AddClubView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bagViewModel: BagViewModel

    @State private var name = ""
    @State private var clubType: ClubType = .iron
    @State private var loftText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Club Details") {
                    TextField("Name  (e.g. 7 Iron)", text: $name)

                    Picker("Type", selection: $clubType) {
                        ForEach(ClubType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    HStack {
                        Text("Loft")
                        Spacer()
                        TextField("Optional", text: $loftText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("°")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            isSaving = true
                            await bagViewModel.addClub(
                                name: name,
                                clubType: clubType,
                                loftDegrees: Double(loftText)
                            )
                            isSaving = false
                            if bagViewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
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
}
