import SwiftUI

/// Language choice and the start/stop control. `isSpacious` fills the lower half when the device is folded.
struct ControlDeckView: View {
    @Bindable var model: ConversationModel
    var isSpacious: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var running: Bool { model.isAutoRunning }

    var body: some View {
        if !isSpacious && verticalSizeClass == .compact {
            // Short screens, like the closed outer display: one row so the transcript keeps its room.
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    languageBar
                    Button {
                        Task { await model.toggleAutoConversation() }
                    } label: {
                        Label(running ? "Stop" : "Start", systemImage: actionSymbol)
                            .font(.headline)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(.horizontal, 22)
                            .frame(maxHeight: .infinity)
                            .background(running ? CatTheme.warning : CatTheme.accent, in: Capsule())
                            .foregroundStyle(CatTheme.surface)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .sensoryFeedback(.impact, trigger: running)
                    .accessibilityLabel(actionTitle)
                }
                .fixedSize(horizontal: false, vertical: true)
                statusLine
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else {
            stacked
        }
    }

    private var stacked: some View {
        Group {
            if isSpacious {
                spaciousPanel
            } else {
                VStack(spacing: 14) {
                    languageBar
                    statusLine
                    wideMicButton
                }
                .padding(16)
                .frame(maxWidth: 560)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The lower half of the folded device: a single paper panel you reach down to touch.
    private var spaciousPanel: some View {
        VStack(spacing: 0) {
            languageBar
            Spacer(minLength: 16)
            roundMicButton
            statusLine
                .padding(.top, 12)
            Spacer(minLength: 16)
            if !running && !model.turns.isEmpty {
                Button("Summary", systemImage: "list.bullet.clipboard") {
                    model.showRecap(for: model.currentRecordID)
                }
                .buttonStyle(.bordered)
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: running)
        .padding(24)
        .frame(maxWidth: 620, maxHeight: .infinity)
        .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(CatTheme.rule)
        }
        .shadow(color: CatTheme.ink.opacity(0.06), radius: 18, y: 6)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: Languages

    private var languageBar: some View {
        HStack(spacing: 4) {
            languageMenu(title: "You speak", selection: $model.holderLanguage)
            Button("Swap languages", systemImage: "arrow.left.arrow.right") {
                withAnimation(.snappy) { model.swapLanguages() }
            }
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .foregroundStyle(CatTheme.accent)
            .frame(width: 44, height: 44)
            .background(CatTheme.surface, in: Circle())
            .overlay { Circle().strokeBorder(CatTheme.rule) }
            .buttonStyle(.plain)
            .contentShape(Circle())
            languageMenu(title: "They speak", selection: $model.otherLanguage)
        }
        .padding(6)
        .background(isSpacious ? CatTheme.canvas : CatTheme.surface,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(CatTheme.rule)
        }
    }

    private func languageMenu(title: String, selection: Binding<AppLanguage>) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.name).tag(language)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(CatTheme.mutedInk)
                HStack(spacing: 4) {
                    Text(selection.wrappedValue.name)
                        .font(.headline)
                        .foregroundStyle(CatTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CatTheme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection.wrappedValue.name)
    }

    // MARK: Status

    private var statusText: String {
        if let error = model.autoStatus { return error }
        guard running else {
            return "Detects \(model.holderLanguage.name) and \(model.otherLanguage.name) automatically"
        }
        if model.listener.isHearingSpeech { return "Hearing speech…" }
        if model.autoTranslating > 0 { return "Translating…" }
        return "Listening — just start talking"
    }

    private var statusLine: some View {
        Label {
            Text(statusText)
        } icon: {
            Image(systemName: model.autoStatus != nil ? "exclamationmark.triangle.fill" :
                    (running ? "waveform" : "sparkles"))
                .symbolEffect(.variableColor.iterative, isActive: model.listener.isHearingSpeech)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(model.autoStatus != nil ? CatTheme.warning : CatTheme.mutedInk)
        .multilineTextAlignment(.center)
        .contentTransition(.opacity)
        .animation(.smooth, value: statusText)
    }

    // MARK: Start / stop

    private var actionTitle: String { running ? "Stop conversation" : "Start conversation" }
    private var actionSymbol: String { running ? "stop.fill" : "microphone.fill" }

    private var roundMicButton: some View {
        Button {
            Task { await model.toggleAutoConversation() }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CatTheme.accent.opacity(running ? 0.14 : 0.08))
                        .frame(width: 136, height: 136)
                    if running && model.listener.isHearingSpeech && !reduceMotion {
                        Circle()
                            .strokeBorder(CatTheme.warning.opacity(0.45), lineWidth: 3)
                            .frame(width: 100, height: 100)
                            .phaseAnimator([false, true]) { ring, expanded in
                                ring
                                    .scaleEffect(expanded ? 1.35 : 1)
                                    .opacity(expanded ? 0 : 1)
                            } animation: { expanded in
                                expanded ? .smooth(duration: 1.2) : nil
                            }
                    }
                    Circle()
                        .fill(running ? CatTheme.warning : CatTheme.accent)
                        .frame(width: 100, height: 100)
                        .shadow(color: CatTheme.ink.opacity(0.15), radius: 10, y: 4)
                    Image(systemName: actionSymbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(CatTheme.surface)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 136, height: 136)

                Text(actionTitle)
                    .font(.headline)
                    .foregroundStyle(CatTheme.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: running)
        .accessibilityLabel(actionTitle)
    }

    private var wideMicButton: some View {
        Button {
            Task { await model.toggleAutoConversation() }
        } label: {
            Label(actionTitle, systemImage: actionSymbol)
                .font(.headline)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(running ? CatTheme.warning : CatTheme.accent, in: Capsule())
                .foregroundStyle(CatTheme.surface)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: running)
    }
}
