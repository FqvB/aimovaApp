import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .httpError(let code, let message):
            return message ?? "Server error (\(code))."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    let baseURL = "http://10.152.34.30:8000"

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: string) { return date }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        e.dateEncodingStrategy = .formatted(f)
        return e
    }()

    private init() {}

    private var authToken: String? {
        KeychainService.load(key: "jwt_token")
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await perform(path: path, method: "GET", body: Optional<EmptyBody>.none)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await perform(path: path, method: "POST", body: body)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await perform(path: path, method: "PUT", body: body)
    }

    func delete(_ path: String) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (_, response) = try await session.data(for: req)
            let http = response as! HTTPURLResponse
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.httpError(http.statusCode, nil)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func perform<T: Decodable, B: Encodable>(path: String, method: String, body: B?) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try Self.encoder.encode(body)
        }
        do {
            let (data, response) = try await session.data(for: req)
            let http = response as! HTTPURLResponse
            guard (200..<300).contains(http.statusCode) else {
                let message = try? JSONDecoder().decode(ErrorBody.self, from: data)
                throw APIError.httpError(http.statusCode, message?.detail)
            }
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}

private struct EmptyBody: Encodable {}
private struct ErrorBody: Decodable { let detail: String? }
