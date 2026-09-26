import SwiftUI

@main
struct TranslateCatApp: App {
    @State private var model = ConversationModel()
    @State private var subscription = SubscriptionModel()

    var body: some Scene {
        WindowGroup {
            InnerConversationView(model: model)
                .environment(subscription)
                .tint(CatTheme.accent)
                .preferredColorScheme(.light)
                .onChange(of: subscription.isPro, initial: true) { _, isPro in
                    model.summariesUnlocked = isPro
                }
        }
    }
}

enum CatTheme {
    static let accent = Color(red: 0.18, green: 0.35, blue: 0.29)
    static let canvas = Color(red: 0.95, green: 0.93, blue: 0.88)
    static let surface = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let ink = Color(red: 0.16, green: 0.20, blue: 0.17)
    static let mutedInk = Color(red: 0.39, green: 0.42, blue: 0.37)
    static let rule = Color(red: 0.82, green: 0.80, blue: 0.73)
    static let accentWash = Color(red: 0.87, green: 0.91, blue: 0.86)
    static let warning = Color(red: 0.64, green: 0.27, blue: 0.20)
}
