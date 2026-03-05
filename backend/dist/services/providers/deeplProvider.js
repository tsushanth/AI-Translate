"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DeepLTranslationProvider = void 0;
/**
 * DeepL API provider
 * Docs: https://www.deepl.com/docs-api
 */
class DeepLTranslationProvider {
    name = 'DeepL';
    apiKey;
    baseUrl;
    constructor(apiKey, useFreeApi = false) {
        this.apiKey = apiKey;
        // DeepL has different endpoints for free vs pro API
        this.baseUrl = useFreeApi
            ? 'https://api-free.deepl.com/v2'
            : 'https://api.deepl.com/v2';
    }
    // Languages supported by DeepL (as of 2025)
    static SUPPORTED_LANGUAGES = new Set([
        'ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr',
        'he', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'nb', 'nl', 'pl',
        'pt', 'ro', 'ru', 'sk', 'sl', 'sv', 'th', 'tr', 'uk', 'vi', 'zh',
        // Also accept 'no' as it maps to 'nb'
        'no'
    ]);
    // Check if a language is supported by DeepL
    isLanguageSupported(code) {
        return DeepLTranslationProvider.SUPPORTED_LANGUAGES.has(code.toLowerCase());
    }
    // Map common language codes to DeepL format
    mapLanguageCode(code, isTarget) {
        const lowerCode = code.toLowerCase();
        // Mapping for special cases
        const mappings = {
            'en': (isTarget) => isTarget ? 'EN-US' : 'EN', // DeepL requires EN-US or EN-GB for target
            'pt': (isTarget) => isTarget ? 'PT-BR' : 'PT', // Portuguese Brazil for target
            'zh': () => 'ZH',
            'no': () => 'NB', // Norwegian maps to Norwegian Bokmål
        };
        const mapping = mappings[lowerCode];
        if (mapping) {
            return typeof mapping === 'function' ? mapping(isTarget) : mapping;
        }
        return code.toUpperCase();
    }
    async translate(params) {
        const { text, sourceLanguage, targetLanguage } = params;
        const startTime = Date.now();
        const body = {
            text: [text],
            target_lang: this.mapLanguageCode(targetLanguage, true),
        };
        if (sourceLanguage !== 'auto') {
            body['source_lang'] = this.mapLanguageCode(sourceLanguage, false);
        }
        const response = await fetch(`${this.baseUrl}/translate`, {
            method: 'POST',
            headers: {
                'Authorization': `DeepL-Auth-Key ${this.apiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
        });
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`DeepL API error: ${response.status} - ${errorText}`);
        }
        const data = await response.json();
        const translation = data.translations?.[0];
        if (!translation) {
            throw new Error('No translation returned from DeepL API');
        }
        const latencyMs = Date.now() - startTime;
        return {
            translatedText: translation.text,
            sourceLanguage: sourceLanguage === 'auto'
                ? translation.detected_source_language.toLowerCase()
                : sourceLanguage,
            targetLanguage,
            detectedLanguage: sourceLanguage === 'auto'
                ? translation.detected_source_language.toLowerCase()
                : undefined,
            characterCount: text.length,
            provider: this.name,
            latencyMs,
        };
    }
}
exports.DeepLTranslationProvider = DeepLTranslationProvider;
//# sourceMappingURL=deeplProvider.js.map