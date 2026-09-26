import SwiftUI

/// A conversation's summary: title, short recap, key points, and follow-ups.
struct RecapSummaryView: View {
    var record: ConversationRecord
    var isLoading: Bool
    var error: String?
    var isLocked = false
    /// Hide the recap title when the surrounding screen already shows it as a headline.
    var showsTitle = true
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Writing your summary…")
                        .foregroundStyle(CatTheme.mutedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if let recap = record.recap {
                recapContent(recap)
            } else if let summary = record.summary {
                Text(summary)
                    .foregroundStyle(CatTheme.ink)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            } else if isLocked {
                ProUpsellView()
            } else {
                Text("Get a short summary of what was said, with key points and anything to follow up on.")
                    .foregroundStyle(CatTheme.mutedInk)
            }

            if let error, !isLoading {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(CatTheme.warning)
            }
            if !isLoading && !(isLocked && record.summary == nil) && (record.summary == nil || error != nil) {
                Button(record.summary == nil ? "Summarize conversation" : "Try again", systemImage: "sparkles",
                       action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: isLocked) { _, locked in
            // Just unlocked Pro from the paywall: write the summary they were waiting for.
            if !locked && record.summary == nil { onRetry() }
        }
    }

    private func recapContent(_ recap: ConversationRecap) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                if showsTitle {
                    Text(recap.title)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(CatTheme.ink)
                }
                Text(recap.summary)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(4)
                    .foregroundStyle(CatTheme.ink)
            }
            if !recap.keyPoints.isEmpty {
                section("Key points", items: recap.keyPoints) {
                    Circle()
                        .fill(CatTheme.accent)
                        .frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { $0.height + 4 }
                        .frame(width: 16)
                }
            }
            if !recap.followUps.isEmpty {
                section("Follow-ups", items: recap.followUps) {
                    Image(systemName: "square")
                        .font(.callout)
                        .foregroundStyle(CatTheme.accent)
                        .frame(width: 16)
                }
            }
        }
        .textSelection(.enabled)
    }

    private func section(_ title: String, items: [String], @ViewBuilder marker: () -> some View) -> some View {
        let marker = marker()
        return VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(CatTheme.mutedInk)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    marker
                        .accessibilityHidden(true)
                    Text(item)
                        .foregroundStyle(CatTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
