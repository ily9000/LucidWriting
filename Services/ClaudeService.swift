import Foundation
import AppKit

struct RefineResult {
    let refinedMessage: String?
    let originalMessage: String?
    let recipient: String?
    let platform: String?
    let reasoning: String?
}

// MARK: - API Key Validation

enum APIKeyValidationResult {
    case valid
    case invalid(reason: String)
    case networkError(Error)
}

class ClaudeService {
    private let baseURL = "https://api.anthropic.com/v1/messages"

    var apiKey: String {
        UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
    }

    /// Loads user context from file
    private func loadUserContext() -> String {
        let contextPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("LucidWriting/UserContext.txt")

        if let context = try? String(contentsOf: contextPath, encoding: .utf8) {
            return context
        }

        // Fallback to bundle location
        if let bundlePath = Bundle.main.path(forResource: "UserContext", ofType: "txt"),
           let context = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            return context
        }

        return ""
    }

    // MARK: - API Key Validation

    /// Validates the API key by making a minimal test request
    func validateAPIKey(_ key: String) async -> APIKeyValidationResult {
        guard !key.isEmpty else {
            return .invalid(reason: "API key is empty")
        }

        // Use a minimal request to test the key
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1,
            "messages": [
                [
                    "role": "user",
                    "content": "Hi"
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .invalid(reason: "Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                return .valid
            case 401:
                return .invalid(reason: "Invalid API key")
            case 403:
                return .invalid(reason: "API key lacks required permissions")
            case 429:
                // Rate limited but key is valid
                return .valid
            default:
                let body = String(data: data, encoding: .utf8) ?? ""
                // Try to extract error message from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    return .invalid(reason: message)
                }
                return .invalid(reason: "API error: \(httpResponse.statusCode)")
            }
        } catch {
            return .networkError(error)
        }
    }

    // MARK: - Message Refinement

    func refineMessage(screenshot: NSImage, ocrText: String) async throws -> RefineResult {
        guard !apiKey.isEmpty else {
            throw ClaudeError.noApiKey
        }

        // Convert image to base64
        guard let imageData = screenshot.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ClaudeError.imageConversionFailed
        }

        let base64Image = pngData.base64EncodedString()

        // Load user context
        let userContext = loadUserContext()

        // Build the request
        let prompt = """
        You are a message refinement assistant. Analyze this screenshot of a messaging application.

        ABOUT THE USER:
        \(userContext.isEmpty ? "No user context provided" : userContext)

        OCR-extracted text from the image:
        ---
        \(ocrText)
        ---

        Your tasks:
        1. Identify the messaging context:
           - Who is the recipient (look for names, contact info, channel names)?
           - What platform is this (iMessage, Slack, Gmail, etc.)?
           - What is the conversation about?
           - Consider the user's role and adjust tone accordingly (CEO vs team vs external)

        2. Find the draft message being composed (usually at the bottom in a text input field)

        3. Refine the draft message to be:
           - Executive-level: clear, concise, and action-oriented
           - Appropriate for the recipient (more formal for CEO/external, warmer for team)
           - Professional but approachable
           - Free of typos and grammatical errors
           - Structured with clear next steps if applicable

        Respond in this exact JSON format:
        {
          "recipient": "name or description",
          "platform": "iMessage/Slack/Gmail/etc",
          "original_draft": "the draft message you found",
          "refined_message": "your improved version",
          "reasoning": "brief explanation of changes made"
        }

        If no draft message is found, set refined_message to null.
        """

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.parseError
        }

        // Extract JSON from response (Claude might wrap it in markdown)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8),
              let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ClaudeError.parseError
        }

        let refinedMessage = result["refined_message"] as? String
        let originalMessage = result["original_draft"] as? String
        let recipient = result["recipient"] as? String
        let platform = result["platform"] as? String
        let reasoning = result["reasoning"] as? String

        return RefineResult(
            refinedMessage: refinedMessage,
            originalMessage: originalMessage,
            recipient: recipient,
            platform: platform,
            reasoning: reasoning
        )
    }

    // MARK: - Refine with Custom Instruction

    func refineWithInstruction(message: String, instruction: String, recipient: String, platform: String) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        let userContext = loadUserContext()

        let prompt = """
        You are a message refinement assistant.

        ABOUT THE USER:
        \(userContext.isEmpty ? "No user context provided" : userContext)

        CONTEXT:
        - Recipient: \(recipient)
        - Platform: \(platform)

        CURRENT MESSAGE:
        \(message)

        USER'S INSTRUCTION:
        \(instruction)

        Apply the user's instruction to refine the message. Return ONLY the refined message text, nothing else.
        """

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                return nil
            }

            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Refine with instruction error: \(error)")
            return nil
        }
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON block in markdown code fence
        if let jsonMatch = text.range(of: "```json\n", options: .caseInsensitive),
           let endMatch = text.range(of: "\n```", range: jsonMatch.upperBound..<text.endIndex) {
            return String(text[jsonMatch.upperBound..<endMatch.lowerBound])
        }

        // Try to find raw JSON object
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text
    }
}

enum ClaudeError: LocalizedError {
    case noApiKey
    case imageConversionFailed
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Claude API key not configured. Please set it in Settings."
        case .imageConversionFailed:
            return "Failed to process screenshot"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse Claude's response"
        }
    }
}
