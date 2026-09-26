import Foundation

/// Online translation through the Gemini API, used for the hands-free demo.
enum GeminiTranslator {
    static var apiKey: String {
        let value = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String
            ?? ""
        return value.hasPrefix("$(") ? "" : value
    }
    static let model = "gemini-3.8-flash"

    struct HeardLine: Decodable {
        var language: String
        var original: String
        var translation: String
    }

    enum Failure: LocalizedError {
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .badResponse(let message): message
            }
        }
    }

    /// Transcribes one spoken utterance, detects which of the two languages it is in,
    /// and translates it into the other one. Returns nil when no clear speech was heard.
    static func translate(audio wav: Data, between first: AppLanguage, and second: AppLanguage) async throws -> HeardLine? {
        let prompt = """
            This audio is one utterance from a face-to-face conversation between someone who speaks \
            \(first.name) (code "\(first.rawValue)") and someone who speaks \(second.name) (code "\(second.rawValue)").
            Transcribe exactly what was said in its original language, set "language" to that language's code, \
            and translate it naturally into the other language.
            If there is no clear speech, or only noise, set "language" to "none" and leave both texts empty.
            """
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inline_data": ["mime_type": "audio/wav", "data": wav.base64EncodedString()]],
                    ["text": prompt]
                ]
            ]],
            "generationConfig": generationConfig(schema: [
                "type": "OBJECT",
                "properties": [
                    "language": ["type": "STRING", "enum": [first.rawValue, second.rawValue, "none"]],
                    "original": ["type": "STRING"],
                    "translation": ["type": "STRING"]
                ],
                "required": ["language", "original", "translation"]
            ])
        ]
        let text = try await send(body)
        let line = try JSONDecoder().decode(HeardLine.self, from: Data(text.utf8))
        let original = line.original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.language != "none", !original.isEmpty else { return nil }
        return line
    }

    static func translate(text: String, from source: AppLanguage, to target: AppLanguage) async throws -> String {
        let body: [String: Any] = [
            "contents": [[
                "parts": [["text": """
                    Translate this \(source.name) text into natural \(target.name). \
                    Reply with only the translation.

                    \(text)
                    """]]
            ]],
            "generationConfig": ["thinkingConfig": ["thinkingLevel": "low"]]
        ]
        return try await send(body).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Summarizes a finished conversation for the holder, in their language.
    static func recap(of transcript: String, note: String, in language: AppLanguage) async throws -> ConversationRecap {
        let prompt = """
            Summarize this face-to-face conversation, which was translated between two people, for "You" (the app owner).
            Write everything in \(language.name). Use only what's in the transcript and the owner's note; never invent \
            names, prices, times, bookings, or promises. Keep it brief and plain.
            - title: 2–6 words naming what the conversation was about.
            - summary: 1–3 sentences.
            - keyPoints: the important facts or answers, up to 5 short items.
            - followUps: things "You" should do next, if any were mentioned; otherwise an empty list.

            Owner's note: \(note.isEmpty ? "none" : note)
            Transcript:
            \(transcript)
            """
        let list: [String: Any] = ["type": "ARRAY", "items": ["type": "STRING"]]
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": generationConfig(schema: [
                "type": "OBJECT",
                "properties": [
                    "title": ["type": "STRING"],
                    "summary": ["type": "STRING"],
                    "keyPoints": list,
                    "followUps": list
                ],
                "required": ["title", "summary", "keyPoints", "followUps"]
            ])
        ]
        let text = try await send(body)
        return try JSONDecoder().decode(ConversationRecap.self, from: Data(text.utf8))
    }

    private static func generationConfig(schema: [String: Any]) -> [String: Any] {
        [
            "thinkingConfig": ["thinkingLevel": "low"],
            "responseMimeType": "application/json",
            "responseSchema": schema
        ]
    }

    private static func send(_ body: [String: Any]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw Failure.badResponse("Add GEMINI_API_KEY to Secrets.xcconfig and rebuild to enable online translation.")
        }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error"] as? [String: Any] {
            throw Failure.badResponse(error["message"] as? String ?? "Gemini returned an error.")
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let candidates = json?["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw Failure.badResponse("Gemini didn’t return a translation.")
        }
        return parts.compactMap { $0["text"] as? String }.joined()
    }
}
