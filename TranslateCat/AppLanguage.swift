import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Hashable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case hindi = "hi"
    case arabic = "ar"
    case russian = "ru"
    case thai = "th"
    case vietnamese = "vi"
    case indonesian = "id"
    case malay = "ms"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chineseSimplified: "Chinese Simplified"
        case .hindi: "Hindi"
        case .arabic: "Arabic"
        case .russian: "Russian"
        case .thai: "Thai"
        case .vietnamese: "Vietnamese"
        case .indonesian: "Indonesian"
        case .malay: "Malay"
        }
    }

    /// The language's name written in that language, for the person who reads it.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .hindi: "हिन्दी"
        case .arabic: "العربية"
        case .russian: "Русский"
        case .thai: "ไทย"
        case .vietnamese: "Tiếng Việt"
        case .indonesian: "Bahasa Indonesia"
        case .malay: "Bahasa Melayu"
        }
    }

    /// Shown on the outside display before anything has been said.
    var waitingPhrase: String {
        switch self {
        case .english: "Go ahead, I’m listening."
        case .spanish: "Adelante, le escucho."
        case .french: "Allez-y, je vous écoute."
        case .german: "Bitte sprechen Sie."
        case .italian: "Prego, la ascolto."
        case .portuguese: "Pode falar, estou ouvindo."
        case .japanese: "どうぞ、お話しください。"
        case .korean: "말씀하세요. 듣고 있어요."
        case .chineseSimplified: "请说，我在听。"
        case .hindi: "बोलिए, मैं सुन रहा हूँ।"
        case .arabic: "تفضل، أنا أستمع."
        case .russian: "Говорите, я слушаю."
        case .thai: "เชิญพูดได้เลย"
        case .vietnamese: "Mời bạn nói, tôi đang nghe."
        case .indonesian: "Silakan bicara, saya mendengarkan."
        case .malay: "Sila bercakap, saya mendengar."
        }
    }

    /// Shown on the outside display while someone is speaking.
    var listeningPhrase: String {
        switch self {
        case .english: "Listening…"
        case .spanish: "Escuchando…"
        case .french: "À l’écoute…"
        case .german: "Hört zu…"
        case .italian: "In ascolto…"
        case .portuguese: "Ouvindo…"
        case .japanese: "聞いています…"
        case .korean: "듣는 중…"
        case .chineseSimplified: "正在听…"
        case .hindi: "सुन रहा है…"
        case .arabic: "جارٍ الاستماع…"
        case .russian: "Слушаю…"
        case .thai: "กำลังฟัง…"
        case .vietnamese: "Đang nghe…"
        case .indonesian: "Mendengarkan…"
        case .malay: "Sedang mendengar…"
        }
    }

    var language: Locale.Language { Locale.Language(identifier: rawValue) }

    var locale: Locale { Locale(identifier: rawValue) }
}

enum Speaker: String, CaseIterable, Identifiable, Hashable, Codable {
    case holder
    case other

    var id: String { rawValue }
}
