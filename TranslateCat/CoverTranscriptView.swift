import SwiftUI

struct CoverTranscriptView: View {
    var model: ConversationModel
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 58

    private var latest: Turn? { model.turns.last }

    private var isHearingOther: Bool {
        model.listeningSpeaker == .other && (model.speech.isListening || model.speech.isStarting)
    }

    private var words: String {
        if model.listeningSpeaker == .holder && (model.speech.isListening || model.speech.isStarting) {
            return model.liveTranslation.isEmpty ? model.otherLanguage.listeningPhrase : model.liveTranslation
        }
        if isHearingOther && !model.speech.partial.isEmpty {
            return model.speech.partial
        }
        guard let latest else { return model.otherLanguage.waitingPhrase }
        if latest.speaker == .holder {
            return latest.translation.isEmpty ? model.otherLanguage.listeningPhrase : latest.translation
        }
        return latest.original
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.height > geometry.size.width {
                transcript
                    .frame(width: geometry.size.height, height: geometry.size.width)
                    .rotationEffect(.degrees(-90))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else {
                transcript
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .rotationEffect(.degrees(180))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CatTheme.surface.ignoresSafeArea())
        .environment(\.colorScheme, .light)
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 8) {
                Image(systemName: "cat.fill")
                Text(model.otherLanguage.nativeName.uppercased())
                    .tracking(2)
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(CatTheme.accent)

            Text(words)
                .font(.system(size: headlineSize, weight: .medium, design: .serif))
                .minimumScaleFactor(0.4)
                .lineLimit(8)
                .foregroundStyle(CatTheme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if isHearingOther || model.listener.isHearingSpeech {
                Text(model.otherLanguage.listeningPhrase)
                    .font(.subheadline)
                    .foregroundStyle(CatTheme.mutedInk)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
