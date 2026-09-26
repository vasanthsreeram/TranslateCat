import Foundation
import FoundationModels
import Observation
import Translation

struct Turn: Identifiable, Equatable, Codable {
    let id: UUID
    let speaker: Speaker
    let original: String
    let translation: String
    let sourceName: String
    let targetName: String
}

struct ConversationRecord: Identifiable, Codable {
    var id: UUID
    var startedAt: Date
    var turns: [Turn]
    var note: String
    var summary: String?
    var recap: ConversationRecap? = nil

    var title: String {
        turns.first?.original ?? "Conversation"
    }

    var transcript: String {
        let lines = turns.map { turn in
            let speaker = turn.speaker == .holder ? "You" : "Them"
            let translated = turn.translation.isEmpty
                ? "Translation unavailable"
                : "\(turn.targetName): \(turn.translation)"
            return "\(speaker) (\(turn.sourceName)): \(turn.original)\n\(translated)"
        }
        return (["Conversation — \(startedAt.formatted(date: .abbreviated, time: .shortened))"]
                + (summary.map { ["Clear notes: \($0)"] } ?? [])
                + (note.isEmpty ? [] : ["Notes: \(note)"])
                + lines).joined(separator: "\n\n")
    }
}

struct ConversationRecap: Codable, Equatable {
    var title: String
    var summary: String
    var keyPoints: [String]
    var followUps: [String]

    var plainText: String {
        var parts = [title, summary]
        if !keyPoints.isEmpty {
            parts.append("Key points:\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n"))
        }
        if !followUps.isEmpty {
            parts.append("Follow-ups:\n" + followUps.map { "• \($0)" }.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }
}

@MainActor
@Observable
final class ConversationModel {
    var holderLanguage: AppLanguage = .english {
        didSet { UserDefaults.standard.set(holderLanguage.rawValue, forKey: "holderLanguage") }
    }
    var otherLanguage: AppLanguage = .spanish {
        didSet { UserDefaults.standard.set(otherLanguage.rawValue, forKey: "otherLanguage") }
    }
    var records: [ConversationRecord] = []
    var currentRecordID: UUID
    var turns: [Turn] {
        records.first(where: { $0.id == currentRecordID })?.turns ?? []
    }
    var draft = ""
    var typingAs: Speaker = .holder
    var translationStatus: String?
    var speechStatus: String?
    var coverAvailable = false
    var outerEnabled = true
    var listeningSpeaker: Speaker?
    var configuration: TranslationSession.Configuration?
    var liveConfiguration: TranslationSession.Configuration?
    var liveTranslation = ""
    var liveTranslationStatus: String?
    var summarizingRecordID: UUID?
    var summaryError: String?
    /// The conversation whose summary sheet is showing.
    var recapRecordID: UUID?
    /// Mirrors the translatecat_pro entitlement; summaries are a Pro feature.
    var summariesUnlocked = false
    private var turnCountAtStart = 0

    let camera = CoverCamera()
    let speech = LiveSpeech()
    let listener = AutoListener()
    var autoStatus: String?
    var autoTranslating = 0

    private var utteranceChain: Task<Void, Never>?

    private let translator = Translator()
    private var queue: [Pending] = []
    private var translating = false
    private var isCommittingSpeech = false
    private var liveRequestID = UUID()
    private var liveRequest: LiveRequest?
    private static let storageKey = "savedConversations.v1"

    init() {
        let saved = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([ConversationRecord].self, from: $0) } ?? []
        if let active = saved.first {
            records = saved
            currentRecordID = active.id
        } else {
            let record = ConversationRecord(id: UUID(), startedAt: .now, turns: [], note: "", summary: nil)
            records = [record]
            currentRecordID = record.id
        }

        let defaults = UserDefaults.standard
        if let holder = defaults.string(forKey: "holderLanguage").flatMap(AppLanguage.init(rawValue:)),
           let other = defaults.string(forKey: "otherLanguage").flatMap(AppLanguage.init(rawValue:)),
           holder != other {
            holderLanguage = holder
            otherLanguage = other
        }
    }

    func newConversation() {
        guard !turns.isEmpty else { return }
        let record = ConversationRecord(id: UUID(), startedAt: .now, turns: [], note: "", summary: nil)
        records.insert(record, at: 0)
        currentRecordID = record.id
        persist()
    }

    func updateNote(_ note: String, for id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].note = note
        persist()
    }

    func deleteRecords(at offsets: IndexSet) {
        let ids = offsets.map { records[$0].id }
        records.remove(atOffsets: offsets)
        if ids.contains(currentRecordID) {
            if let first = records.first {
                currentRecordID = first.id
            } else {
                let record = ConversationRecord(id: UUID(), startedAt: .now, turns: [], note: "", summary: nil)
                records = [record]
                currentRecordID = record.id
            }
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func makeClearNotes(for id: UUID) async {
        guard summariesUnlocked, summarizingRecordID == nil,
              let record = records.first(where: { $0.id == id }), !record.turns.isEmpty else { return }
        summarizingRecordID = id
        summaryError = nil
        defer { summarizingRecordID = nil }

        let source = record.turns.map { turn in
            "\(turn.speaker == .holder ? "You" : "Them"): \(turn.original)"
                + (turn.translation.isEmpty ? "" : " [translation: \(turn.translation)]")
        }.joined(separator: "\n")
        let excerpt = String(source.suffix(12_000))
        let language = holderLanguage

        if let recap = try? await GeminiTranslator.recap(of: excerpt, note: record.note, in: language) {
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            records[index].recap = recap
            records[index].summary = recap.plainText
            persist()
            return
        }

        // Offline: fall back to Apple's on-device model when it's available.
        guard case .available = SystemLanguageModel.default.availability else {
            summaryError = "Couldn’t write a summary. Check the internet connection and try again."
            return
        }
        let session = LanguageModelSession(instructions: """
            Turn a travel conversation transcript into clear, brief notes for the participants.
            Use only facts explicitly in the transcript or the user's note. Do not invent names,
            bookings, prices, or promises. Distinguish agreed plans from questions or uncertain details.
            Write plain language with short headings and action items if there are any.
            Do not repeat the full transcript.
            """)
        do {
            let response = try await session.respond(to: "User note: \(record.note)\nTranscript:\n\(excerpt)")
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            records[index].recap = nil
            records[index].summary = response.content
            persist()
        } catch {
            summaryError = "Couldn’t write a summary right now. Try again later."
        }
    }

    func showRecap(for id: UUID) {
        recapRecordID = id
        guard summariesUnlocked,
              let record = records.first(where: { $0.id == id }), record.summary == nil else { return }
        Task { await makeClearNotes(for: id) }
    }

    func startNewConversationAfterRecap() {
        recapRecordID = nil
        newConversation()
    }

    private struct Pending {
        let text: String
        let speaker: Speaker
        let source: AppLanguage
        let target: AppLanguage
        let recordID: UUID
    }

    private struct LiveRequest {
        let id: UUID
        let text: String
        let source: AppLanguage
        let target: AppLanguage
    }

    var isAutoRunning: Bool { listener.isRunning }

    func toggleAutoConversation() async {
        if listener.isRunning {
            listener.stop()
            autoStatus = nil
            // Let lines still being translated land, then summarize what was said.
            await utteranceChain?.value
            let id = currentRecordID
            if turns.count > turnCountAtStart {
                if let index = records.firstIndex(where: { $0.id == id }) {
                    records[index].summary = nil
                    records[index].recap = nil
                }
                showRecap(for: id)
            }
            return
        }
        turnCountAtStart = turns.count
        if speech.isListening || speech.isStarting {
            _ = await speech.stop()
            listeningSpeaker = nil
            resetLiveTranslation()
        }
        listener.onUtterance = { [weak self] wav in
            self?.queueUtterance(wav)
        }
        do {
            try await listener.start()
            autoStatus = nil
        } catch {
            autoStatus = error.localizedDescription
        }
    }

    private func queueUtterance(_ wav: Data) {
        let previous = utteranceChain
        let recordID = currentRecordID
        let holder = holderLanguage
        let other = otherLanguage
        autoTranslating += 1
        // Chain requests so lines are saved in the order they were spoken.
        utteranceChain = Task {
            let outcome: (GeminiTranslator.HeardLine?, String?) = await Task.detached {
                do {
                    return (try await GeminiTranslator.translate(audio: wav, between: holder, and: other), nil)
                } catch {
                    return (nil, "Couldn’t translate that line. Check the internet connection. (\(error.localizedDescription))")
                }
            }.value
            await previous?.value
            autoTranslating -= 1
            if let failure = outcome.1 { autoStatus = failure }
            guard let result = outcome.0 else { return }
            let isHolder = result.language == holder.rawValue
            let job = Pending(
                text: result.original.trimmingCharacters(in: .whitespacesAndNewlines),
                speaker: isHolder ? .holder : .other,
                source: isHolder ? holder : other,
                target: isHolder ? other : holder,
                recordID: recordID
            )
            autoStatus = nil
            append(job, translated: result.translation.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func swapLanguages() {
        let previousHolder = holderLanguage
        holderLanguage = otherLanguage
        otherLanguage = previousHolder
    }

    func keepLanguagesDistinct(changedHolder: Bool, previous: AppLanguage) {
        if holderLanguage == otherLanguage {
            if changedHolder {
                otherLanguage = previous
            } else {
                holderLanguage = previous
            }
        }
    }

    func sendDraft() {
        let text = draft
        draft = ""
        enqueue(text: text, speaker: typingAs)
    }

    func onSpeakTapped(_ speaker: Speaker) {
        if speech.isListening || isCommittingSpeech {
            guard !isCommittingSpeech else { return }
            isCommittingSpeech = true
            Task {
                await commitListening(switchTo: speaker)
                isCommittingSpeech = false
            }
            return
        }
        guard !speech.isStarting else { return }
        Task { await beginListening(speaker) }
    }

    func requestLiveTranslation(for partial: String) {
        guard let speaker = listeningSpeaker, speech.isListening else { return }
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let source = speaker == .holder ? holderLanguage : otherLanguage
        let target = speaker == .holder ? otherLanguage : holderLanguage
        let request = LiveRequest(id: UUID(), text: text,
                                  source: source, target: target)
        liveRequestID = request.id
        liveRequest = request
        if var current = liveConfiguration,
           same(current.source, request.source), same(current.target, request.target) {
            current.invalidate()
            liveConfiguration = current
        } else {
            liveConfiguration = TranslationSession.Configuration(
                source: request.source.language, target: request.target.language
            )
        }
    }

    func performLiveTranslation(using session: TranslationSession) async {
        guard let request = liveRequest,
              listeningSpeaker != nil,
              session.sourceLanguage == nil || same(session.sourceLanguage, request.source) else { return }
        let translated = await translator.translate(
            request.text, from: request.source.language,
            to: request.target.language, session: session
        )
        guard liveRequestID == request.id, listeningSpeaker != nil else { return }
        if let translated { liveTranslation = translated }
        liveTranslationStatus = translator.status
    }

    private func resetLiveTranslation() {
        liveRequestID = UUID()
        liveRequest = nil
        liveConfiguration = nil
        liveTranslation = ""
        liveTranslationStatus = nil
    }

    func performPendingTranslation(using session: TranslationSession) async {
        if translating { return }
        translating = true
        defer {
            translating = false
            if let next = queue.first {
                schedule(next)
            }
        }

        guard let job = queue.first, sessionMatches(session, job) else { return }
        queue.removeFirst()
        let translated = await translator.translate(
            job.text,
            from: job.source.language,
            to: job.target.language,
            session: session
        )
        translationStatus = translator.status
        append(job, translated: translated ?? "")
    }

    private func beginListening(_ speaker: Speaker) async {
        resetLiveTranslation()
        listeningSpeaker = speaker
        let locale = (speaker == .holder ? holderLanguage : otherLanguage).locale
        let started = await speech.start(locale: locale, session: camera.session)
        guard listeningSpeaker == speaker || !started else { return }
        if !started {
            if listeningSpeaker == speaker {
                listeningSpeaker = nil
            }
            speechStatus = speech.status
        } else {
            speechStatus = nil
        }
    }

    private func commitListening(switchTo speaker: Speaker) async {
        let who = listeningSpeaker ?? speaker
        let text = await speech.stop()
        listeningSpeaker = nil
        resetLiveTranslation()
        if !text.isEmpty {
            enqueue(text: text, speaker: who)
        }
        if who != speaker {
            await beginListening(speaker)
        }
    }

    private func enqueue(text: String, speaker: Speaker) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let source = speaker == .holder ? holderLanguage : otherLanguage
        let target = speaker == .holder ? otherLanguage : holderLanguage
        let job = Pending(text: trimmed, speaker: speaker, source: source, target: target, recordID: currentRecordID)
        if source == target {
            translationStatus = nil
            append(job, translated: trimmed)
            return
        }
        Task {
            if let translated = try? await GeminiTranslator.translate(text: trimmed, from: source, to: target),
               !translated.isEmpty {
                translationStatus = nil
                append(job, translated: translated)
                return
            }
            // Fall back to Apple's on-device translation when offline.
            queue.append(job)
            if translating { return }
            schedule(job)
        }
    }

    private func schedule(_ job: Pending) {
        if var current = configuration,
           same(current.source, job.source),
           same(current.target, job.target) {
            current.invalidate()
            configuration = current
        } else {
            configuration = TranslationSession.Configuration(
                source: job.source.language,
                target: job.target.language
            )
        }
    }

    private func append(_ job: Pending, translated: String) {
        guard let index = records.firstIndex(where: { $0.id == job.recordID }) else { return }
        records[index].turns.append(
            Turn(
                id: UUID(),
                speaker: job.speaker,
                original: job.text,
                translation: translated,
                sourceName: job.source.name,
                targetName: job.target.name
            )
        )
        persist()
    }

    private func sessionMatches(_ session: TranslationSession, _ job: Pending) -> Bool {
        let sourceMatches = session.sourceLanguage == nil || same(session.sourceLanguage, job.source)
        let targetMatches = session.targetLanguage == nil || same(session.targetLanguage, job.target)
        return sourceMatches && targetMatches
    }

    private func same(_ language: Locale.Language?, _ appLanguage: AppLanguage) -> Bool {
        guard let language else { return false }
        let sessionID = language.minimalIdentifier.lowercased()
        let languageID = appLanguage.language.minimalIdentifier.lowercased()
        return sessionID == languageID
            || sessionID.hasPrefix(languageID + "-")
            || languageID.hasPrefix(sessionID + "-")
    }
}
