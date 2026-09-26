import AVFoundation
import Foundation
import FoundationModels
import Observation

struct TravelMessage: Identifiable {
    var id = UUID()
    var isUser: Bool
    var text: String
}

@MainActor
@Observable
final class TravelChatModel {
    var messages: [TravelMessage] = []
    var draft = ""
    var isGenerating = false
    var errorMessage: String?

    private var session: LanguageModelSession?
    private let speaker = AVSpeechSynthesizer()

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func send(_ question: String? = nil) async {
        let prompt = (question ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating, isAvailable else { return }
        draft = ""
        errorMessage = nil
        messages.append(TravelMessage(isUser: true, text: prompt))
        isGenerating = true
        defer { isGenerating = false }

        if session == nil {
            session = LanguageModelSession(instructions: """
                You are a friendly, concise travel companion. Answer practical travel questions and help people plan and communicate. Keep answers brief and actionable. You have no live web access or current location. Never invent current prices, schedules, opening hours, visa requirements, safety alerts, or bookings; tell the user to verify changing details with an official source. Ask for a destination when it is needed. Do not claim to have completed a real-world action.
                """)
        }

        do {
            let answer = try await session!.respond(to: prompt)
            messages.append(TravelMessage(isUser: false, text: answer.content))
        } catch {
            errorMessage = "The on-device model couldn’t answer. Check that Apple Intelligence has finished setting up on your iPhone, then try again."
        }
    }

    func readAloud(_ text: String) {
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speaker.speak(utterance)
    }

    func stopSpeaking() {
        speaker.stopSpeaking(at: .immediate)
    }

    func clear() {
        stopSpeaking()
        messages.removeAll()
        session = nil
        errorMessage = nil
    }
}
