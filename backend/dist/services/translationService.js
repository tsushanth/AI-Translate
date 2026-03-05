"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.translationService = void 0;
const translate_1 = require("@google-cloud/translate");
const config_1 = require("../config");
const logger_1 = require("../utils/logger");
/**
 * Google Cloud Translation service wrapper
 */
class TranslationService {
    client;
    projectId;
    location = 'global';
    constructor() {
        this.client = new translate_1.TranslationServiceClient();
        this.projectId = config_1.config.google.projectId;
    }
    /**
     * Translates text from source language to target language
     */
    async translate(params) {
        const { text, sourceLanguage, targetLanguage, format = 'text' } = params;
        const startTime = Date.now();
        try {
            const parent = `projects/${this.projectId}/locations/${this.location}`;
            const request = {
                parent,
                contents: [text],
                targetLanguageCode: targetLanguage,
                mimeType: format === 'html' ? 'text/html' : 'text/plain',
            };
            // Only set source language if not auto-detect
            if (sourceLanguage !== 'auto') {
                request.sourceLanguageCode = sourceLanguage;
            }
            const [response] = await this.client.translateText(request);
            const translation = response.translations?.[0];
            if (!translation || !translation.translatedText) {
                throw new Error('No translation returned from API');
            }
            const result = {
                translatedText: translation.translatedText,
                sourceLanguage: sourceLanguage === 'auto'
                    ? translation.detectedLanguageCode || sourceLanguage
                    : sourceLanguage,
                targetLanguage,
                characterCount: text.length,
            };
            // Add detected language info if auto-detect was used
            if (sourceLanguage === 'auto' && translation.detectedLanguageCode) {
                result.detectedLanguage = translation.detectedLanguageCode;
                // Google doesn't return confidence, so we don't set it
            }
            const duration = Date.now() - startTime;
            logger_1.logger.debug('Translation completed', {
                sourceLanguage: result.sourceLanguage,
                targetLanguage,
                characterCount: result.characterCount,
                durationMs: duration,
            });
            return result;
        }
        catch (error) {
            const duration = Date.now() - startTime;
            logger_1.logger.error('Translation failed', {
                error: error.message,
                sourceLanguage,
                targetLanguage,
                durationMs: duration,
            });
            throw error;
        }
    }
    /**
     * Gets list of supported languages
     */
    async getSupportedLanguages() {
        try {
            const parent = `projects/${this.projectId}/locations/${this.location}`;
            const [response] = await this.client.getSupportedLanguages({
                parent,
                displayLanguageCode: 'en',
            });
            return (response.languages || []).map((lang) => ({
                code: lang.languageCode || '',
                name: lang.displayName || lang.languageCode || '',
            }));
        }
        catch (error) {
            logger_1.logger.error('Failed to get supported languages', { error: error.message });
            throw error;
        }
    }
}
exports.translationService = new TranslationService();
//# sourceMappingURL=translationService.js.map