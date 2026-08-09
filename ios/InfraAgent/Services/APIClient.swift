import Foundation

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .badStatus(let status, let body):
            return "HTTP \(status): \(body)"
        }
    }
}

final class APIClient {
    static var shared: APIClient {
        APIClient(baseURL: AppConfig.backendBaseURL)
    }

    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL = AppConfig.defaultBackendBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = APIClient.iso8601WithFractionalSeconds.date(from: value) {
                return date
            }
            if let date = APIClient.iso8601.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var request = try makeRequest(path: path, queryItems: queryItems)
        request.httpMethod = "GET"
        return try await send(request)
    }

    func post<T: Decodable, Body: Encodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        body: Body
    ) async throws -> T {
        var request = try makeRequest(path: path, queryItems: queryItems)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    func post<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var request = try makeRequest(path: path, queryItems: queryItems)
        request.httpMethod = "POST"
        return try await send(request)
    }

    func put<T: Decodable, Body: Encodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        body: Body
    ) async throws -> T {
        var request = try makeRequest(path: path, queryItems: queryItems)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    func postNoContent(_ path: String, queryItems: [URLQueryItem] = []) async throws {
        var request = try makeRequest(path: path, queryItems: queryItems)
        request.httpMethod = "POST"
        try await sendNoContent(request)
    }

    func delete(_ path: String) async throws {
        var request = try makeRequest(path: path, queryItems: [])
        request.httpMethod = "DELETE"
        try await sendNoContent(request)
    }

    private func sendNoContent(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.badStatus(-1, "Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIClientError.badStatus(http.statusCode, body)
        }
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(normalizedPath),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIClientError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIClientError.invalidURL
        }
        return URLRequest(url: url, timeoutInterval: AppConfig.apiTimeoutInterval)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.badStatus(-1, "Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIClientError.badStatus(http.statusCode, body)
        }
        return try decoder.decode(T.self, from: data)
    }

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
