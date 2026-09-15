import Foundation

/// An image sent along with a question, introduced to the model by its label.
public struct GeminiImage: Sendable {
    public let jpegData: Data
    /// Said to the model right before the image, for example which screen it is.
    public let label: String

    public init(jpegData: Data, label: String) {
        self.jpegData = jpegData
        self.label = label
    }
}

/// One earlier question and Tiko's answer, so follow-up questions have context.
public struct ConversationExchange: Equatable, Sendable {
    public let userText: String
    public let tikoReply: String

    public init(userText: String, tikoReply: String) {
        self.userText = userText
        self.tikoReply = tikoReply
    }
}

public struct GeminiReply: Equatable, Sendable {
    public let text: String
    /// Which model actually answered, after any fallbacks.
    public let modelName: String

    public init(text: String, modelName: String) {
        self.text = text
        self.modelName = modelName
    }
}

public enum GeminiClientError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    /// Every model was rate-limited or temporarily down.
    case allModelsBusy
    /// None of the models could be used with this key.
    case noUsableModel
    case requestRejected(statusCode: Int, message: String)
    case noReplyText(reason: String)
    case unreadableResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "pehle menu bar mein Tiko kholo aur Gemini key daalo"
        case .invalidAPIKey:
            return "Gemini key galat lag rahi hai, panel mein check karo"
        case .allModelsBusy:
            return "Gemini ka free quota abhi busy hai, thodi der baad poochho"
        case .noUsableModel:
            return "is key se koi Gemini model nahi chal raha"
        case .requestRejected(let statusCode, let message):
            return "Gemini ne request mana kar di (\(statusCode)): \(message)"
        case .noReplyText(let reason):
            return "Gemini ne jawab nahi diya (\(reason))"
        case .unreadableResponse:
            return "Gemini ka jawab samajh nahi aaya"
        }
    }
}

/// What to do with one HTTP response from Gemini.
public enum GeminiResponseOutcome: Equatable {
    case success
    /// This model can't answer right now, but another model might.
    case tryNextModel(isBusy: Bool)
    case fail(GeminiClientError)
}

/// Talks to Google's Gemini API directly — no proxy server in between.
public final class GeminiClient: Sendable {
    private static let apiBaseURLString = "https://generativelanguage.googleapis.com/v1beta"

    private let apiKey: String
    private let modelNames: [String]
    private let urlSession: URLSession

    /// - Parameter modelNames: Models to try, best first.
    public init(apiKey: String, modelNames: [String], urlSession: URLSession = .shared) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelNames = modelNames
        self.urlSession = urlSession
    }

    /// Asks the question, trying each model in order. On the free tier a rate
    /// limit on one model says nothing about the next, so a busy model is
    /// skipped instead of failing the whole question.
    public func generateReply(
        systemInstruction: String,
        history: [ConversationExchange],
        images: [GeminiImage],
        userText: String
    ) async throws -> GeminiReply {
        guard !apiKey.isEmpty else { throw GeminiClientError.missingAPIKey }
        guard !modelNames.isEmpty else { throw GeminiClientError.noUsableModel }

        let requestBody = try JSONSerialization.data(withJSONObject: Self.makeRequestBody(
            systemInstruction: systemInstruction,
            history: history,
            images: images,
            userText: userText
        ))

        var sawBusyModel = false
        for modelName in modelNames {
            try Task.checkCancellation()

            var request = URLRequest(url: URL(string: "\(Self.apiBaseURLString)/models/\(modelName):generateContent")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // In a header rather than the URL, so the key never shows up wherever URLs get logged.
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = requestBody

            let (responseData, response) = try await urlSession.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            switch Self.classifyResponse(statusCode: statusCode, responseData: responseData) {
            case .success:
                return GeminiReply(text: try Self.extractReplyText(from: responseData), modelName: modelName)
            case .tryNextModel(let isBusy):
                sawBusyModel = sawBusyModel || isBusy
                continue
            case .fail(let error):
                throw error
            }
        }

        throw sawBusyModel ? GeminiClientError.allModelsBusy : GeminiClientError.noUsableModel
    }

    /// Lists the models this key can ask questions of, so Tiko never depends on
    /// a hardcoded model name that Google may have retired.
    public func fetchAvailableModelNames() async throws -> [String] {
        guard !apiKey.isEmpty else { throw GeminiClientError.missingAPIKey }

        var request = URLRequest(url: URL(string: "\(Self.apiBaseURLString)/models?pageSize=1000")!)
        request.timeoutInterval = 20
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (responseData, response) = try await urlSession.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        switch Self.classifyResponse(statusCode: statusCode, responseData: responseData) {
        case .success:
            return try Self.parseGenerateContentModelNames(from: responseData)
        case .tryNextModel(let isBusy):
            if isBusy { throw GeminiClientError.allModelsBusy }
            throw GeminiClientError.requestRejected(statusCode: statusCode, message: Self.extractErrorMessage(from: responseData))
        case .fail(let error):
            throw error
        }
    }

    // MARK: - Request and response shapes

    public static func makeRequestBody(
        systemInstruction: String,
        history: [ConversationExchange],
        images: [GeminiImage],
        userText: String
    ) -> [String: Any] {
        var contents: [[String: Any]] = []

        // Earlier exchanges are sent as text only — resending old screenshots
        // would make every request slower without helping the new question.
        for exchange in history {
            contents.append(["role": "user", "parts": [["text": exchange.userText]]])
            contents.append(["role": "model", "parts": [["text": exchange.tikoReply]]])
        }

        var questionParts: [[String: Any]] = []
        for image in images {
            questionParts.append(["text": image.label])
            questionParts.append(["inline_data": [
                "mime_type": "image/jpeg",
                "data": image.jpegData.base64EncodedString()
            ]])
        }
        // The question goes last, after the images it refers to.
        questionParts.append(["text": userText])
        contents.append(["role": "user", "parts": questionParts])

        return [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.6,
                // Room for thinking models to reason and still answer.
                "maxOutputTokens": 2048
            ]
        ]
    }

    public static func classifyResponse(statusCode: Int, responseData: Data) -> GeminiResponseOutcome {
        switch statusCode {
        case 200:
            return .success
        case 429, 500, 502, 503, 504:
            return .tryNextModel(isBusy: true)
        case 404:
            // This model isn't served for this key or region; another may be.
            return .tryNextModel(isBusy: false)
        default:
            let errorMessage = extractErrorMessage(from: responseData)
            // Google answers a bad key with 400 "API key not valid" or 403.
            if statusCode == 403 || errorMessage.localizedCaseInsensitiveContains("API key") {
                return .fail(.invalidAPIKey)
            }
            return .fail(.requestRejected(statusCode: statusCode, message: errorMessage))
        }
    }

    public static func extractReplyText(from responseData: Data) throws -> String {
        guard let responseJSON = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw GeminiClientError.unreadableResponse
        }

        if let promptFeedback = responseJSON["promptFeedback"] as? [String: Any],
           let blockReason = promptFeedback["blockReason"] as? String {
            throw GeminiClientError.noReplyText(reason: blockReason)
        }

        guard let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first else {
            throw GeminiClientError.noReplyText(reason: "no candidates")
        }

        let contentParts = (firstCandidate["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        // Thinking models return their reasoning as parts marked "thought";
        // only the answer itself should reach the user.
        let replyText = contentParts
            .filter { contentPart in (contentPart["thought"] as? Bool) != true }
            .compactMap { contentPart in contentPart["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !replyText.isEmpty else {
            throw GeminiClientError.noReplyText(reason: firstCandidate["finishReason"] as? String ?? "empty")
        }
        return replyText
    }

    public static func parseGenerateContentModelNames(from responseData: Data) throws -> [String] {
        guard let responseJSON = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let models = responseJSON["models"] as? [[String: Any]] else {
            throw GeminiClientError.unreadableResponse
        }

        return models.compactMap { model in
            guard let fullModelName = model["name"] as? String,
                  let supportedMethods = model["supportedGenerationMethods"] as? [String],
                  supportedMethods.contains("generateContent") else {
                return nil
            }
            // The API names models "models/gemini-…" but expects them without the prefix in URLs.
            return fullModelName.hasPrefix("models/") ? String(fullModelName.dropFirst("models/".count)) : fullModelName
        }
    }

    public static func extractErrorMessage(from responseData: Data) -> String {
        if let responseJSON = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let errorDetails = responseJSON["error"] as? [String: Any],
           let message = errorDetails["message"] as? String {
            return message
        }
        return String(data: responseData.prefix(200), encoding: .utf8) ?? "no details"
    }
}
