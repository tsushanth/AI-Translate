"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GoogleTranslationProvider = void 0;
const translate_1 = require("@google-cloud/translate");
const config_1 = require("../../config");
/**
 * Google Cloud Translation API provider (Neural Machine Translation)
 */
class GoogleTranslationProvider {
    name = 'Google Cloud Translation';
    client;
    projectId;
    location = 'global';
    constructor() {
        this.client = new translate_1.TranslationServiceClient();
        this.projectId = config_1.config.google.projectId;
    }
    async translate(params) {
        const { text, sourceLanguage, targetLanguage } = params;
        const startTime = Date.now();
        const parent = `projects/${this.projectId}/locations/${this.location}`;
        const request = {
            parent,
            contents: [text],
            targetLanguageCode: targetLanguage,
            mimeType: 'text/plain',
        };
        if (sourceLanguage !== 'auto') {
            request.sourceLanguageCode = sourceLanguage;
        }
        const [response] = await this.client.translateText(request);
        const translation = response.translations?.[0];
        if (!translation || !translation.translatedText) {
            throw new Error('No translation returned from Google API');
        }
        const latencyMs = Date.now() - startTime;
        return {
            translatedText: translation.translatedText,
            sourceLanguage: sourceLanguage === 'auto'
                ? translation.detectedLanguageCode || sourceLanguage
                : sourceLanguage,
            targetLanguage,
            detectedLanguage: sourceLanguage === 'auto' && translation.detectedLanguageCode
                ? translation.detectedLanguageCode
                : undefined,
            characterCount: text.length,
            provider: this.name,
            latencyMs,
        };
    }
}
exports.GoogleTranslationProvider = GoogleTranslationProvider;
//# sourceMappingURL=googleProvider.js.map