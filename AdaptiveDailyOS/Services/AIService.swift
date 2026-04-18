import Foundation

// Thin wrapper around the Anthropic Messages API. Milestone A builds only
// the primitive sendMessage + a connection test. Weekly-plan and adaptation
// logic will be layered on top in later milestones.
struct AIService {
    static let defaultModel = "claude-sonnet-4-6"

    enum AIServiceError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case authenticationFailed
        case rateLimited
        case httpError(status: Int, body: String)
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:         return "No API key. Add one in Settings."
            case .invalidResponse:       return "Invalid response from Anthropic API."
            case .authenticationFailed:  return "API key rejected. Check it in Settings."
            case .rateLimited:           return "Rate limited by Anthropic. Try again shortly."
            case .httpError(let s, _):   return "Anthropic API error (HTTP \(s))."
            case .decodingFailed(let m): return "Could not parse response: \(m)"
            }
        }
    }

    var apiKey: String?
    var model: String = defaultModel
    var session: URLSession = .shared

    init(apiKey: String? = KeychainService.loadAPIKey()) {
        self.apiKey = apiKey
    }

    // Sends a single user message with an optional system prompt. Returns
    // the concatenated text of all text blocks in the assistant response.
    func sendMessage(
        systemPrompt: String? = nil,
        userMessage: String,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        if let systemPrompt {
            body["system"] = systemPrompt
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw AIServiceError.authenticationFailed
        case 429:
            throw AIServiceError.rateLimited
        default:
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.httpError(status: http.statusCode, body: bodyText)
        }

        do {
            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
            return text
        } catch {
            throw AIServiceError.decodingFailed(error.localizedDescription)
        }
    }

    // Lightweight round-trip used by the Settings screen to validate an API key.
    func testConnection() async throws {
        _ = try await sendMessage(userMessage: "ping", maxTokens: 16)
    }
}

private struct MessagesResponse: Decodable {
    let content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    let type: String
    let text: String?
}
