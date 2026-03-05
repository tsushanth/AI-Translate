"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ttsService = void 0;
const text_to_speech_1 = require("@google-cloud/text-to-speech");
const logger_1 = require("../utils/logger");
// Language to voice mapping for high-quality neural voices
const VOICE_MAP = {
    // English variants
    'en': { languageCode: 'en-US', name: 'en-US-Neural2-J', ssmlGender: 'MALE' },
    'en-US': { languageCode: 'en-US', name: 'en-US-Neural2-J', ssmlGender: 'MALE' },
    'en-GB': { languageCode: 'en-GB', name: 'en-GB-Neural2-B', ssmlGender: 'MALE' },
    // Spanish
    'es': { languageCode: 'es-ES', name: 'es-ES-Neural2-B', ssmlGender: 'MALE' },
    'es-ES': { languageCode: 'es-ES', name: 'es-ES-Neural2-B', ssmlGender: 'MALE' },
    'es-MX': { languageCode: 'es-US', name: 'es-US-Neural2-B', ssmlGender: 'MALE' },
    // French
    'fr': { languageCode: 'fr-FR', name: 'fr-FR-Neural2-B', ssmlGender: 'MALE' },
    'fr-FR': { languageCode: 'fr-FR', name: 'fr-FR-Neural2-B', ssmlGender: 'MALE' },
    // German
    'de': { languageCode: 'de-DE', name: 'de-DE-Neural2-B', ssmlGender: 'MALE' },
    'de-DE': { languageCode: 'de-DE', name: 'de-DE-Neural2-B', ssmlGender: 'MALE' },
    // Italian
    'it': { languageCode: 'it-IT', name: 'it-IT-Neural2-C', ssmlGender: 'MALE' },
    'it-IT': { languageCode: 'it-IT', name: 'it-IT-Neural2-C', ssmlGender: 'MALE' },
    // Portuguese
    'pt': { languageCode: 'pt-BR', name: 'pt-BR-Neural2-B', ssmlGender: 'MALE' },
    'pt-BR': { languageCode: 'pt-BR', name: 'pt-BR-Neural2-B', ssmlGender: 'MALE' },
    'pt-PT': { languageCode: 'pt-PT', name: 'pt-PT-Neural2-B', ssmlGender: 'MALE' },
    // Russian
    'ru': { languageCode: 'ru-RU', name: 'ru-RU-Neural2-B', ssmlGender: 'MALE' },
    // Chinese
    'zh': { languageCode: 'cmn-CN', name: 'cmn-CN-Neural2-C', ssmlGender: 'MALE' },
    'zh-CN': { languageCode: 'cmn-CN', name: 'cmn-CN-Neural2-C', ssmlGender: 'MALE' },
    'zh-TW': { languageCode: 'cmn-TW', name: 'cmn-TW-Neural2-C', ssmlGender: 'MALE' },
    // Japanese
    'ja': { languageCode: 'ja-JP', name: 'ja-JP-Neural2-C', ssmlGender: 'MALE' },
    // Korean
    'ko': { languageCode: 'ko-KR', name: 'ko-KR-Neural2-C', ssmlGender: 'MALE' },
    // Arabic
    'ar': { languageCode: 'ar-XA', name: 'ar-XA-Neural2-C', ssmlGender: 'MALE' },
    // Hindi
    'hi': { languageCode: 'hi-IN', name: 'hi-IN-Neural2-B', ssmlGender: 'MALE' },
    // Dutch
    'nl': { languageCode: 'nl-NL', name: 'nl-NL-Neural2-C', ssmlGender: 'MALE' },
    // Polish
    'pl': { languageCode: 'pl-PL', name: 'pl-PL-Neural2-B', ssmlGender: 'MALE' },
    // Turkish
    'tr': { languageCode: 'tr-TR', name: 'tr-TR-Neural2-B', ssmlGender: 'MALE' },
    // Vietnamese
    'vi': { languageCode: 'vi-VN', name: 'vi-VN-Neural2-A', ssmlGender: 'FEMALE' },
    // Thai
    'th': { languageCode: 'th-TH', name: 'th-TH-Neural2-C', ssmlGender: 'FEMALE' },
    // Swedish
    'sv': { languageCode: 'sv-SE', name: 'sv-SE-Neural2-A', ssmlGender: 'FEMALE' },
    // Danish
    'da': { languageCode: 'da-DK', name: 'da-DK-Neural2-D', ssmlGender: 'FEMALE' },
    // Finnish
    'fi': { languageCode: 'fi-FI', name: 'fi-FI-Neural2-A', ssmlGender: 'FEMALE' },
    // Norwegian
    'no': { languageCode: 'nb-NO', name: 'nb-NO-Neural2-B', ssmlGender: 'MALE' },
    'nb': { languageCode: 'nb-NO', name: 'nb-NO-Neural2-B', ssmlGender: 'MALE' },
    // Czech
    'cs': { languageCode: 'cs-CZ', name: 'cs-CZ-Neural2-A', ssmlGender: 'FEMALE' },
    // Greek
    'el': { languageCode: 'el-GR', name: 'el-GR-Neural2-A', ssmlGender: 'FEMALE' },
    // Hebrew
    'he': { languageCode: 'he-IL', name: 'he-IL-Neural2-B', ssmlGender: 'MALE' },
    // Indonesian
    'id': { languageCode: 'id-ID', name: 'id-ID-Neural2-B', ssmlGender: 'MALE' },
    // Malay
    'ms': { languageCode: 'ms-MY', name: 'ms-MY-Neural2-B', ssmlGender: 'MALE' },
    // Romanian
    'ro': { languageCode: 'ro-RO', name: 'ro-RO-Neural2-A', ssmlGender: 'FEMALE' },
    // Ukrainian
    'uk': { languageCode: 'uk-UA', name: 'uk-UA-Neural2-A', ssmlGender: 'FEMALE' },
    // Hungarian
    'hu': { languageCode: 'hu-HU', name: 'hu-HU-Neural2-A', ssmlGender: 'FEMALE' },
    // Bengali
    'bn': { languageCode: 'bn-IN', name: 'bn-IN-Neural2-B', ssmlGender: 'MALE' },
};
class TextToSpeechService {
    client;
    constructor() {
        // Client will use Application Default Credentials
        this.client = new text_to_speech_1.TextToSpeechClient();
    }
    /**
     * Synthesizes speech from text
     * @returns Audio content as a Buffer (MP3 format)
     */
    async synthesize(params) {
        const { text, languageCode, speakingRate = 1.0, pitch = 0.0 } = params;
        const startTime = Date.now();
        // Get voice configuration for this language
        const voiceConfig = this.getVoiceConfig(languageCode);
        logger_1.logger.info('TTS request', {
            languageCode,
            textLength: text.length,
            voiceName: voiceConfig.name,
        });
        try {
            const [response] = await this.client.synthesizeSpeech({
                input: { text },
                voice: {
                    languageCode: voiceConfig.languageCode,
                    name: voiceConfig.name,
                    ssmlGender: voiceConfig.ssmlGender,
                },
                audioConfig: {
                    audioEncoding: 'MP3',
                    speakingRate: Math.max(0.25, Math.min(4.0, speakingRate)),
                    pitch: Math.max(-20.0, Math.min(20.0, pitch)),
                    effectsProfileId: ['small-bluetooth-speaker-class-device'], // Optimized for mobile
                },
            });
            const durationMs = Date.now() - startTime;
            logger_1.logger.info('TTS completed', {
                languageCode,
                voiceName: voiceConfig.name,
                audioSize: response.audioContent ? response.audioContent.length : 0,
                durationMs,
            });
            return {
                audioContent: response.audioContent,
                audioEncoding: 'MP3',
                durationMs,
            };
        }
        catch (error) {
            logger_1.logger.error('TTS failed', {
                languageCode,
                error: error.message,
            });
            throw error;
        }
    }
    /**
     * Gets the best voice configuration for a language code
     */
    getVoiceConfig(languageCode) {
        const normalizedCode = languageCode.toLowerCase();
        // Try exact match first
        const exactMatch = VOICE_MAP[normalizedCode];
        if (exactMatch) {
            return exactMatch;
        }
        // Try language prefix (e.g., "en" for "en-AU")
        const prefix = normalizedCode.split('-')[0] || normalizedCode;
        const prefixMatch = VOICE_MAP[prefix];
        if (prefixMatch) {
            return prefixMatch;
        }
        // Default to English if language not found
        logger_1.logger.warn('No voice mapping found for language, defaulting to English', { languageCode });
        return VOICE_MAP['en'];
    }
    /**
     * Checks if a language is supported for TTS
     */
    isLanguageSupported(languageCode) {
        const normalizedCode = languageCode.toLowerCase();
        const prefix = normalizedCode.split('-')[0] || normalizedCode;
        return normalizedCode in VOICE_MAP || prefix in VOICE_MAP;
    }
    /**
     * Gets list of supported languages
     */
    getSupportedLanguages() {
        // Return unique language codes (without duplicates from variants)
        const languages = new Set();
        for (const code of Object.keys(VOICE_MAP)) {
            const prefix = code.split('-')[0];
            if (prefix) {
                languages.add(prefix);
            }
        }
        return Array.from(languages).sort();
    }
}
exports.ttsService = new TextToSpeechService();
//# sourceMappingURL=ttsService.js.map