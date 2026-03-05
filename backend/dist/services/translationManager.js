"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.translationManager = void 0;
const config_1 = require("../config");
const logger_1 = require("../utils/logger");
const providers_1 = require("./providers");
/**
 * Translation manager that routes requests to the appropriate provider
 */
class TranslationManager {
    googleProvider;
    deeplProvider = null;
    constructor() {
        // Always initialize Google provider
        this.googleProvider = new providers_1.GoogleTranslationProvider();
        // Initialize DeepL if configured
        if (config_1.config.deepl.isEnabled && config_1.config.deepl.apiKey) {
            this.deeplProvider = new providers_1.DeepLTranslationProvider(config_1.config.deepl.apiKey, config_1.config.deepl.useFreeApi);
            logger_1.logger.info('DeepL provider initialized');
        }
    }
    /**
     * Get list of available providers
     */
    getAvailableProviders() {
        const providers = ['google'];
        if (this.deeplProvider) {
            providers.push('deepl');
        }
        return providers;
    }
    /**
     * Check if a provider is available
     */
    isProviderAvailable(provider) {
        if (provider === 'google')
            return true;
        if (provider === 'deepl')
            return this.deeplProvider !== null;
        return false;
    }
    /**
     * Check if DeepL supports the given language pair
     */
    isDeepLLanguageSupported(sourceLanguage, targetLanguage) {
        if (!this.deeplProvider)
            return false;
        // Auto-detect is always supported
        const sourceSupported = sourceLanguage === 'auto' || this.deeplProvider.isLanguageSupported(sourceLanguage);
        const targetSupported = this.deeplProvider.isLanguageSupported(targetLanguage);
        return sourceSupported && targetSupported;
    }
    /**
     * Translate text using the specified provider
     */
    async translate(params, provider = 'google') {
        // Validate provider availability
        if (!this.isProviderAvailable(provider)) {
            logger_1.logger.warn(`Provider ${provider} not available, falling back to google`);
            provider = 'google';
        }
        // Check if DeepL supports the language pair, fall back to Google if not
        if (provider === 'deepl' && !this.isDeepLLanguageSupported(params.sourceLanguage, params.targetLanguage)) {
            logger_1.logger.info(`DeepL does not support language pair ${params.sourceLanguage} -> ${params.targetLanguage}, falling back to google`);
            provider = 'google';
        }
        const selectedProvider = this.getProvider(provider);
        const startTime = Date.now();
        try {
            const result = await selectedProvider.translate({
                text: params.text,
                sourceLanguage: params.sourceLanguage,
                targetLanguage: params.targetLanguage,
            });
            logger_1.logger.info('Translation completed', {
                provider,
                sourceLanguage: result.sourceLanguage,
                targetLanguage: result.targetLanguage,
                characterCount: result.characterCount,
                latencyMs: result.latencyMs,
            });
            return {
                translatedText: result.translatedText,
                sourceLanguage: result.sourceLanguage,
                targetLanguage: result.targetLanguage,
                detectedLanguage: result.detectedLanguage,
                characterCount: result.characterCount,
                provider,
            };
        }
        catch (error) {
            const duration = Date.now() - startTime;
            logger_1.logger.error('Translation failed', {
                provider,
                error: error.message,
                durationMs: duration,
            });
            throw error;
        }
    }
    getProvider(provider) {
        switch (provider) {
            case 'deepl':
                return this.deeplProvider;
            case 'google':
            default:
                return this.googleProvider;
        }
    }
}
exports.translationManager = new TranslationManager();
//# sourceMappingURL=translationManager.js.map