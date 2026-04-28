import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Aimova")
                    .font(.largeTitle.bold())
                Text("See where your shots actually go.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                if isSignUp {
                    TextField("Name (optional)", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                }

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(isSignUp ? .newPassword : .password)
            }
            .padding(.horizontal, 24)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        if isSignUp {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                displayName: displayName.isEmpty ? nil : displayName
                            )
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                .padding(.horizontal, 24)

                Button {
                    isSignUp.toggle()
                    authViewModel.errorMessage = nil
                } label: {
                    Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                        .font(.subheadline)
                }
            }

            Spacer()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
