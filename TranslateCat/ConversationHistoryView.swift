import SwiftUI

struct ConversationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: ConversationModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Start a new conversation", systemImage: "square.and.pencil") {
                        model.newConversation()
                        dismiss()
                    }
                    .disabled(model.turns.isEmpty)
                } footer: {
                    Text("Transcripts and notes are saved only on this iPhone, and audio isn’t kept. During a conversation, spoken lines are sent to Google Gemini to be translated and summarized.")
                }

                Section("Conversations") {
                    ForEach(model.records.filter { !$0.turns.isEmpty }) { record in
                        NavigationLink {
                            detail(for: record.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.title)
                                    .lineLimit(1)
                                    .foregroundStyle(CatTheme.ink)
                                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if record.id == model.currentRecordID {
                                    Text("CURRENT")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(CatTheme.accent)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let visible = model.records.enumerated().filter { !$0.element.turns.isEmpty }
                        let actual = IndexSet(offsets.map { visible[$0].offset })
                        model.deleteRecords(at: actual)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CatTheme.canvas)
            .navigationTitle("Conversation notes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detail(for id: UUID) -> some View {
        let record = model.records.first { $0.id == id }
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(record?.startedAt.formatted(date: .complete, time: .shortened) ?? "")
                    .font(.footnote)
                    .foregroundStyle(CatTheme.mutedInk)

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NOTES")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(CatTheme.accent)
                    TextField("Add a note about this conversation…", text: Binding(
                        get: { model.records.first(where: { $0.id == id })?.note ?? "" },
                        set: { model.updateNote($0, for: id) }
                    ), axis: .vertical)
                    .lineLimit(3...8)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 12) {
                    Text("SUMMARY")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(CatTheme.accent)
                    if let record = model.records.first(where: { $0.id == id }) {
                        RecapSummaryView(
                            record: record,
                            isLoading: model.summarizingRecordID == id,
                            error: model.summaryError,
                            isLocked: !model.summariesUnlocked
                        ) {
                            Task { await model.makeClearNotes(for: id) }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 12))

                ForEach(record?.turns ?? []) { turn in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(turn.speaker == .holder ? "YOU" : "THEY")
                            .font(.caption.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(CatTheme.accent)
                        Text(turn.original)
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(CatTheme.ink)
                        Text(turn.translation.isEmpty ? "Translation unavailable" : turn.translation)
                            .foregroundStyle(CatTheme.mutedInk)
                        Text("\(turn.sourceName) → \(turn.targetName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .background(CatTheme.canvas.ignoresSafeArea())
        .navigationTitle("Transcript")
        .toolbar {
            if let record = model.records.first(where: { $0.id == id }) {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: record.transcript) {
                        Label("Share transcript", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
