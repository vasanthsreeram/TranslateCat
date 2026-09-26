import Foundation
import Translation

@MainActor
final class Translator {
    private(set) var status: String?

    static let unavailable = "Translation is unavailable here. Download the language pack on an iPhone and try again."

    func translate(
        _ text: String,
        from source: Locale.Language,
        to target: Locale.Language,
        session: TranslationSession?
    ) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = nil
            return ""
        }
        if source.minimalIdentifier == target.minimalIdentifier {
            status = nil
            return trimmed
        }
        guard let session else {
            status = Self.unavailable
            return nil
        }
        do {
            // The system requests any required on-device language downloads here.
            try await session.prepareTranslation()
            let translated = try await session.translate(trimmed).targetText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if translated.isEmpty {
                status = Self.unavailable
                return nil
            }
            status = nil
            return translated
        } catch is CancellationError {
            return nil
        } catch {
            status = Self.unavailable
            return nil
        }
    }
}
