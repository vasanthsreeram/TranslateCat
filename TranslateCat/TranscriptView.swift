import SwiftUI

/// The running conversation, written in the holder's language with the other side's words beneath.
struct TranscriptView: View {
    var model: ConversationModel

    private var isPending: Bool {
        model.isAutoRunning && (model.listener.isHearingSpeech || model.autoTranslating > 0)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.turns.isEmpty && !isPending {
                    emptyState
                        .containerRelativeFrame(.vertical)
                }
                ForEach(model.turns) { turn in
                    TurnBubble(turn: turn, isLatest: turn.id == model.turns.last?.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if isPending {
                    pendingBubble
                        .transition(.opacity)
                }
            }
            .animation(.smooth, value: model.turns.count)
            .animation(.smooth, value: isPending)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(CatTheme.accent)
                .accessibilityHidden(true)
            Text("Ready when you are")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(CatTheme.ink)
            Text("Tap Start and talk naturally. TranslateCat hears \(model.holderLanguage.name) and \(model.otherLanguage.name) and translates each line automatically.")
                .font(.callout)
                .foregroundStyle(CatTheme.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }

    private var pendingBubble: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: model.listener.isHearingSpeech)
                .accessibilityHidden(true)
            Text(model.autoTranslating > 0 && !model.listener.isHearingSpeech ? "Translating…" : "Listening…")
                .font(.callout)
        }
        .foregroundStyle(CatTheme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CatTheme.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(CatTheme.rule) }
        .frame(maxWidth: .infinity)
    }
}

private struct TurnBubble: View {
    var turn: Turn
    var isLatest: Bool

    private var isHolder: Bool { turn.speaker == .holder }

    /// Text in the holder's own language: what they said, or the translation of what they heard.
    private var readable: String {
        if isHolder || turn.translation.isEmpty { return turn.original }
        return turn.translation
    }

    private var counterpart: String? {
        let text = isHolder ? turn.translation : turn.original
        return text.isEmpty || text == readable ? nil : text
    }

    var body: some View {
        VStack(alignment: isHolder ? .trailing : .leading, spacing: 6) {
            Text(isHolder ? "You" : "Them · \(turn.sourceName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CatTheme.mutedInk)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 8) {
                Text(readable)
                    .font(.system(isLatest ? .title2 : .title3, design: .serif, weight: .medium))
                    .foregroundStyle(CatTheme.ink)
                if let counterpart {
                    Text(counterpart)
                        .font(.callout)
                        .foregroundStyle(isHolder ? CatTheme.accent : CatTheme.mutedInk)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isHolder ? CatTheme.accentWash : CatTheme.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isHolder ? .clear : CatTheme.rule)
            }
        }
        .frame(maxWidth: .infinity, alignment: isHolder ? .trailing : .leading)
        .padding(isHolder ? .leading : .trailing, 44)
        .accessibilityElement(children: .combine)
    }
}
