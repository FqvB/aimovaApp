import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = AuthService()

    init() {
        isAuthenticated = authService.isSignedIn
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            currentUser = try await authService.signIn(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            currentUser = try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        authService.signOut()
        currentUser = nil
        isAuthenticated = false
    }
}
