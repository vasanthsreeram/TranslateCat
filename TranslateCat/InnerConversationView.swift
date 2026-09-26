import RevenueCatUI
import SwiftUI
import Translation

struct InnerConversationView: View {
    @Bindable var model: ConversationModel
    @Environment(SubscriptionModel.self) private var subscription
    @State private var isFolded = false
    @State private var showingPaywall = false
    @State private var showingCustomerCenter = false
    @State private var showingComposer = false
    @State private var showingTravelHelp = false
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            Group {
                if isFolded {
                    // Partially folded like a laptop: read the conversation up top, touch the controls below.
                    ArrangementView {
                        TranscriptView(model: model)
                    } secondary: {
                        ControlDeckView(model: model, isSpacious: true)
                    }
                    .arrangementViewStyle(.split)
                } else {
                    TranscriptView(model: model)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            ControlDeckView(model: model, isSpacious: false)
                                .background {
                                    CatTheme.canvas
                                        .overlay(alignment: .top) {
                                            CatTheme.rule.frame(height: 1)
                                        }
                                        .ignoresSafeArea()
                                }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CatTheme.canvas.ignoresSafeArea())
            .onGeometryChange(for: Bool.self) { proxy in
                !proxy.reservedRegions(kind: .division).isEmpty
            } action: { folded in
                withAnimation(.smooth) { isFolded = folded }
            }
            .navigationTitle("TranslateCat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Label("TranslateCat", systemImage: "cat.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(CatTheme.ink)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Type a line", systemImage: "keyboard") {
                        showingComposer = true
                    }
                    Button("New conversation", systemImage: "square.and.pencil") {
                        model.newConversation()
                    }
                    .disabled(model.turns.isEmpty)
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    Button("Summary", systemImage: "list.bullet.clipboard") {
                        model.showRecap(for: model.currentRecordID)
                    }
                    .disabled(model.turns.isEmpty || model.isAutoRunning)
                    Button("Conversation notes", systemImage: "text.book.closed") {
                        showingHistory = true
                    }
                    Button("Travel help", systemImage: "sparkles") {
                        showingTravelHelp = true
                    }
                    if subscription.isPro {
                        Button("Manage subscription", systemImage: "crown.fill") {
                            showingCustomerCenter = true
                        }
                    } else {
                        Button("Get TranslateCat Pro", systemImage: "crown") {
                            showingPaywall = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                composerSheet
            }
            .sheet(isPresented: $showingTravelHelp) {
                TravelChatView()
            }
            .sheet(isPresented: $showingHistory) {
                ConversationHistoryView(model: model)
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywall()
            }
            .presentCustomerCenter(isPresented: $showingCustomerCenter)
            .sheet(isPresented: Binding(
                get: { model.recapRecordID != nil },
                set: { if !$0 { model.recapRecordID = nil } }
            )) {
                if let id = model.recapRecordID {
                    ConversationRecapView(model: model, recordID: id)
                }
            }
        }
        .sceneAccessory {
            CameraCaptureAccessory(isEnabled: $model.outerEnabled) {
                CoverTranscriptView(model: model)
            }
            .onAvailabilityChange { isAvailable in
                model.coverAvailable = isAvailable
            }
        }
        .translationTask(model.configuration) { session in
            await model.performPendingTranslation(using: session)
        }
        .translationTask(model.liveConfiguration) { session in
            await model.performLiveTranslation(using: session)
        }
        .task {
            await model.camera.start()
        }
        .onChange(of: model.holderLanguage) { previous, _ in
            model.keepLanguagesDistinct(changedHolder: true, previous: previous)
        }
        .onChange(of: model.otherLanguage) { previous, _ in
            model.keepLanguagesDistinct(changedHolder: false, previous: previous)
        }
    }

    private var composerSheet: some View {
        NavigationStack {
            Form {
                Picker("Who is speaking", selection: $model.typingAs) {
                    Text("Me · \(model.holderLanguage.name)").tag(Speaker.holder)
                    Text("Them · \(model.otherLanguage.name)").tag(Speaker.other)
                }
                .pickerStyle(.segmented)
                TextField("Type a line", text: $model.draft, axis: .vertical)
                    .lineLimit(2...5)
                    .submitLabel(.send)
                    .onSubmit { sendDraft() }
            }
            .navigationTitle("Type a line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingComposer = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Translate") { sendDraft() }
                        .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sendDraft() {
        guard !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.sendDraft()
        showingComposer = false
    }
}
