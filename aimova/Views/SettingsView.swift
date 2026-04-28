import SwiftUI

struct SettingsView: View {
    @AppStorage("tournament_mode") private var tournamentMode = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Gameplay") {
                    Toggle("Tournament Mode", isOn: $tournamentMode)
                    if tournamentMode {
                        Text("Wind adjustment is disabled. Only raw dispersion ellipses are shown. No wind data is fetched.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        authViewModel.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
