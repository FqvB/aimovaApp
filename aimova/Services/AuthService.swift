import Foundation

final class AuthService {
    private let api = APIClient.shared
    private let tokenKey = "jwt_token"

    var isSignedIn: Bool {
        KeychainService.load(key: tokenKey) != nil
    }

    func signIn(email: String, password: String) async throws -> User {
        let response: TokenResponse = try await api.post(
            "/api/v1/auth/login",
            body: LoginRequest(email: email, password: password)
        )
        KeychainService.save(key: tokenKey, value: response.accessToken)
        return try await api.get("/api/v1/auth/me")
    }

    func signUp(email: String, password: String, displayName: String?) async throws -> User {
        let response: TokenResponse = try await api.post(
            "/api/v1/auth/register",
            body: RegisterRequest(email: email, password: password, displayName: displayName)
        )
        KeychainService.save(key: tokenKey, value: response.accessToken)
        return try await api.get("/api/v1/auth/me")
    }

    func signOut() {
        KeychainService.delete(key: tokenKey)
    }
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email, password
        case displayName = "display_name"
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
