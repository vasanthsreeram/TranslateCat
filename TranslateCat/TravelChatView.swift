import SwiftUI

struct TravelChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = TravelChatModel()

    private let suggestions = [
        "How do I ask for directions in Spanish?",
        "What should I pack for a weekend trip?",
        "Help me plan a relaxed day in Barcelona"
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if model.messages.isEmpty { introduction }
                        ForEach(model.messages) { message in
                            messageView(message)
                                .id(message.id)
                        }
                        if model.isGenerating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Thinking through your question…")
                            }
                            .font(.footnote)
                            .foregroundStyle(CatTheme.mutedInk)
                        }
                        if let error = model.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
                .onChange(of: model.messages.count) { _, _ in
                    if let id = model.messages.last?.id {
                        withAnimation(.smooth) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
            .background(CatTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if model.isAvailable { composer }
            }
            .navigationTitle("Travel help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !model.messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New chat", systemImage: "square.and.pencil") { model.clear() }
                    }
                }
            }
        }
        .onDisappear { model.stopSpeaking() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "suitcase.rolling")
                .font(.largeTitle)
                .foregroundStyle(CatTheme.accent)
                .accessibilityHidden(true)
            Text("A little help along the way")
                .font(.system(.title, design: .serif, weight: .medium))
                .foregroundStyle(CatTheme.ink)
            Text("Ask about travel plans, local phrases, and practical ideas. Answers are made on your device and may be wrong; check time-sensitive details with official sources.")
                .foregroundStyle(CatTheme.mutedInk)

            if model.isAvailable {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        Task { await model.send(suggestion) }
                    } label: {
                        Text(suggestion)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("On-device travel help needs an Apple Intelligence-compatible iPhone with Apple Intelligence enabled and its model ready. Translation still works separately.")
                    .font(.callout)
                    .foregroundStyle(CatTheme.ink)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func messageView(_ message: TravelMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.isUser ? "YOU" : "TRAVEL HELP")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(CatTheme.accent)
            Text(message.text)
                .font(.system(.body, design: message.isUser ? .default : .serif))
                .foregroundStyle(CatTheme.ink)
                .textSelection(.enabled)
            if !message.isUser {
                Button("Read aloud", systemImage: "speaker.wave.2") {
                    model.readAloud(message.text)
                }
                .font(.footnote)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.isUser ? CatTheme.canvas : CatTheme.surface,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(CatTheme.rule)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask about your trip…", text: $model.draft, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit { Task { await model.send() } }
                .padding(12)
                .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            Button("Send", systemImage: "arrow.up") {
                Task { await model.send() }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isGenerating)
        }
        .padding(16)
        .background(CatTheme.canvas)
    }
}
