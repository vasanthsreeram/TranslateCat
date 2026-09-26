import SwiftUI

/// Shown when a conversation ends: the summary, the transcript, and what to do next.
/// Partially folded, the summary sits above the fold and the transcript and actions below it.
struct ConversationRecapView: View {
    var model: ConversationModel
    var recordID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var isFolded = false

    private var record: ConversationRecord? {
        model.records.first { $0.id == recordID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let record {
                    if isFolded {
                        ArrangementView {
                            ScrollView { summaryColumn(record) }
                        } secondary: {
                            ScrollView { transcriptCard(record) }
                                .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
                        }
                        .arrangementViewStyle(.split)
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                summaryColumn(record)
                                transcriptCard(record)
                            }
                            .padding(.bottom, 8)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CatTheme.canvas.ignoresSafeArea())
            .onGeometryChange(for: Bool.self) { proxy in
                !proxy.reservedRegions(kind: .division).isEmpty
            } action: { folded in
                isFolded = folded
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if let record, !record.turns.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareText(record)) {
                            Label("Share summary", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    // MARK: Summary

    private func summaryColumn(_ record: ConversationRecord) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            header(record)

            RecapSummaryView(
                record: record,
                isLoading: model.summarizingRecordID == recordID,
                error: model.summaryError,
                isLocked: !model.summariesUnlocked,
                showsTitle: false
            ) {
                Task { await model.makeClearNotes(for: recordID) }
            }
            .padding(20)
            .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(CatTheme.rule)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func header(_ record: ConversationRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Conversation complete", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(CatTheme.accent)

            Text(record.recap?.title ?? "Your conversation")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(CatTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { metaChips(record) }
                VStack(alignment: .leading, spacing: 6) { metaChips(record) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func metaChips(_ record: ConversationRecord) -> some View {
        chip(record.startedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
        chip(record.turns.count == 1 ? "1 line" : "\(record.turns.count) lines", systemImage: "text.bubble")
        chip("\(model.holderLanguage.name) ⇄ \(model.otherLanguage.name)", systemImage: "globe")
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(CatTheme.mutedInk)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(CatTheme.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(CatTheme.rule) }
    }

    // MARK: Transcript

    private func transcriptCard(_ record: ConversationRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRANSCRIPT")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(CatTheme.mutedInk)
                .padding(.bottom, 12)

            ForEach(Array(record.turns.enumerated()), id: \.element.id) { index, turn in
                if index > 0 {
                    CatTheme.rule.frame(height: 1)
                        .padding(.leading, 56)
                }
                transcriptRow(turn)
            }
        }
        .padding(20)
        .background(CatTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(CatTheme.rule)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func transcriptRow(_ turn: Turn) -> some View {
        let isHolder = turn.speaker == .holder
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(isHolder ? "You" : "Them")
                .font(.caption.weight(.bold))
                .foregroundStyle(isHolder ? CatTheme.accent : CatTheme.mutedInk)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(turn.original)
                    .foregroundStyle(CatTheme.ink)
                if !turn.translation.isEmpty && turn.translation != turn.original {
                    Text(turn.translation)
                        .font(.callout)
                        .foregroundStyle(CatTheme.mutedInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("Keep talking", systemImage: "mic.fill")
                    .font(.headline)
                    .foregroundStyle(CatTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(CatTheme.accentWash, in: Capsule())
            }
            Button {
                model.startNewConversationAfterRecap()
            } label: {
                Label("New conversation", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(CatTheme.surface)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(CatTheme.accent, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .background {
            CatTheme.canvas
                .overlay(alignment: .top) { CatTheme.rule.frame(height: 1) }
                .ignoresSafeArea()
        }
    }

    private func shareText(_ record: ConversationRecord) -> String {
        guard let summary = record.summary else { return record.transcript }
        return summary + "\n\n" + record.transcript
    }
}
