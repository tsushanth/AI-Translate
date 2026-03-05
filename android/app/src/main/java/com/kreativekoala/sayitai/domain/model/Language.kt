package com.kreativekoala.sayitai.domain.model

data class Language(
    val code: String,
    val name: String,
    val nativeName: String,
    val isRTL: Boolean = false,
    val speechLocaleCode: String,
    val flagEmoji: String
) {
    val displayName: String
        get() = "$flagEmoji $name"

    companion object {
        val AUTO_DETECT = Language(
            code = "auto",
            name = "Auto-detect",
            nativeName = "Auto-detect",
            isRTL = false,
            speechLocaleCode = "",
            flagEmoji = "🌐"
        )

        val supportedLanguages = listOf(
            Language("en", "English", "English", false, "en-US", "🇺🇸"),
            Language("es", "Spanish", "Español", false, "es-ES", "🇪🇸"),
            Language("fr", "French", "Français", false, "fr-FR", "🇫🇷"),
            Language("de", "German", "Deutsch", false, "de-DE", "🇩🇪"),
            Language("it", "Italian", "Italiano", false, "it-IT", "🇮🇹"),
            Language("pt", "Portuguese", "Português", false, "pt-BR", "🇧🇷"),
            Language("ru", "Russian", "Русский", false, "ru-RU", "🇷🇺"),
            Language("zh", "Chinese", "中文", false, "zh-CN", "🇨🇳"),
            Language("ja", "Japanese", "日本語", false, "ja-JP", "🇯🇵"),
            Language("ko", "Korean", "한국어", false, "ko-KR", "🇰🇷"),
            Language("ar", "Arabic", "العربية", true, "ar-SA", "🇸🇦"),
            Language("hi", "Hindi", "हिन्दी", false, "hi-IN", "🇮🇳"),
            Language("nl", "Dutch", "Nederlands", false, "nl-NL", "🇳🇱"),
            Language("pl", "Polish", "Polski", false, "pl-PL", "🇵🇱"),
            Language("tr", "Turkish", "Türkçe", false, "tr-TR", "🇹🇷"),
            Language("vi", "Vietnamese", "Tiếng Việt", false, "vi-VN", "🇻🇳"),
            Language("th", "Thai", "ไทย", false, "th-TH", "🇹🇭"),
            Language("sv", "Swedish", "Svenska", false, "sv-SE", "🇸🇪"),
            Language("da", "Danish", "Dansk", false, "da-DK", "🇩🇰"),
            Language("fi", "Finnish", "Suomi", false, "fi-FI", "🇫🇮"),
            Language("no", "Norwegian", "Norsk", false, "nb-NO", "🇳🇴"),
            Language("cs", "Czech", "Čeština", false, "cs-CZ", "🇨🇿"),
            Language("el", "Greek", "Ελληνικά", false, "el-GR", "🇬🇷"),
            Language("he", "Hebrew", "עברית", true, "he-IL", "🇮🇱"),
            Language("id", "Indonesian", "Bahasa Indonesia", false, "id-ID", "🇮🇩"),
            Language("ms", "Malay", "Bahasa Melayu", false, "ms-MY", "🇲🇾"),
            Language("ro", "Romanian", "Română", false, "ro-RO", "🇷🇴"),
            Language("uk", "Ukrainian", "Українська", false, "uk-UA", "🇺🇦"),
            Language("hu", "Hungarian", "Magyar", false, "hu-HU", "🇭🇺"),
            Language("bn", "Bengali", "বাংলা", false, "bn-IN", "🇧🇩")
        )

        val allLanguages = listOf(AUTO_DETECT) + supportedLanguages

        fun fromCode(code: String): Language {
            return supportedLanguages.find { it.code == code }
                ?: if (code == "auto") AUTO_DETECT else supportedLanguages.first()
        }
    }
}
